# btrfs-boot-menu-settings
Btrfs file system - GRUB and systemd-boot  
Optimizes the boot menu and the description in Snapper

--------

## EN

### Description

The standard boot entry boots into the rollback target after a rollback with snapper.  
The subvolume is specified in the title of the boot menu.  
Improves the description of APT pre- and postsnapshot in the list output by Snapper.

The functionality of [grub-btrfs](https://github.com/Antynea/grub-btrfs) remains unaffected.

**Issues with GRUB that have been worked on:**  
+ The standard boot entry is not adjusted after a rollback.  
+ The file /boot/grub/grub.cfg in the rollback target is not adjusted.  
+ GRUB continues to read the /boot/grub/grub.cfg file from the subvolume from  
  which it read the file before the rollback. The rollback target can only be  
  booted via the menu of the *grub-btrfs* extension.

**Issues with systemd-boot that have been worked on:**  
+ After a rollback, systemd-boot does not create any menu entries for the rollback target.  
+ The default boot target also remains unchanged.  
+ The boot entries of deleted r/w snapshots entries remain in the boot menu.

**Issues with description of apt actions in snapper:**  
+ Snapper always only displays 'apt' in the description of the snapshots.  
  Regardless of which apt action was executed.

Be sure to read the Info.md file before testing.

--------

## DE

### Beschreibung

Der Standardbooteintrag bootet nach einem Rollback mit Snapper in das Rollbackziel.  
Im Titel des Bootmenüs wird das Subvolumen angegeben.  
Verbessert die Beschreibung von APT Pre- und Postsnapshot in der durch Snapper  
ausgegebenen Liste.

Die Funktionalität von [grub-btrfs](https://github.com/Antynea/grub-btrfs) bleibt unberührt.

**Probleme mit GRUB, die bearbeitet wurden:**  
+ Nach einem Rollback wird der Standardbooteintrag nicht angepasst.  
+ Die Datei /boot/grub/grub.cfg im Rollbackziel wird nicht angepasst.  
+ GRUB liest die Datei /boot/grub/grub.cfg weiterhin aus dem Subvolumen, aus dem  
  es die Datei vor dem Rollback las. Das booten des Rollbackziels ist nur über  
  das Menü der Erweiterung *grub-btrfs* möglich.

**Probleme mit systemd-boot, die bearbeitet wurden:**  
+ Nach einem Rollback erstellt systemd-boot keine Menüeinträge für das Rollbackziel.  
+ Auch das Standard Bootziel bleibt unverändert.  
+ Von gelöschten r/w Snapshots verbleiben die Booteinträge im Menü.

**Probleme mit der Beschreibung von apt Aktionen in snapper:**  
+ Snapper gibt in der Beschreibung der Snapshots immer 'apt' aus. Gleichgültig  
  welche apt Aktion ausgeführt wurde.

Vor dem Test bitte unbedingt die Datei Info.md lesen.

