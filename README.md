# btrfs-boot-menu-settings
Btrfs file system - GRUB and systemd-boot  
Optimizes the boot menu and the description in Snapper

--------

# EN

## Description

Improves the menu after a rollback using snapper or manual change of the Btrfs default subvolume.  
The default boot entry points to the new default subvolume with the kernels present.

The functionality of [grub-btrfs](https://github.com/Antynea/grub-btrfs) remains unaffected.

This project may be of interest for other debin based OS.

**Issues with GRUB that have been worked on:**  
+ The default boot entry always points to the "/@" subvolume using "rootflags=".  
+ For kernel and initrd, the subvolume that was booted into is always used, not the Btrfs default subvolume.  
+ The boot target is not clear from the title.

**Issues with systemd-boot that have been worked on:**  
+ After a rollback, systemd-boot does not create any menu entries for the rollback target.  
+ The default boot target also remains unchanged.  
+ If r/w snapshots are deleted, the corresponding entries remain in the boot menu.

**Issues with description of apt actions in snapper:**  
+ snapper always only displays 'APT' in the description of the snapshots. Regardless of which apt action was executed.

Be sure to read the Info.md file before testing.

--------

# DE

## Beschreibung

Verbessert das Grub Menü nach einem Rollback mittels snapper oder manueller Änderung des Btrfs default Subvolumens.  
Der Standard Booteintrag zeigt auf das neue default Subvolumen mit den dort vonhandenen Kerneln.

Die Funktionalität von [grub-btrfs](https://github.com/Antynea/grub-btrfs) bleibt unberührt.

Dieses Projekt kann für andere Debin basierte OS von Interesse sein.

**Probleme mit GRUB, die bearbeitet wurden:**
+ Der Standard Booteintrag zeigt mittels "rootflags=" immer auf das "/@" Subvolumen.  
+ Für Kernel und initrd wird immer das Subvolumen verwendet, in das gebootet wurde, nicht das Btrfs default Subvolumen.  
+ Aus dem Titel geht das Bootziel nicht hervor.

**Probleme mit systemd-boot, die bearbeitet wurden:**
+ Nach einem Rollback erstellt systemd-boot keine Menüeinträge für das Rollbackziel.  
+ Auch das Standard Bootziel bleibt unverändert.  
+ Werden r/w snapshots gelöscht, verbleiben die korrespondierenden Einträge im Bootmenü.

**Probleme mit Beschreibung von apt-Aktionen in snapper:**
+ snapper gibt in der Beschreibung der Snapshots immer 'APT' aus. Gleichgültig, welche apt-Aktion ausgeführt wurde.

Vor dem Test bitte unbedingt die Datei Info.md lesen.
