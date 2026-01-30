#!/usr/bin/bash
#
# Name: /usr/share/siduction/snapshot-description.sh
# Part of siduction-btrfs
# Called by /usr/lib/snapper/plugins/50-siduction.sh
#
# Since apt 3.1.6 command history-list and history-info
#

post_num="$1"

#######################
### Begin funktions ###

find_package () {
# Read the first package.from the apt command line.
if grep -P -q "^(apt-get|apt) " <<< $1; then
	apt_package=$(sed -e 's|apt-get | |' \
		-e 's|apt | |' \
		-e 's| --solver 3.0||' \
		-e 's| -\+[^ ]*||g' \
		-e "s|$2||" \
		-e 's|^ \+||' \
		-e 's|^\([^ ]*\)|\1|' <<< $1 | \
		cut -d " " -f 1 | \
		sed 's|:.*||' | \
		grep -P -o "^[a-z0-9_-]+.[a-z0-9]+" )
fi
## regex explanation:
# 's|apt-get | |'			# remove 'apt-get '
# 's|apt | |' \				# remove 'apt '
# 's| --solver 3.0||'		# remove option ' --solver 3.0'
# 's| -\+[^ ]*||g'			# remove options (e.g. ' -f' or ' --quit')
# "s|$2||"					# remove the apt command
# 's|^ \+||'				# remove leading spaces
# 's|^\([^ ]*\)|\1|'		# get only the first package (full name and version)
# cut -d " " -f 1			# cut out the package name
# 's|:.*||'					# remove the variant (e.g. ':amd64')
# "^[a-z0-9_-]+.[a-z0-9]+"	# The name with a maximum of one character other
							# than [a-z0-9] and at least three characters.

if [ "$count" -gt 1 ]; then
	((--count))
	apt_package=" $apt_package +$count pkg"
else
	apt_package=" $apt_package"
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
	pre_num=$(( "$post_num" - 1 ))
else
	# This is not an apt post snapshot.
	echo "$(date  +%T) snapshot-description: No complete apt action." >> /var/log/snapper.log
	exit 0
fi

# Create a secure tmp file.
TEMP1=`mktemp /tmp/sn-description.XXXXXXXXXXXX`  || exit 1
trap "rm -f $TEMP1 2>/dev/null || true" EXIT HUP INT QUIT TERM

# Get the last apt aktion and extrakt the ID and the number
# of packages changed.
last_apt="$(apt history-list 2>/dev/null | tail -n1)"

last_id=$(grep -o "^[0-9]\+" <<< $last_apt)
# The echo command removes all unnecessary spaces.
# This makes 'sed' easier.
count=$(echo $last_apt | sed 's/.* \([0-9]\+\)$/\1/')

# Security test on Integer.
int="^[0-9]+$"
if ! [[ "$last_id" =~ $int ]]; then
	echo "$(date  +%T) snapshot-description: ERROR: Variable last_id is not an integer." >> /var/log/snapper.log && exit 1
elif ! [[ "$count" =~ $int ]]; then
	echo "$(date  +%T) snapshot-description: ERROR: Variable count is not an integer." >> /var/log/snapper.log && exit 1
fi

# Extract the details of the last apt action using 'apt history-info'
# and get the values needed.
apt_start=""
apt_end=""
apt_full_command=""

bash -c "apt history-info $last_id" 1>$TEMP1 2>/dev/null

apt_start=$(grep "Start time:" "$TEMP1" | sed -e 's!^Start time: !!' -e 's![: -]!!g')
apt_end=$(grep "End time:" "$TEMP1" | sed -e 's!^End time: !!' -e 's![: -]!!g')
apt_full_command=$(grep "Command line:" "$TEMP1" | sed 's!Command line: !!')

# Declare the search pattern.
pattern=("apt-get remove --purge --yes linux-" " autoremove" " autopurge" " purge" \
" remove" " reinstall" " install" ".*-upgrade" " upgrade" " synaptic")

# Search for matching apt actions.
for value in "${pattern[@]}"; do
	if grep -q -P "$value" <<< "$apt_full_command"; then
		break
	fi
done

# Create the snapper description depending on the command used.
apt_command=""
apt_package=""

case "$value" in
"apt-get remove --purge --yes linux-")
	apt_command="kernel-rm "
	apt_package=$( grep -o "image[[:print:]]\+[a-z]" <<< "$apt_full_command" \
					| grep -o "[.0-9]\+-[0-9]")
	;;
" autoremove")
	apt_command="autoremove"
	apt_package=" $count pkg"
	;;
" autopurge")
	apt_command="autopurge"
	apt_package=" $count pkg"
	;;
" purge")
	apt_command="purge"
	find_package "$apt_full_command" "$value"
	;;
" remove")
	apt_command="remove"
	find_package "$apt_full_command" "$value"
	;;
" reinstall")
	apt_command="reinstall"
	find_package "$apt_full_command" "$value"
	;;
" install")
	apt_command="install"
	find_package "$apt_full_command" "$value"
	;;
".*-upgrade")
	apt_command="DU"
	apt_package=""
	;;
" upgrade")
	apt_command="upgrade"
	apt_package=" $count pkg"
	;;
" synaptic")
	apt_command="synaptic"
	apt_package=""
	;;
*)
	echo "$(date  +%T) snapshot-description: Can't change the description." >> /var/log/snapper.log
	exit 0
	;;
esac

# Comparing the timestamps of snapper and apt.
# The apt times must be within those of snapper.
if [ $pre_date -le $apt_start ] && [ $post_date -ge $apt_end ]; then
	echo "$(date  +%T) snapshot-description: Change snapper's description of snapshots $pre_num and $post_num." >> /var/log/snapper.log
	snapper modify -d "$apt_command$apt_package" "$pre_num" "$post_num"
else
	echo "$(date  +%T) snapshot-description: No apt action corresponding to the snapshot found." >> /var/log/snapper.log
fi
rm "${TEMP1}"
exit 0
