#!/bin/bash
#
# Name: /usr/share/siduction/test-btrfs-default.sh
# Part of siduction-btrfs
# Called by /usr/lib/systemd/system/siduction_btrfs.service
# Checks after booting or a new snapshot whether a Btrfs is present
# and which boot manager is installed.
# Creates new boot entries after a "snapper rollback" command.
# The different configuration of Grub and systemd-boot is taken into account.
#
# Customize the description in 'snapper list' for apt actions
# using the apt log file.

set -e

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


find_package () {
# Search for the first package and the total number of packages
# for the given action.
# Snapper outputs the values in the description.

# Reading in the package line.
pkg=$(grep "$1" $TEMP1)

# Cut out the given action.
pkg=${pkg#$1: }

# Read out the first package.
apt_package=${pkg%%:*}

# Counting the total number of packages.
for i in $pkg; do
    if [ $(grep '^[a-z]' <<< $i) ]; then
        ((++count))
        
    fi
done
}


snapper_descripttion () {
# The btrfs default subvolume, the booted subvolume, and the
# default menu entry (only grub) point to the same subvolume.
# The new snapshot is based on an apt action.
# We search for pre and post snapshots in snapper and the
# corresponding action in the apt log file.

TEMP1=`mktemp /tmp/test-btrfs.XXXXXXXXXXXX`  || exit 1
trap "rm -f $TEMP1 2>/dev/null || true" EXIT HUP INT QUIT TERM

# We are looking for a complete apt action in snapper's newest
# entries. If the action has not yet been completed, the entire
# block is skipped and the script is terminated.
if snapper_last_post=$(snapper --no-headers --machine-readable csv list \
  | tail -n 1 | grep ",apt," | grep ",post,") && \
  snapper_last_pre=$(snapper --no-headers --machine-readable csv list \
  | tail -n 2 | grep ",apt," | grep ",pre,"); then
    # Snapper logged a complete apt action.
    
    # Search for matches in the apt log.
    # Read in the last lines of apt history
    # and extract the last apt action.
    while read line; do
        if [ "x$line" = "x" ]; then
            break
        else
            echo "$line" >> "$TEMP1"
        fi
    done <<< $(tail /var/log/apt/history.log | tac)
    
    
    # Extract apt Start-Date, End-Date, Commandline.
    apt_start=""
    apt_end=""
    apt_full_command=""
    apt_package=""
    count=0
    
    apt_start=$(grep "Start-Date" "$TEMP1" | sed 's![\(Start-Date:\): -]!!g')
    
    apt_end=$(grep "End-Date" "$TEMP1" | sed 's![\(End-Date:\): -]!!g')
    
    apt_full_command=$(grep "Commandline" "$TEMP1" | sed 's!Commandline: !!')
    
    # Search for matching apt actions.
    # Prepare the first part of the snapper output.
    # Declare the search pattern.
    pattern=("apt-get remove --purge --yes linux-" ".*autoremove" ".*purge" \
    ".*remove" ".*reinstall" ".*install" ".*-upgrade" ".*upgrade")

    
    for value in "${pattern[@]}"; do
        if grep -q -P "$value" <<< "$apt_full_command"; then
            apt_command="$value"
        break
        fi
    done


    case "$apt_command" in
    "apt-get remove --purge --yes linux-")
        apt_package=$( grep -o "image[[:print:]]\+[a-z]" <<< "$apt_full_command" \
        | grep -o "[.0-9]\+-[0-9]")
        apt_command="kernel-rm"
        ;;
    ".*autoremove")
        apt_command="Autoremove"
        apt_package=""
        ;;
    ".*purge")
        apt_command="Purge"
        find_package "$apt_command"
        ;;
    ".*remove")
        apt_command="Remove"
        find_package "$apt_command"
        ;;
    ".*reinstall")
        apt_command="Reinstall"
        find_package "$apt_command"
        ;;
    ".*install")
        apt_command="Install"
        find_package "$apt_command"
        ;;
    ".*-upgrade")
        apt_command="DU"
        apt_package=""
        ;;
    ".*upgrade")
        apt_command="Upgrade"
        find_package "$apt_command"
        ;;
    *)
       echo "Error with $apt_command" >&2
       exit 1
       ;;
    esac

    # The required variables are filled with the values from snapper.
    pre_num=$(echo "$snapper_last_pre" | cut -d "," -f 3)
    pre_date=$(echo "$snapper_last_pre" | cut -d "," -f 8 | sed 's![: -]!!g')
    
    post_num=$(echo "$snapper_last_post" | cut -d "," -f 3)
    post_date=$(echo "$snapper_last_post" | cut -d "," -f 8 | sed 's![: -]!!g')
    
    # compare the timestamps.
    # The apt times must be within those of snapper.
    if [ $pre_date -le $apt_start ] && [ $post_date -ge $apt_end ]; then
        if [ "$count" -gt 1 ]; then
            count=$((count -= 1))
            apt_package="$apt_package +$count pkg"
        fi
        echo "Change snapper's description of snapshots $pre_num and $post_num."
        snapper modify -d "$apt_command $apt_package" "$pre_num" "$post_num"
    fi
else
    # No complete apt action.
    rm "${TEMP1}"
    exit 0
fi
rm "${TEMP1}"
}



# Query the btrfs default subvolume, the booted subvolume, and the grub default menu entry.
# 1) Subvolume, that is set to default in Btrfs
btrfs_default=$(echo "$btrfs_default" | sed -E 's,[^@]*@?,@,')

# 2) Subvolume that was booted into.
booted_subvol=$(btrfs inspect-internal subvolid-resolve $(btrfs inspect-internal rootid /) /)

# 3) Subvolume of the grub default boot entry.
grub_default_menu=$(grep -m 1 -o '/.*/boot/vmlinuz' /boot/grub/grub.cfg | sed 's,/\(.*\)/boot/vmlinuz,\1,')

# Compare the query values and execute action if necessary.
if [ "x${btrfs_default}" = "x${booted_subvol}" ]; then
    if [ "x${btrfs_default}" = "x${grub_default_menu}" ]; then
    # All three queries point to the same subvolume.
    # No rollback done.
        snapper_descripttion
        exit 0
    else
    
    # Btrfs default subvolume and booted subvolume are the same.
    # The grub standard boot entry differs.
    # State after booting into the rollback target first time.
        echo "btrfs default: $btrfs_default"
        echo "booted subvol: $booted_subvol"
        echo "grub default: $grub_default_menu"
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
        rm "${oldbak}"
    fi

    newbak="fstab_btrfs_$(date +%F_%H%M.bak)"
    echo "Backup fstab in the rollback target to $newbak"
    cp "$target_path"/etc/fstab "$target_path"/etc/"$newbak"

    # Now edit .../etc/fstab 
    if [ -w "$target_path"/etc/fstab 2>/dev/null ]; then
        echo "Edit fstab in the rollback target."
        sed -i 's!^\(.* / .*subvol=/\)@[^,]*,\(.*\)!\1'"$btrfs_default"',\2!' "$target_path"/etc/fstab
    fi
    
    # We have to wait for grub-btrfs.
    sleep 5
    
    echo "btrfs default: $btrfs_default"
    echo "booted subvol: $booted_subvol"
    echo "grub default: $grub_default_menu"
    echo "Btrfs default and booted subvolume differ." 
    echo "Run \"update-grub\""
    update-grub

fi

exit 0
