#!/bin/bash
#
# Name: /usr/share/siduction/rollback-sd-boot.sh
# Part of siduction-btrfs
# Called by /usr/lib/snapper/plugins/50-siduction.sh
# Creates new boot entries after a "snapper rollback" command.
# It takes into account all kernels contained in the new snapshot.

set -e

if [ "$1" -gt 0 ]; then
	default_nr="$1"
	btrfs_default="@snapshots/$1/snapshot"
else
	default_nr="@"
	btrfs_default="@"
fi


# Check if menuentry already exists.
if ls "$2" | grep -Pq "$3$default_nr"; then
	# Menuentry exists. Nothing to do.
	echo "$(date +%T) rollback-sd-boot: Entry already exists." >> /var/log/snapper.log


else
	# Create a menu entry for the rollback target.
	echo "$(date +%T) rollback-sd-boot: Create new entry." >> /var/log/snapper.log

	# Determine root partition.
	root_dev=$(grep ' / ' /proc/mounts | cut -d ' ' -f 1)

	# Create a temporary mount directory.
	tmp_dir=`mktemp -d /tmp/sn-mount.XXXXXXXXXXXX` || exit 1
	trap "umount -R $tmp_dir; rmdir $tmp_dir" KILL EXIT SYS TERM HUP

	# Mount rollback target.
	mount -t btrfs -o subvol=${btrfs_default} ${root_dev} ${tmp_dir}

	# Create the file /etc/kernel/cmdline in the rollback target.
	tr -s "$IFS" '\n' </proc/cmdline | grep -ve '^BOOT_IMAGE=' -e '^initrd=' | \
		tr '\n' ' ' | sed "s|\(^.*subvol=\)[^ ]\+|\1$btrfs_default|" \
		>${tmp_dir}/etc/kernel/cmdline   #"

	# Adapt the file /etc/kernel/entry-token  in the rollback target.
#	sed -i "s|ot-.*|ot-$default_nr|" ${tmp_dir}/etc/kernel/entry-token

	# Adapt the file /etc/os-release in the rollback target.
#	sed -i "s|shot .*|shot $default_nr\"|" ${tmp_dir}/etc/os-release

	# bind mounts
	for i in "/proc" "/run" "/sys" "/dev"; do
		mount --rbind ${i} ${tmp_dir}${i} && mount --make-rslave ${tmp_dir}${i}
	done


	# Chroot into new default subvolume and create boot entry.
	chroot ${tmp_dir} /usr/bin/bash -x << 'EOF'

	mount /boot &>/dev/null || true
	mount /efi &>/dev/null || true

	modlist=($(ls /usr/lib/modules/))

	for i in "${modlist[@]}"; do
		match=$(grep "$i" <<< $(ls /boot/vmlinu*))
		if [ "X${match:+1}" = "X1" ]; then
			dpkg-reconfigure "linux-image-$i"
		fi
	done

	umount /efi &>/dev/null || true
	umount /boot &>/dev/null || true
EOF

	umount -R ${tmp_dir}
fi
echo "$(date +%T) rollback-sd-boot: Completed successfully." >> /var/log/snapper.log
exit 0