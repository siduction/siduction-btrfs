#! /bin/bash
#
# Name: /usr/share/siduction/test-btrfs-default.sh
# Part of siduction-btrfs
# Called by /usr/lib/systemd/system/siduction_btrfs.service
# After booting or new snapshot, checks if Btrfs default subvolume, booted subvolume, and Grub default menu item match.
# Create new /boot/grub/grub.cfg if not.

set -e

sleep 10
btrfs_default=$(echo "$(btrfs subvolume get-default /)" | sed -E 's,[^@]*@?,@,')
booted_subvol=$(btrfs inspect-internal subvolid-resolve $(btrfs inspect-internal rootid /) /)
grub_default_menu=$(grep -m 1 -o '/.*/boot/vmlinuz' /boot/grub/grub.cfg | sed 's,/\(.*\)/boot/vmlinuz,\1,')

if [ "x${btrfs_default}" = "x${booted_subvol}" ]; then
    if [ "x${btrfs_default}" = "x${grub_default_menu}" ]; then
        echo "Nothing to do"
        exit 0
    else
        echo "Btrfs default subvolume and Grub default menu item differ."
        echo "Start \"update-grub\""
        update-grub
    fi
else
    echo "Btrfs default and login subvolume differ." 
    echo "Start \"update-grub\""
    update-grub
fi

exit 0
