#!/bin/bash
#
# Name: /usr/share/siduction-btrfs/test-btrfs-default.sh
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

export TERM="xterm-256color"

# Wait 2 seconds.
# If a rollback starts, it is safer to wait for the second snapshot.
sleep 2

# Check if Btrfs. Get default subvolume.
if ! btrfs_default=$(btrfs subvolume get-default / 2>/dev/null); then
    echo "No Btrfs found on /"
    exit 0
fi

# Check filesystem write permission. Cancel if boot into
# a read only subvolume.
if [ ! -w / ]; then
    echo "Execution canceled. No write permission."
    exit 1
fi


###################################
######### Begin funktions #########
###################################

find_package () {
# Search for the first package and the total number of packages
# for the given action.
# Snapper outputs the values in the description.

# Reading in the package line.
if grep -q "$1" "$TEMP1"; then
    pkg=$(grep "$1" "$TEMP1")

    # Cut out the given action.
    pkg=${pkg#$1: }

    # Read out the first package.
    apt_package=$(sed 's|[- ].*||' <<< ${pkg%%:*})

    # Counting the total number of packages.
    for i in $pkg; do
        if [ $(grep '^[a-z]' <<< $i) ]; then
            ((++count))
        fi
    done
else
    # Reverts to the original command if apt modifies the
    # command internally and therefore no package was found.
    apt_package=" "
fi
}


snapper_descripttion () {
# The btrfs default subvolume, the booted subvolume, and the
# default menu entry (only grub) point to the same subvolume.
# The new snapshot maybe based on an apt action.
# We search for pre and post snapshots in snapper and the
# corresponding action in the apt log file.
#
# We are looking for a complete apt action in snapper's newest
# entries. If the action has not yet been completed, the entire
# block is skipped and the script is terminated.
if snapper_last_post=$(snapper --no-headers --machine-readable csv list \
  | tail -n 1 | grep ",apt," | grep ",post,") && \
  snapper_last_pre=$(snapper --no-headers --machine-readable csv list \
  | tail -n 2 | grep ",apt," | grep ",pre,"); then
    # Snapper logged a complete apt action.
    
    TEMP1=`mktemp /tmp/test-btrfs.XXXXXXXXXXXX`  || exit 1
    trap "rm -f $TEMP1 2>/dev/null || true" EXIT HUP INT QUIT TERM
    
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
    ".*remove" ".*reinstall" ".*install" ".*-upgrade" ".*upgrade" ".*synaptic")

    
    for value in "${pattern[@]}"; do
        if grep -q -P "$value" <<< "$apt_full_command"; then
            apt_command="$value"
        break
        fi
    done


    case "$apt_command" in
    "apt-get remove --purge --yes linux-")
        apt_command="kernel-rm"
        apt_package=$( grep -o "image[[:print:]]\+[a-z]" <<< "$apt_full_command" \
        | grep -o "[.0-9]\+-[0-9]")
        ;;
    ".*autoremove")
        apt_command="Remove"
        find_package "$apt_command"
        apt_command="Autoremove"
        count=$((count += 1))
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
    ".*synaptic")
        apt_command="synaptic"
        apt_package=""
        ;;
    *)
       echo "Can't change the description."
       exit 0
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
            if [ "x$apt_command" = "xAutoremove" ]; then
                apt_package="$count pkg"
            else
                apt_package="$apt_package +$count pkg"
            fi
        fi
        echo "Change snapper's description of snapshots $pre_num and $post_num."
        snapper modify -d "$apt_command $apt_package" "$pre_num" "$post_num"
    fi
    rm "${TEMP1}"
else
    echo "No complete apt action."
fi
}

###################################
########## End funktions ##########
###################################


# Query the btrfs default subvolume, the booted subvolume,
# and determine the subvolume of the Grub default boot entry.
# If Grub is not present, check whether systemd-boot is installed.
# Call the appropriate function.
# If neither of the two boot managers is found, output an error message.

# 1) Subvolume, that is set to default in Btrfs
if ! grep -q "@" <<< ${btrfs_default}; then
    btrfs_default="@"
else
    btrfs_default=$(sed -E 's|[^@]*@|@|' <<< ${btrfs_default})
fi
export btrfs_default


if grep -q '/' <<< "$btrfs_default"; then
	default_nr=$(cut -d '/' -f 2 <<< "$btrfs_default")
	key=$((10000 - "$default_nr"))
else
	default_nr="@"
	key="10000"
# $key is only required in btrfs-sdboot-menu.sh.
fi

# 2) Subvolume that was booted into.
booted_subvol=$(btrfs inspect-internal subvolid-resolve $(btrfs inspect-internal rootid /) /)
if grep -q '/' <<< "$booted_subvol"; then
	booted_nr=$(cut -d '/' -f 2 <<< "$booted_subvol")
else
	booted_nr="@"
fi

# 3) Grub default boot entry or whether systemd-boot is installed.
if [ -e /boot/grub/grub.cfg ] && [ -w /boot/grub/grub.cfg ]; then
    grub_default_menu=$(grep -m 1 -o '/.*/boot/vmlinuz' /boot/grub/grub.cfg | \
    sed 's,/\(.*\)/boot/vmlinuz,\1,')

    # Compare the query values and execute action if necessary.
    if [ "x${btrfs_default}" = "x${booted_subvol}" ]; then
        if [ ! "x${btrfs_default}" = "x${grub_default_menu}" ]; then
        
        # Btrfs default subvolume and booted subvolume are the same.
        # The grub standard boot entry differs.
        # State after booting into the rollback target first time.
            echo "btrfs default: $btrfs_default"
            echo "booted subvol: $booted_subvol"
            echo "grub default: $grub_default_menu"
            echo "Btrfs default subvolume and Grub default menu item differ."
            echo "Run \"update-grub\" and \"grub-install\""
            /usr/sbin/update-grub
            
        # Search for grub installation target.
        # 1) EFI GPT
            if [ -x /boot/efi ]; then
                echo "Found EFI. Install grub."
                /usr/sbin/grub-install
            else
        
        # 2) MBR BIOS
                list=$(mount | grep '^/dev/[sn]' | cut -d " " -f 1 | sed 's!p\?[0-9]\+$!!' | uniq)
                for i in $list; do
                    dd if="$i" count=4000 2>/dev/null | \
                    if [ $(grep --no-ignore-case -ao GRUB) ]; then
                        echo "Found MBR. Install grub to $i."
                        /usr/sbin/grub-install "$i"
                    else
                        echo "Error: No installation target found for grub"
                        exit 1
                    fi
                done
            fi
        
        else
        # All three queries point to the same subvolume.
        # No rollback done.
            snapper_descripttion
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
        
        # Adapt the files /etc/os-release and /etc/kernel/entry-token
        # in the rollback target.
        # This is not absolutely necessary. However, it increase
        # compatibility with systemd.
        sed -i "s|shot .*|shot $default_nr\"|" $target_path/etc/os-release
        sed -i "s|shot-.*|shot-$default_nr|" $target_path/etc/kernel/entry-token
        
        # We have to wait for grub-btrfs.
        sleep 5
        
        echo "btrfs default: $btrfs_default"
        echo "booted subvol: $booted_subvol"
        echo "grub default: $grub_default_menu"
        echo "Btrfs default and booted subvolume differ." 
        echo "Run \"update-grub\""
        /usr/sbin/update-grub
    fi
    
    # or is systemd-boot installed.
elif dpkg-query -f='${Status}' -W systemd-boot | grep -q "ok installed"; then

    # Search for the installation directory of systemd-boot.
    for sd_boot_dir in "/boot" "/efi" "/boot/efi"; do
        if findmnt "$sd_boot_dir" &> /dev/null; then
            menu_dir="$sd_boot_dir/loader/entries/"
            break
        fi
    done

    # Search for menu items.
    entry_part=$(sed 's|-[0-9@]\+$|-|' /etc/kernel/entry-token)

    # Array of boot entries.
    subv_entry=($(find "$sd_boot_dir" -type d -name "$entry_part*" | \
                 grep -o '[0-9@]\+$'))

    # Ceck for rollback.
    if snapper list | tail -n1 | grep -q "writable" \
       && snapper list | tail -n2 | grep -q "rollback" \
       && [ ! "$default_nr" = "@" ]; then
       
        # Rollback found. Check if menuentry already exists.
        if ls "$sd_boot_dir" | grep -Pq "$entry_part$default_nr"; then
            # Menuentry already exists. Nothing to do.
            echo "Entry already exists."
        else
            # Create a menu entry for the rollback target.
            echo "Create new entry."
            
            filesystem=$(findmnt -n -o FSTYPE "$sd_boot_dir")
            mountdev=$(findmnt -n -o SOURCE "$sd_boot_dir")
            
            # Determine root partition.
            root_dev=$(grep ' / ' /proc/mounts | cut -d ' ' -f 1)

            # Create a temporary mount directory.
            tmp_dir=`mktemp -d /tmp/sn-mount.XXXXXXXXXXXX`  || exit 1
            trap "umount -R $tmp_dir; rmdir $tmp_dir" KILL EXIT SYS TERM HUP

            # Mount rollback target.
            mount -t btrfs -o subvol=/${btrfs_default} ${root_dev} ${tmp_dir}

            # Create the file /etc/kernel/cmdline in the rollback target.
            tr -s "$IFS" '\n' </proc/cmdline | grep -ve '^BOOT_IMAGE=' -e '^initrd=' | \
                tr '\n' ' ' | sed "s#\(^.*subvol=\)[^ ]\+#\1$btrfs_default#" \
                >${tmp_dir}/etc/kernel/cmdline   #"

            # Adapt the file /etc/kernel/entry-token  in the rollback target.
            sed -i "s|ot-.*|ot-$default_nr|" ${tmp_dir}/etc/kernel/entry-token
            entry_dir=$(cat ${tmp_dir}/etc/kernel/entry-token)

            # Adapt the file /etc/os-release in the rollback target.
            sed -i "s|shot .*|shot $default_nr\"|" ${tmp_dir}/etc/os-release

            # bind mounts
            for i in "/proc" "/run" "/sys" "/dev"; do
                mount --rbind ${i} ${tmp_dir}${i} && mount --make-rslave ${tmp_dir}${i}
            done

            # Chroot into new default subvolume
            export filesystem
            export mountdev
            export sd_boot_dir
            . /etc/os-release
            export VARIANT_ID
            export entry_dir
            export key

            chroot ${tmp_dir} /bin/bash -x << 'EOF'

            mount -t "$filesystem" "$mountdev" "$sd_boot_dir"
            if ! findmnt "/efi" &>/dev/null; then
                mount /efi 2>/dev/null
            fi

            modlist=($(ls /usr/lib/modules/))

            for i in "${modlist[@]}"; do
                match=$(grep "$i" <<< $(ls $sd_boot_dir/vmlinu*))
                if [ "X${match:+1}" = "X1" ]; then
                dpkg-reconfigure "linux-image-$i"
                
                # Change the sort-key in the menu entry.
                sed -i "s|ey .*|ey   $VARIANT_ID-$key|" $sd_boot_dir/loader/entries/$entry_dir-$i.conf
                fi
            done

            # Change the default boot entry to the default subvolume.
            if findmnt "/efi" &>/dev/null; then
                sed -i "s|^default.*$|default $entry_dir-*|" /efi/loader/loader.conf
            else
                sed -i "s|^default.*$|default $entry_dir-*|" /$sd_boot_dir/loader/loader.conf
            fi

            # Adapt /etc/fstab before ${tmp_dir} is unmounted.
                sed -i "s|\(^.* / .*subvol=\)[^,]\+|\1/${btrfs_default}|" etc/fstab

            umount "$sd_boot_dir"
            umount /efi 2>/dev/null
EOF

        fi
        exit 0

    elif (( ${#subv_entry[*]} >= 2 )); then
        # Check for remaining menu entries of deleted subvolumes.
        # Snapper must list at least one r/w snapshot and
        # there must also be at least two boot entries.

        # List of r/w snapshots by snapper.
        if grep -q "writable" <<< $(snapper list); then
            subv_rw=$(grep "writable" <<< $(snapper --machine-readable csv list) | \
                   cut -d "," -f 3)

            # Are there more entries than r/w subvolumes?
            if [ ! ${#subv_entry[*]} = $(echo "$subv_rw" | wc -l) ] ; then

                # Remove the orphaned ones.
                for nr in "${subv_entry[@]}"; do
                    if ! grep -q "$nr" <<< "$subv_rw"; then
                        echo "Remove directory $sd_boot_dir/$entry_part$nr"
                        rm -r "$sd_boot_dir/${entry_part:?}${nr:?}"
                        if find "$menu_dir" -type f -name "$entry_part$nr*" &>/dev/null; then
                            echo "Remove menu entry $menu_dir$entry_part$nr*"
                            rm $menu_dir${entry_part:?}${nr:?}*
                        fi
                    fi
                done

                # Change the default boot entry to the default subvolume.
                if findmnt "/efi" &>/dev/null; then
                    sed -i "s|^default.*$|default $entry_part$default_nr-*|" /efi/loader/loader.conf
                else
                    sed -i "s|^default.*$|default $entry_part$default_nr-*|" /$sd_boot_dir/loader/loader.conf
                fi
            fi
        exit 0
        fi
    else
        snapper_descripttion
    fi
else
    snapper_descripttion
    echo "Neither Grub nor systemd-boot found."
fi
exit 0

