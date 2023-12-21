#!/bin/bash
#
# Name: /usr/share/siduction/test-btrfs-default.sh
# Part of siduction-btrfs
# Called by /usr/lib/systemd/system/siduction_btrfs.service
# After booting or new snapshot, checks if Btrfs default subvolume,
# booted subvolume, and Grub default menu item match.
# Create new /boot/grub/grub.cfg if not.

set -e

sleep 5

# Check filesystem write permission. Cancel if boot into
# a read only subvolume (other than Btrfs default)
if [ ! -w / ]; then
    echo "Execution canceled. No write permission."
    exit 1
fi

# Query the btrfs default subvolume, the booted subvolume, and the grub default menu entry.
# 1) Subvolume, that is set to default in Btrfs
btrfs_default=$(echo "$(btrfs subvolume get-default /)" | sed -E 's,[^@]*@?,@,')

# 2) Subvolume that was booted into.
booted_subvol=$(btrfs inspect-internal subvolid-resolve $(btrfs inspect-internal rootid /) /)

# 3) Subvolume of the grub default boot entry.
grub_default_menu=$(grep -m 1 -o '/.*/boot/vmlinuz' /boot/grub/grub.cfg | sed 's,/\(.*\)/boot/vmlinuz,\1,')


# Compare the query values and execute action if necessary.
if [ "x${btrfs_default}" = "x${booted_subvol}" ]; then
    if [ "x${btrfs_default}" = "x${grub_default_menu}" ]; then
    # All three queries point to the same subvolume.
        echo "Nothing to do"
        exit 0
    else
    
    # Btrfs subvolume and booted subvolume are the same.
    # The grub standard boot entry differs.
    # State after booting into the rollback target first time.
        echo "Btrfs default subvolume and Grub default menu item differ."
        echo "Start \"update-grub\" and \"grub-install\""
        update-grub
        
    # Search for grub installation target.
    # 1) EFI GPT
        if [ -x /boot/efi ]; then
            echo "Found EFI. Install grub."
            grub-install
            exit 0
        else
    
    # 2) MBR BIOS
            list=$(mount | grep '^/dev/[sn]' | cut -d " " -f 1 | sed 's!p\?[0-9]\+$!!' | uniq)
            for i in $list; do
                dd if="$i" count=4000 2>/dev/null | \
                if [ $(grep --no-ignore-case -ao GRUB) ]; then
                    echo "Found MBR. Install grub to $i."
                    grub-install "$i"
                    exit 0
                else
                    echo "Error: No installation target found for grub"
                    exit 1
                fi
            done
        fi
    fi
else
    
    # State after rollback and without reboot.
    # We still have write permissions in the previous default
    # subvolume, in which we are currently located.
    echo "Btrfs default and booted subvolume differ." 
    echo "Start \"update-grub\""
    update-grub
fi

exit 0
