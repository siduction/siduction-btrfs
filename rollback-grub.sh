#!/bin/bash
#
# Name: /usr/share/siduction/rollback-grub.sh
# Part of siduction-btrfs
# Called by /usr/lib/snapper/plugins/50-siduction.sh
#
# Switch to the rollback target and run the commands
# 'update-grub' and 'grub-install'.
# Grub will now read the menu file from the rollback target.
#

set -e

. /etc/default/grub.d/siduction.cfg

# After rollback, subvolume that is set to default in Btrfs.
default_nr="$1"
btrfs_default="@snapshots/$1/snapshot"

# Determine root partition.
root_dev=$(grep ' / ' /proc/mounts | cut -d ' ' -f 1)

# Search for grub installation target.
# 1) EFI GPT
if findmnt /boot/efi &>/dev/null; then
	target=""
	echo "$(date +%T) rollback-grub: Found EFI. Install grub from subvolume $default_nr." >> /var/log/snapper.log
else

# 2) MBR BIOS
	list=$(mount | grep '^/dev/[sn]' | cut -d " " -f 1 | sed 's!p\?[0-9]\+$!!' | uniq)
	for i in $list; do
		if dd if="$i" count=4000 2>/dev/null | grep --no-ignore-case -ao GRUB; then
			echo "$(date +%T) rollback-grub: Found MBR. Install grub from subvolume $default_nr to $i." >> /var/log/snapper.log
			target="$i"
			break
		fi
		echo "$(date +%T) rollback-grub: Error: No installation target found for grub" >> /var/log/snapper.log
		exit 1
	done
fi

# Create a temporary mount directory.
tmp_dir=`mktemp -d /tmp/sn-mount.XXXXXXXXXXXX` || exit 1
trap "umount -R $tmp_dir; rmdir $tmp_dir" KILL EXIT SYS TERM HUP

# Mount rollback target.
mount -t btrfs -o subvol=${btrfs_default} ${root_dev} ${tmp_dir}

# Create the file /etc/kernel/cmdline in the rollback target.
tr -s "$IFS" '\n' </proc/cmdline | grep -ve '^BOOT_IMAGE=' -e '^initrd=' | \
	tr '\n' ' ' | sed "s|\(^.*subvol=\)[^ ]\+|\1$btrfs_default|" \
	>${tmp_dir}/etc/kernel/cmdline   #"

# bind mounts
for i in "/proc" "/run" "/sys" "/dev"; do
	mount --rbind ${i} ${tmp_dir}${i} && mount --make-rslave ${tmp_dir}${i}
done


# Chroot into new default subvolume, update grub and install grub from there.
export default_nr
export target

chroot ${tmp_dir} /usr/bin/bash -x << 'EOF'

mount /boot &>/dev/null || true
mount /boot/efi &>/dev/null || true

. /etc/default/grub.d/siduction.cfg
. /etc/os-release

/usr/sbin/update-grub
sed -i "s|\(^menuentry '\).*with|\1$GRUB_DISTRIBUTOR $VARIANT snapshot $default_nr,|" /boot/grub/grub.cfg

/usr/sbin/grub-install "$target"

umount /boot/efi &>/dev/null || true
umount /boot &>/dev/null || true
EOF

exit 0

