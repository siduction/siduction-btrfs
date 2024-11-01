#!/bin/bash
#
# Name: /usr/share/siduction/snapshot-description.sh
# Part of siduction-btrfs
#

set -e

post_num="$1"

#######################
### Begin funktions ###

find_package () {
# Search for the first package and the total number of packages
# for the given action.
# Snapper outputs the values in the description.

# Reading in the package line.
if pkg=$(grep "$1" "$TEMP1"); then
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
	pre_num=$post_num && ((--pre_num))
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
	echo "snapshot-description: Can't change the description." >> /var/log/snapper.log
	exit 0
	;;
esac

# Comparing the timestamps of snapper and apt.
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
	echo "$(date  +%T) snapshot-description: Change snapper's description of snapshots $pre_num and $post_num." >> /var/log/snapper.log
	snapper modify -d "$apt_command $apt_package" "$pre_num" "$post_num"
else
	echo "$(date  +%T) snapshot-description: No apt action corresponding to the snapshot found." >> /var/log/snapper.log
fi
rm "${TEMP1}"
exit 0

