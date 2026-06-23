#!/bin/bash
#
# Name: /usr/share/tuxedo-btrfs/grub-menu-title.sh
# Part of tuxedo-btrfs
# Called by /usr/lib/systemd/system/tuxedo_grubmenutitle.service
#        or /usr/lib/snapper/plugins/50-tuxedo.sh
# Modifies the title of the default boot entry of grub.cfg.

set -e

. /etc/default/grub.d/tuxedo.cfg
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
