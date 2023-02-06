#! /bin/bash
set -e
#
# Name: install.sh
# Part of siduction-btrfs
# Execute as root in same folder where
#         siduction_btrfs.service
#         siduction_btrfs.timer
#         siduction_btrfs.path
#         test-btrfs-default.sh
#         09_siduction-btrfs

cp 09_siduction-btrfs /etc/grub.d/
chown root:root /etc/grub.d/09_siduction-btrfs
chmod 755 /etc/grub.d/09_siduction-btrfs

cp siduction_btrfs.* /usr/lib/systemd/system/
chown root:root /usr/lib/systemd/system/siduction_btrfs.*
chmod 644 /usr/lib/systemd/system/siduction_btrfs.*

cp test-btrfs-default.sh /usr/share/siduction/
chown root:root /usr/share/siduction/test-btrfs-default.sh
chmod 755 /usr/share/siduction/test-btrfs-default.sh

echo "systemd enable"
systemctl enable --now siduction_btrfs.timer siduction_btrfs.path
