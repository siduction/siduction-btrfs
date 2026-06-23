#!/bin/bash
#
# Name: /usr/share/siduction/grub-menu-title.sh
# Part of siduction-btrfs
# Called by /usr/lib/systemd/system/siduction_grubmenutitle.service
#        or /usr/lib/snapper/plugins/50-siduction.sh
# Modifies the title of the default boot entry of grub.cfg.

set -e

. /etc/default/grub.d/siduction.cfg
. /etc/os-release

# Determine the booted subvolume.
booted_subvol=$(findmnt -n -o SOURCE / | sed 's|.*\(@.*\)].*|\1|')

if [ "x$booted_subvol" = "x@" ]; then
	default_nr="@"
else
	default_nr=$(cut -d '/' -f 2 <<< "$booted_subvol")
fi

sed -i "s|\(^menuentry '\).*with|\1$GRUB_DISTRIBUTOR $VARIANT snapshot $default_nr,|" /boot/grub/grub.cfg

exit 0
