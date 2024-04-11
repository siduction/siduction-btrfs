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

# Check if Btrfs. Get default subvolume.
if ! btrfs_default=$(btrfs subvolume get-default / 2>/dev/null); then
    echo "No Btrfs found on /"
    exit 0
fi

# Check filesystem write permission. Cancel if boot into
# a read only subvolume (other than Btrfs default)
if [ ! -w / ]; then
    echo "Execution canceled. No write permission."
    exit 1
fi

# Query the btrfs default subvolume, the booted subvolume, and the grub default menu entry.
# 1) Subvolume, that is set to default in Btrfs
btrfs_default=$(echo "$btrfs_default" | sed -E 's,[^@]*@?,@,')
echo "btrfs default: $btrfs_default"

# 2) Subvolume that was booted into.
booted_subvol=$(btrfs inspect-internal subvolid-resolve $(btrfs inspect-internal rootid /) /)
echo "booted subvol: $booted_subvol"

# 3) Subvolume of the grub default boot entry.
grub_default_menu=$(grep -m 1 -o '/.*/boot/vmlinuz' /boot/grub/grub.cfg | sed 's,/\(.*\)/boot/vmlinuz,\1,')
echo "grub default: $grub_default_menu"

# Compare the query values and execute action if necessary.
if [ "x${btrfs_default}" = "x${booted_subvol}" ]; then
    if [ "x${btrfs_default}" = "x${grub_default_menu}" ]; then
    # All three queries point to the same subvolume.
        echo "Nothing to do"
        exit 0
    else
    
    # Btrfs default subvolume and booted subvolume are the same.
    # The grub standard boot entry differs.
    # State after booting into the rollback target first time.
        echo "Btrfs default subvolume and Grub default menu item differ."
        echo "Run \"update-grub\" and \"grub-install\""
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
    # We still have write permissions in the new
    # default subvolume, and in the previous default
    # subvolume, in which we are currently located
    echo "Btrfs default and booted subvolume differ." 
    echo "Run \"update-grub\""
    update-grub
    
    # We have to edit /etc/fstab in the rollback target
    # Query whether the default subvolume was set to @.
    # (E.g. with a btrfs command instead of a snapper rollback).
    if [ "x$btrfs_default" = "x@" ]; then
        target_path="" 
    else
        target_path=$(echo "$btrfs_default" | sed 's!@!/.!')
    fi

    # Backup fstab. Remove old backup first.
    oldbak=$(find "$target_path"/etc/* -maxdepth 0 -regex ".*fstab_btrfs_.*" 2>/dev/null)
    if [ "$oldbak" ]; then
        echo "Remove old fstab backup."
	rm $(echo "$oldbak")
    fi

    newbak="fstab_btrfs_$(date +%F_%H%M.bak)"
    echo "Backup fstab in the rollback target to $newbak"
    cp "$target_path"/etc/fstab "$target_path"/etc/"$newbak"

    # Now edit .../etc/fstab 
    if [ -w "$target_path"/etc/fstab 2>/dev/null ]; then
        echo "Edit fstab in the rollback target."
        sed -i 's!^\(.* / .*subvol=/\)@[^,]*,\(.*\)!\1'"$btrfs_default"',\2!' "$target_path"/etc/fstab
    fi
fi

exit 0
