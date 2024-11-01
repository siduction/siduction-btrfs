## EN

### preface

The package **siduction-btrfs** improves the boot menu of the boot managers GRUB and systemd-boot for a siduction installed on Btrfs file system.  
It can be used on systems with MBR and GPT partition tables, with or without a separate /boot partition.  
But it does not replace the basic understanding of the function of the Btrfs file system, its subvolumes and snapshots.  
In addition, it improves the description of apt actions in the list output by snapper.

### Partitioning

For UEFI systems, the boot manager **GRUB** requires the ESP to be mounted under */boot/efi*, whereby the ESP must be the first partition on the medium.  
In MBR systems the ESP is not necessary, and the directory */boot/efi* is not created. Instead, the installation target must be specified when installing the boot manager. For example *"/dev/sda"*.  
A BOOT partition is possible, but does not make sense in combination with Btrfs and GRUB. The subvolume of the root directory "/" must not extend over several media. It must be located on one medium in one partition.

The boot manager **systemd-boot** can only be used with UEFI systems.  
Here too, the first partition on the medium must be the ESP. An XBOOTLDR partition is strongly recommended. The partition with the subvolume of the root directory "/", the ESP, and the XBOOTLDR partition must all be on one medium.  
The XBOOTLDR partition is mounted under */boot*.  
The ESP is mounted under */efi*, or in the absence of the XBOOTLDR under */boot*.  
**Important:** systemd-boot strongly advises against mounting the ESP under */boot/efi* and as a result this is not supported by siduction-btrfs.

### Involved components

+ Btrfs with subvolumes (With Btrfs, snapshots are also subvolumes, just with default contents).  
+ Snapper as frontend for Btrfs  
+ Bootmanager GRUB  
+ Bootmanager systemd-boot  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), which is very helpful. Its functionality remains unchanged.  
+ The siduction-btrfs package, it contains  
*siduction_btrfs* systemd units  
and the scripts  
*/usr/lib/snapper/plugins/50-siduction.sh*  
*/usr/share/siduction/rollback-grub.sh*  
*/usr/share/siduction/grub-menu-title.sh  
*/usr/share/siduction/rollback-sd-boot.sh*  
*/usr/share/siduction/snapshot-description.sh*  
*/usr/lib/kernel/install.d/91-siduction-entry-key.install*

### How the package works

As of version 0.3.0, siduction-btrfs uses the Snapper plugin directory.  
There the script *50-siduction* listens to the Snapper actions in the root subvolume and executes the scripts *snapshot-description*, *rollback-grub*, *grub-menu-title*, or *rollback-sd-boot* if required.  
To manage snapshots, snapper-gui is quite useful. However, a rollback requires a terminal with root rights.

**When using the boot manager GRUB**  
After a rollback, the file */boot/grub/grub.cfg* is recreated in the rollback target using chroot and GRUB is then reinstalled from the rollback target. This allows the user to access the rollback target directly with a simple reboot. All other subvolumes, including the previously used one, can be accessed via the *siduction snapshots* submenu.  
If the */boot/grub/grub.cfg* file is updated during a software installation or upgrade, the *grub-menu-title* script adds the flavor and subvolume to the menu line of the default boot entry.

**When using the boot manager systemd-boot**  
After a rollback, the *rollback-sd-boot* script creates the boot entries. It takes into account all kernels contained in the new snapshot. The default boot entry is set to the default subvolume.  
If a subvolume is deleted for which boot entries existed, these are removed.

**Snapper snapshot description**  
Following an APT action, the *snapshot-description* script changes the description displayed by Snapper (apt) to a more meaningful text.

---------

## DE

### Vorwort

Das Paket **siduction-btrfs** verbessert bei einem auf Btrfs installierten siduction das Bootmenü der Bootmanager GRUB und systemd-boot.  
Es ist auf Systemen mit MBR und GPT Partitionstabellen, und jeweils ohne oder mit einer separaten /boot Partition verwendbar.  
Aber es ersetzt nicht das grundlegende Verständnis der Funktion des Btrfs Dateisystems, seiner Subvolumen und Snapshots.  
Zusätzlich verbessert es die Beschreibung von apt Aktionen in der durch snapper ausgegebenen Liste.

### Partitionierung

Der Bootmanager **GRUB** verlangt bei UEFI Systemen die Einhängung der ESP unter */boot/efi*, wobei die ESP die erste Partition auf dem Medium sein muss.  
In MBR Systemen ist die ESP nicht notwendig und das Verzeichnis */boot/efi* wird nicht erstellt. Dafür muss bei der Installation des Bootmanagers das Installationsziel angegeben werden. Zum Beispiel *"/dev/sda"*.  
Eine BOOT Partition ist möglich, aber im Zusammenhang mit Btrfs und GRUB nicht sinnvoll. Das Subvolumen des Wurzelverzeichnisses "/" darf sich nicht über mehrere Medien erstrecken. Es muss sich auf einem Medium in einer Partition befinden.

Der Bootmanager **systemd-boot** ist nur mit UEFI Systemen verwendbar.  
Auch hier muss die erste Partition auf dem Medium die ESP sein. Eine XBOOTLDR Partition wird ausdrücklich empfohlen. Die Partition mit dem Subvolumen des Wurzelverzeichnisses "/", die ESP und die XBOOTLDR Partition müssen sich alle auf einem Medium befinden.  
Die XBOOTLDR Partition wird unter */boot* eingehangen.  
Die ESP hängt man unter */efi*, oder bei Abwesenheit der XBOOTLDR unter */boot* ein.  
**Wichtig:** Von einer Einhängung der ESP unter */boot/efi* rät systemd-boot dringend ab und in der Folge unterstützt siduction-btrfs dies nicht.

### Beteiligten Komponenten

+ Btrfs mit Subvolumen (Für Btrfs sind Snapshots auch Subvolumen, nur mit einem vorgegebenen Inhalt.)  
+ Snapper als Frontend für Btrfs  
+ Bootmanager GRUB  
+ Bootmanager systemd-boot  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), das sehr hilfreich ist. Seine Funktionalität bleibt unverändert erhalten.  
+ Das Paket siduction-btrfs, es beinhaltet  
*siduction_btrfs* systemd Units  
und die Skripte  
*/usr/lib/snapper/plugins/50-siduction.sh*  
*/usr/share/siduction/rollback-grub.sh*  
*/usr/share/siduction/grub-menu-title.sh  
*/usr/share/siduction/rollback-sd-boot.sh*  
*/usr/share/siduction/snapshot-description.sh*  
*/usr/lib/kernel/install.d/91-siduction-entry-key.install*

### Wie das Paket arbeitet

Ab Version 0.3.0 verwendet siduction-btrfs das Snapper Plugin Verzeichnis.  
Dort lauscht das Skript *50-siduction* auf die Snapper Aktionen im root Subvolumen und führt bei Bedarf die Skripte *snapshot-description*, *rollback-grub*, *grub-menu-title* oder *rollback-sd-boot* aus.  
Um Schnappschüsse zu verwalten, ist snapper-gui ganz nützlich. Ein Rollback jedoch erfordert ein Terminal mit root Rechten.

**Bei Verwendung des Bootmanagers GRUB**  
Nach einem Rollback wird im Rollbackziel mittels chroot die Datei */boot/grub/grub.cfg* neu erstellt und anschließend aus dem Rollbackziel heraus GRUB neu installiert. Dadurch gelangt der User mit einem einfachen Reboot direkt in das Rollbackziel. Alle anderen Subvolumen, auch das zuvor verwendete, sind über das Untermenü *siduction snapshots* erreichbar.  
Wird bei Software Installation oder Upgrade die Datei */boot/grub/grub.cfg* aktualisiert, erweitert das Skript *grub-menu-title* die Menüzeile des Standardbooteintrages um das Flavor und das Subvolumen.

**Bei Verwendung des Bootmanagers systemd-boot**  
Nach einem Rollback erstellt das Skript *rollback-sd-boot* die Booteinträge. Dabei berücksichtigt es alle im neuen Snapshot enthaltenen Kernel. Der Standardbooteintrag wird auf das Standardsubvolumen gesetzt.  
Wird ein Subvolumen gelöscht für das Booteinträge bestanden, werden diese entfernt.

**Snapper Snapshot Beschreibung**  
Im Anschluss an eine APT Aktion ändert das Skript *snapshot-description* die von Snapper angezeigte Beschreibung (apt) zu einem aussagekräftigeren Text.

