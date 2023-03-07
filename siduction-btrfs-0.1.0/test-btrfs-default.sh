#! /bin/bash
#
# Name: /usr/share/siduction/test-btrfs-default.sh
# Part of siduction-btrfs
# Called by /usr/lib/systemd/system/siduction_btrfs.service
# After booting or new snapshot, checks if Btrfs default subvolume,
# booted subvolume, and Grub default menu item match.
# Create new /boot/grub/grub.cfg if not.

set -e

## Test whether file system of "/" is btrfs.
#ROOTFSTYP=$( grep '[[:space:]]\+/[[:space:]]\+' /etc/fstab | awk '{ print $3 }' )

#if [ "x$ROOTFSTYP" = "xbtrfs" ]; then
#    # If the file system is btrfs, then do the work.
    
    sleep 10
    
    # Query the btrfs default subvolume, the booted subvolume, and the grub default menu entry.
    btrfs_default=$(echo "$(btrfs subvolume get-default /)" | sed -E 's,[^@]*@?,@,')
    booted_subvol=$(btrfs inspect-internal subvolid-resolve $(btrfs inspect-internal rootid /) /)
    grub_default_menu=$(grep -m 1 -o '/.*/boot/vmlinuz' /boot/grub/grub.cfg | sed 's,/\(.*\)/boot/vmlinuz,\1,')

    # Compare the query values and execute action if necessary.
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
#else
#    # No btrfs: Disable systemd units and we never see each other here again.
#    systemctl mask --now siduction_btrfs.timer siduction_btrfs.path
#fi

exit 0
