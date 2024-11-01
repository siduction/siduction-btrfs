#!/bin/bash
#
# Name: /usr/lib/snapper/plugins/50-siduction.sh
# Part of siduction-btrfs
#

set -e

# Check if Btrfs. Get default subvolume.
if [ "X$3" = "Xbtrfs" ]; then
	btrfs_default=$(btrfs subvolume get-default / )
else
	exit 0
fi

#####################
# Begin funktions ###

boot_path () {
# Search for the installation directory of systemd-boot.
for sd_boot_dir in "/boot" "/efi"; do
	if findmnt "$sd_boot_dir" &> /dev/null; then
		menu_dir="$sd_boot_dir/loader/entries/"
		break
	fi
done

entry_part=$(sed 's|-[0-9@]\+$|-|' /etc/kernel/entry-token)
}

# End funktions ###
###################


case "$1" in

"create-snapshot-post")
	echo "$(date +%T) Plugin 50-siduction: Inside create-snapshot-post" >> /var/log/snapper.log
	# If full apt-aktion is done, this script change snappers description.
	/usr/share/siduction/snapshot-description.sh "$4" &
	;;

# This section is for systemd-boot only.
"delete-snapshot-post")
	echo "$(date +%T) Plugin 50-siduction: Inside delete-snapshot-post" >> /var/log/snapper.log
	del_sn="$4"
	
	# Is systemd-boot installed?.
	if dpkg-query -f='${Status}' -W systemd-boot | grep -q "ok installed"; then
		
		boot_path
		
		# Search for menu items and remove the orphaned ones.
		if [ -d "$sd_boot_dir/$entry_part$del_sn" ]; then
			echo "$(date +%T) Plugin 50-siduction: Remove directory $sd_boot_dir/$entry_part$del_sn" >> /var/log/snapper.log
			rm -r "$sd_boot_dir/${entry_part:?}${del_sn:?}"
			for del_file in $(ls $menu_dir$entry_part$del_sn*); do
				echo "$(date  +%T) Plugin 50-siduction: Remove menu entry $del_file" >> /var/log/snapper.log
				rm "$del_file"
			done
		fi
	fi
	;;

"rollback-post")
	echo "$(date +%T) Plugin 50-siduction: Inside rollback-post" >> /var/log/snapper.log
	old_sn="$4"
	new_sn="$5"
	
	btrfs_default="@snapshots/$new_sn/snapshot"
	target_path=$(echo "$btrfs_default" | sed 's|@|/.|')
	
	# Adapt the files /etc/os-release and /etc/kernel/entry-token
	# in the rollback target.
	# This is not absolutely necessary for GRUB, but for systemd-boot.
	# However, it increase compatibility with systemd.
	sed -i "s|shot .*|shot $new_sn\"|" $target_path/etc/os-release
	sed -i "s|shot-.*|shot-$new_sn|" $target_path/etc/kernel/entry-token
	
	
	# Execution depending on the boot manager.
	# GRUB takes precedence over systemd-boot.
	if [ -e /boot/grub/grub.cfg ] && [ -w /boot/grub/grub.cfg ]; then
		
		echo "$(date +%T) Plugin 50-siduction: Forwarding to rollback-grub." >> /var/log/snapper.log
		/usr/share/siduction/rollback-grub.sh "$new_sn" &
		wait
		echo "$(date +%T) Plugin 50-siduction: Return from rollback-grub." >> /var/log/snapper.log
		true
	
	elif dpkg-query -f='${Status}' -W systemd-boot | grep -q "ok installed"; then
		
		boot_path
		entry_part=$(sed 's|-[0-9@]\+$|-|' /etc/kernel/entry-token)
		
		# Create a menu entry for the rollback target.
		echo "$(date +%T) Plugin 50-siduction: Forwarding to rollback-sd-boot." >> /var/log/snapper.log
	
		/usr/share/siduction/rollback-sd-boot.sh "$new_sn" "$sd_boot_dir" "$entry_part" &
		wait
		echo "$(date +%T) Plugin 50-siduction: Return from rollback-sd-boot." >> /var/log/snapper.log
		
		# Change systemd-boot default boot entry to the default subvolume.
		if findmnt "/efi" &>/dev/null; then
			echo "$(date +%T) Plugin 50-siduction: Change loader.conf to $entry_part$new_sn-*" >> /var/log/snapper.log
			sed -i "s|^default.*$|default $entry_part$new_sn-*|" /efi/loader/loader.conf
		else
			echo "$(date +%T) Plugin 50-siduction: Change loader.conf to $entry_part$new_sn-*" >> /var/log/snapper.log
			sed -i "s|^default.*$|default $entry_part$new_sn-*|" /$sd_boot_dir/loader/loader.conf
		fi
	
	else
		echo "$(date +%T) Plugin 50-siduction: Neither GRUB nor systemd-boot found." >> /var/log/snapper.log
	fi
	
	# We have to edit /etc/fstab in the rollback target	
	# Backup fstab. Remove old backup first.
	# This part may only be executed after rollback-sd-boot.sh.
	# With modified fstab, /boot and /efi cannot be mounted in chroot.
	oldbak=$(find "$target_path"/etc/* -maxdepth 0 -regex ".*fstab_btrfs_.*" 2>/dev/null)
	if [ "$oldbak" ]; then
		rm "${oldbak}"
	fi
	
	newbak="fstab_btrfs_$(date +%F_%H-%M.bak)"
	echo "$(date +%T) Plugin 50-siduction: Backup fstab in the rollback target to $newbak" >> /var/log/snapper.log
	cp "$target_path"/etc/fstab "$target_path"/etc/"$newbak"
	
	# Now edit /etc/fstab 
	if [ -w "$target_path"/etc/fstab 2>/dev/null ]; then
		echo "$(date +%T) Plugin 50-siduction: Edit fstab in the rollback target." >> /var/log/snapper.log
		sed -i 's|^\(.* / .*subvol=/\)@[^,]*,\(.*\)|\1'"$btrfs_default"',\2|' "$target_path"/etc/fstab
	fi
	;;
esac
exit 0
