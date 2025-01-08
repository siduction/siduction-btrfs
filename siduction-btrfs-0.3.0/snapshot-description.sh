#!/usr/bin/bash
#
# Name: /usr/share/siduction/snapshot-description.sh
# Part of siduction-btrfs
#

set -e

post_num="$1"

#######################
### Begin funktions ###

find_package () {
# Search for the first package of the given action.
# Read the first package.from the command line.
if grep -P -q " (apt-get|apt) " <<< $2; then
	apt_package=$(sed -e 's|apt-get | |' \
		-e 's|apt | |' \
		-e 's| --solver 3.0||' \
		-e 's| -\+[^ ]*||g' \
		-e "s|$3||" \
		-e 's|^ \+||' \
		-e 's|^\([^ ]*\)|\1|' <<< $2 | \
		cut -d " " -f 1 | \
		grep -o -P "^[a-z0-9_-]+.[a-z0-9]+" )
fi

# Read in the package line.
if pkg=$(grep "$1" "$TEMP1"); then
	# Cut out the given action.
	pkg=${pkg#$1: }

else

# APT internally changed the command.
# Search for the command used.
	if [ "X$1" = "XInstall" ]; then
		if pkg=$(grep "Upgrade" "$TEMP1"); then
			pkg=${pkg#Upgrade: }
		fi
	elif [ "X$1" = "XReinstall" ]; then
		if pkg=$(grep "Install" "$TEMP1"); then
			pkg=${pkg#Install: }
		elif pkg=$(grep "Upgrade" "$TEMP1"); then
			pkg=${pkg#Upgrade: }
		fi
	elif [ "X$1" = "XRemove" ]; then
		if pkg=$(grep "Purge" "$TEMP1"); then
			pkg=${pkg#Purge: }
		fi
	fi
fi
count_packages
}

count_packages () {
# Cleanup extended package description and
# counting the total number of packages.

pkg=$(sed 's| ([^)]*),\?||g' <<< $pkg)

for i in $pkg; do
	if [ $(grep '^[a-z]' <<< "$i") ]; then
		((++count))
	fi
done
}

### End funktions ###
#####################

# The new snapshot maybe based on an apt action.
# We search for post snapshots with apt action in snapper
# and the corresponding action in the apt log file.
if snapper_last_post=$(snapper --no-headers --machine-readable csv list \
  | tail -n 1 | grep ",$post_num,.*,post,.*,apt,"); then
	snapper_last_pre=$(snapper --no-headers --machine-readable csv list \
	  | tail -n 2 | grep ",pre,.*,apt,")

	# The required variables are filled with the values from snapper.
	post_date=$(echo "$snapper_last_post" | cut -d "," -f 8 | sed 's![: -]!!g')
	pre_date=$(echo "$snapper_last_pre" | cut -d "," -f 8 | sed 's![: -]!!g')
	pre_num=$(( "$post_num" - 1 ))
else
	# This is not an apt post snapshot.
	echo "$(date  +%T) snapshot-description: No complete apt action." >> /var/log/snapper.log
	exit 0
fi

TEMP1=`mktemp /tmp/sn-description.XXXXXXXXXXXX`  || exit 1
trap "rm -f $TEMP1 2>/dev/null || true" EXIT HUP INT QUIT TERM


# Search for matches in the apt log.
# Read in the last lines of apt history
# and extract the last apt action.
while read line; do
	if [ "X$line" = "X" ]; then
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

apt_start=$(grep "Start-Date" "$TEMP1" | sed -e 's!^Start-Date!!' -e 's![: -]!!g')
apt_end=$(grep "End-Date" "$TEMP1" | sed -e 's!^End-Date!!' -e 's![: -]!!g')
apt_full_command=$(grep "Commandline" "$TEMP1" | sed 's!Commandline:!!')

# Search for matching apt actions.
# Prepare the first part of the snapper output.
# Declare the search pattern.
pattern=("apt-get remove --purge --yes linux-" " autoremove" " autopurge" " purge" \
" remove" " reinstall" " install" ".*-upgrade" " upgrade" " synaptic")

for value in "${pattern[@]}"; do
	if grep -q -P "$value" <<< "$apt_full_command"; then
		break
	fi
done

case "$value" in
"apt-get remove --purge --yes linux-")
	apt_command="kernel-rm"
	apt_package=$( grep -o "image[[:print:]]\+[a-z]" <<< "$apt_full_command" \
	| grep -o "[.0-9]\+-[0-9]")
	;;
" autoremove")
	apt_command="Remove"
	pkg=$(grep "Remove" "$TEMP1")
	pkg=${pkg#Remove: }
	count_packages
	((++count))
	apt_command="Autoremove"
	;;
" autopurge")
	apt_command="Purge"
	pkg=$(grep "Purge" "$TEMP1")
	pkg=${pkg#Purgee: }
	count_packages
	((++count))
	apt_command="Autopurge"
	;;
" purge")
	apt_command="Purge"
	find_package "$apt_command" "$apt_full_command" "$value"
	;;
" remove")
	apt_command="Remove"
	find_package "$apt_command" "$apt_full_command" "$value"
	;;
" reinstall")
	apt_command="Reinstall"
	find_package "$apt_command" "$apt_full_command" "$value"
	;;
" install")
	apt_command="Install"
	find_package "$apt_command" "$apt_full_command" "$value"
	;;
".*-upgrade")
	apt_command="DU"
	apt_package=""
	;;
" upgrade")
	apt_command="Upgrade"
	apt_package=""
	;;
" synaptic")
	apt_command="synaptic"
	apt_package=""
	;;
*)
	echo "snapshot-description: Can't change the description." >> /var/log/snapper.log
	exit 0
	;;
esac

# Comparing the timestamps of snapper and apt.
# The apt times must be within those of snapper.
if [ $pre_date -le $apt_start ] && [ $post_date -ge $apt_end ]; then
	if [ "$count" -gt 1 ]; then
		((--count))
		if [ "x$apt_command" = "xAutoremove" ] || [ "x$apt_command" = "xAutopurge" ]; then
		apt_package="$count pkg"
		else
		apt_package="$apt_package +$count pkg"
		fi
	fi
	echo "$(date  +%T) snapshot-description: Change snapper's description of snapshots $pre_num and $post_num." >> /var/log/snapper.log
	snapper modify -d "$apt_command $apt_package" "$pre_num" "$post_num"
else
	echo "$(date  +%T) snapshot-description: No apt action corresponding to the snapshot found." >> /var/log/snapper.log
fi
rm "${TEMP1}"
exit 0
