# EN

## preface

The package **siduction-btrfs** improves the boot menu of the boot managers GRUB and systemd-boot for a siduction installed on Btrfs file system.  
It does not replace the basic understanding of the function of the Btrfs file system, its subvolumes and snapshots.  
In addition, it improves the description of apt actions in the list output by snapper.

### Involved components

+ Btrfs with subvolumes (With Btrfs, snapshots are also subvolumes, just with default contents).  
+ Bootmanager GRUB  
+ Bootmanager systemd-boot  
+ Snapper as frontend for Btrfs  
+ Manual Btrfs commands  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), which is very helpful. Its functionality remains unchanged.  
+ The package *siduction-btrfs* with the *siduction_btrfs* systemd units and the scripts *09_siduction-btrfs* and *test-btrfs-default*.

### How the package works

**systemd units and the script 'test-btrfs-default'**

The systemd units activate the script after every system start and whenever a snapshot of **`/`** has been created.  
The script checks whether the Btrfs default, the booted subvolume and the default menu entry are different. If this is the case after a rollback, for example, the boot menu is adjusted. The default menu entry now boots the new default subvolume.  
If snapper generates new snapshots due to an apt action, the *test-btrfs-default* script evaluates the apt action and improves the description used by snapper.

**When using the boot manager GRUB**

+ **Basic function of '90_siduction-btrfs'**  
  The numbering (09\_) causes Grub to execute the file before *10_linux*. This is necessary to prevent duplicate entries in the Grub menu.  
  If the file system is Btrfs, the file *10_linux* is stripped of the execution rights and *09_siduction-btrfs* creates the Grub default menu items.  
  If the file system is **not** Btrfs, the file revokes its own execution rights and exits without editing the Grub menu file. Henceforth, Grub ignores it when updating the menu.

+ **Changes from '10_linux'**  
  The default entry in the grub menu contains the boot target in the form of *subvolume @* or *snapshot #*. Thus the user immediately recognizes the boot target and can select another one in the submenu "siduction snapshots" if necessary.  
  The Grub function `make_system_path_relative_to_its_root /` (10_linux from line 84) always generates the kernel option *rootflags=subvol=@*. This is only correct as long as Btrfs does not know a default subvolume, or no rollback has been done. This is a known bug in Debian based OS.  
  Grub does not use the Btrfs default subvolume for the paths to the kernel and initrd, but the subvolume that was booted into. After a rollback, they differ.  
  The file *09_siduction-btrfs* determines the Btrfs default subvolume and generates the default boot entry in the Grub menu with these values. All other subvolumes are provided by *grub-btrfs* in the submenu "siduction snapshots". A simple reboot thus leads to the rollback target.

If the user decides to reset the btrfs default subvolume to "@", which should only be done with proper preparation and knowledge, the correct default entry is created in the grub menu. Previously, editing the kernel and initrd boot lines was necessary.

**When using the boot manager systemd-boot**  
  
+  **Partitioning**  
  systemd-boot is only available for UEFI systems with GPT data carriers and requires an ESP (Efi System Partition). The *test-btrfs-default* script takes the various partitioning options into account when processing the boot entries.
  
+  **snapper actions**  
  If r/w snapshots are created, for example by rollback, the script generates corresponding boot entries. It takes into account all kernels contained in the new snapshot.  
  After r/w snapshots have been deleted, the script removes the corresponding boot entries.

---------

# DE

## Vorwort

Das Paket **siduction-btrfs** verbessert bei einem auf Btrfs installierten siduction das Bootmenü der Bootmanager GRUB und systemd-boot.  
Es ersetzt nicht das grundlegende Verständnis der Funktion des Btrfs Dateisystems, seiner Subvolumen und Snapshots.  
Zusätzlich verbessert es die Beschreibung von apt-Aktionen in der durch snapper ausgegebenen Liste.

### Beteiligten Komponenten

+ Btrfs mit Subvolumen (Für Btrfs sind Snapshots auch Subvolumen, nur mit einem vorgegebenen Inhalt.)  
+ Bootmanager GRUB  
+ Bootmanager systemd-boot  
+ snapper als Frontend für Btrfs  
+ Manuelle Btrfs Kommandos  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), das sehr hilfreich ist. Seine Funktionalität bleibt unverändert erhalten.  
+ Das Paket *siduction-btrfs* mit den *siduction_btrfs* systemd Units und den Skripten *09_siduction-btrfs* und *test-btrfs-default*.

### Wie das Paket arbeitet

**systemd Units und das Skript 'test-btrfs-default'**

Die systemd Units aktivieren das Skript nach jedem Systemstart und immer dann, wenn ein Snapshot von **`/`** erstellt wurde.  
Das Skript prüft darauf hin ob sich das Btrfs Standard-, das gebootete Subvolumen und der Standard-Menüeintrag unterscheiden. Ist das zum Beispiel nach einem Rollback der Fall, wird das Bootmenü angepasst. Der Standard-Menüeintrag bootet nun das neue Standard Subvolumen.  
Generiert snapper auf Grund einer apt-Aktion neue Snapshot, wertet das Skript *test-btrfs-default* die apt-Aktion aus und verbessert die von snapper verwendete Beschreibung.

**Bei Verwendung des Bootmanagers GRUB**
  
+  **Funktion von '09_siduction-btrfs'**  
  Die Nummerierung (09\_) bewirkt, dass Grub die Datei vor *10_linux* ausführt. Das ist notwendig um doppelte Einträge im Grub Menü zu verhindern.  
  Ist das Dateisystem Btrfs, werden der Datei *10_linux* die Ausführrechte entzogen und *09_siduction-btrfs* erstellt die Standard Menüeinträge des Grub Menüs.  
  Ist das Dateisystem **nicht** Btrfs, entzieht sich die Datei selbst die Ausführrechte und beendet sich ohne die Grub Menüdatei zu bearbeiten. Fortan ignoriert Grub sie bei einem Update des Menüs.
  
+  **Änderungen gegenüber '10_linux'**  
  Der default Eintrag im Grubmenü enthält das Bootziel in Form von *subvolume @* oder *snapshot #*. Somit erkennt der Benutzer sofort das Bootziel und kann bei Bedarf im Untermenü "siduction snapshots" ein anderes auswählen.  
  Die Grub Funktion `make_system_path_relative_to_its_root /` (10_linux ab Zeile 84) generiert immer die Kerneloption *rootflags=subvol=@*. Das ist nur richtig solange Btrfs kein default Subvolumen kennt, oder kein Rollback vollzogen wurde. Der Fehler ist bei Debian basierten OS bekannt.  
  Grub verwendet für die Pfade zum Kernel und der initrd nicht das Btrfs default Subvolumen, sondern das Subvolumen, in das gebootet wurde. Nach einem Rollback unterscheiden sie sich.  
  Die Datei *09_siduction-btrfs* ermittelt das Btrfs default Subvolumen und generiert mit diesen Werten im Grub Menü den Standard Booteintrag. Alle anderen Subvolumen stellt *grub-btrfs* im Untermenü "siduction snapshots" bereit. Ein einfacher Reboot führt so zum Rollback-Ziel.

Sollte der Benutzer sich dazu entscheiden das Btrfs default Subvolumen auf "@" zurück zu setzen, was er nur mit entsprechenden Vorbereitungen und der notwendigen Sachkenntnis tun sollte, wird auch hierfür der richtige default Eintrag im Grub Menü erstellt. Bisher war das Editieren der Kernel und initrd Bootzeile notwendig.

**Bei Verwendung des Bootmanagers systemd-boot**  
  
+  **Partitionierung**  
  systemd-boot steht ausschließlich für UEFI Systeme mit GPT Datenträgern zur Verfügung und benötigt zwingend eine ESP (Efi System Partition). Das Skript *test-btrfs-default* berücksichtigt die verschiedenen Möglichkeiten der Partitionierung bei der Bearbeitung der Booteinträge.
  
+  **snapper Aktionen**  
  Werden r/w Snapshots erstellt, zum Beispiel mittels Rollback, generiert das Skript entsprechende Booteinträge. Dabei berücksichtigt es alle in dem neuen Snapshot enthaltene Kernel.  
  Nachdem r/w Snapshots gelöscht wurden, entfernt das Skript die korrespondierenden Booteinträge.  
