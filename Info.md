# EN

## preface

The package **siduction-btrfs** improves the grub menu file "/boot/grub/**grub.cfg**" for siduction installed in Btrfs file system.

It does not replace the basic understanding of the function of Btrfs file system, its subvolume and snapshots.

For this reason, an important note right at the beginning:  
After a rollback followed by a reboot into the new Btrfs default subvolume, a `grub-install` is required. Otherwise, the reference to the previous default subvolume in Grub stage-1 remains and Grub loads the menu file from there.

### Involved components

+ Btrfs with subvolumes (With Btrfs, snapshots are also subvolumes, just with default contents).  
+ Grub with its configuration files  
+ Snapper as frontend for Btrfs  
+ Manual Btrfs commands  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), which is very helpful. Its functionality remains unchanged.  
+ The package *subduction-btrfs* with systemd units and scripts.

### How the package works

**Basic function of '90_siduction-btrfs'**

The numbering (09\_) causes Grub to execute the file before *10_linux*. This is necessary to prevent duplicate entries in the Grub menu.  
If the file system is Btrfs, the file *10_linux* is stripped of the execution rights and *09_siduction-btrfs* creates the Grub default menu items.  
If the file system is **not** Btrfs, the file revokes its own execution rights and exits without editing the Grub menu file. Henceforth, Grub ignores it when updating the menu.

**Changes from '10_linux'**

The default entry in the grub menu contains the boot target in the form of *subvolume @* or *snapshot #*. Thus the user immediately recognizes the boot target and can select another one in the submenu "siduction snapshots" if necessary.

The Grub function `make_system_path_relative_to_its_root /` (10_linux from line 84) always generates the kernel option *rootflags=subvol=@*. This is only correct as long as Btrfs does not know a default subvolume, or no rollback has been done. This is a known bug in Debian based OS.  
Grub does not use the Btrfs default subvolume for the paths to the kernel and initrd, but the subvolume that was booted into. After a rollback, they differ.  
The file *09_siduction-btrfs* determines the Btrfs default subvolume and generates the default boot entry in the Grub menu with these values. All other subvolumes are provided by *grub-btrfs* in the submenu "siduction snapshots". A simple reboot thus leads to the rollback target.

If the user decides to reset the btrfs default subvolume to "@", which should only be done with proper preparation and knowledge, the correct default entry is created in the grub menu. Previously, editing the kernel and initrd boot lines was necessary.

**systemd units and the script 'test-btrfs-default'**

The systemd units activate the script after every system boot and whenever a snapshot of **`/`** is taken. The script checks if the Btrfs default subvolume, the booted subvolume and the default menu entry are different. If this is the case, the `update-grub` command is executed.

### Events affecting the Grub menu

+ Snapshot  
  *grub-btrfs* updates the submenu "siduction snapshots". It is automatically called from the grub menu file.  
  `update-grub` is executed only if the Btrfs default, the booted subvolume, and the Grub default menu item differ.  
+ Rollback  
  *grub-btrfs* updates the submenu "siduction snapshots".  
  `update-grub` is executed. Then the default Grub menu entry boots into the rollback target.  
+ Reboot into rollback target  
  `update-grub` is executed. The newly created grub menu file in the rollback target is different from the previously used menu. Grub stage-1 still points to the previous Btrfs default subvolume. If the state of the OS after the rollback is as desired, `grub-install` must be called manually. So Grub stage-1 points to the rollback target, which is now also the Btrfs default subvolume.  
+ *apt install/remove*  
  *snapper* triggers apt and creates a pre- and post-snapshot (default). Then *grub-btrfs* updates the "siduction snapshots" submenu.
+ *apt upgrade/install/remove* with kernel  
  For apt actions involving kernels, apt runs an `update-grub`, *snapper* takes a pre- and post-snapshot, and *grub-btrfs* updates the "siduction snapshots" submenu.

---------

# DE

## Vorwort

Das Paket **siduction-btrfs** verbessert bei einem auf Btrfs installierten siduction die Grub Men??datei "/boot/grub/**grub.cfg**".

Es ersetzt nicht das grundlegende Verst??ndnis der Funktion des Btrfs Dateisystems, seiner Subvolumen und Snapshots.

Aus diesem Grund gleich zu Beginn ein wichtiger Hinweis:  
Nach einem Rollback mit anschlie??endem Reboot in das neue Btrfs default Subvolumen ist ein `grub-install` notwendig. Sonst bleibt in Grub stage-1 der Verweis auf das vorherige default Subvolumen erhalten und Grub l??dt von dort die Men??datei.

### Beteiligten Komponenten

+ Btrfs mit Subvolumen (F??r Btrfs sind Snapshots auch Subvolumen, nur mit einem vorgegebenen Inhalt.)  
+ Grub mit seinen Konfigurationsdateien  
+ snapper als Frontend f??r Btrfs  
+ Manuelle Btrfs Kommandos  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), das sehr hilfreich ist. Seine Funktionalit??t bleibt unver??ndert erhalten.  
+ Das Paket *siduction-btrfs* mit systemd Units und Skripten.

### Wie das Paket arbeitet

**Basis Funktion von '09_siduction-btrfs'**

Die Nummerierung (09\_) bewirkt, dass Grub die Datei vor *10_linux* ausf??hrt. Das ist notwendig um doppelte Eintr??ge im Grub Men?? zu verhindern.  
Ist das Dateisystem Btrfs, werden der Datei *10_linux* die Ausf??hrrechte entzogen und *09_siduction-btrfs* erstellt die Standard Men??eintr??ge des Grub Men??s.  
Ist das Dateisystem **nicht** Btrfs, entzieht sich die Datei selbst die Ausf??hrrechte und beendet sich ohne die Grub Men??datei zu bearbeiten. Fortan ignoriert Grub sie bei einem Update des Men??s.

**??nderungen gegen??ber '10_linux'**

Der default Eintrag im Grubmen?? enth??lt das Bootziel in Form von *subvolume @* oder *snapshot #*. Somit erkennt der Benutzer sofort das Bootziel und kann bei Bedarf im Untermen?? "siduction snapshots" ein anderes ausw??hlen.  
Die Grub Funktion `make_system_path_relative_to_its_root /` (10_linux ab Zeile 84) generiert immer die Kerneloption *rootflags=subvol=@*. Das ist nur richtig solange Btrfs kein default Subvolumen kennt, oder kein Rollback vollzogen wurde. Der Fehler ist bei Debian basierten OS bekannt.  
Grub verwendet f??r die Pfade zum Kernel und der initrd nicht das Btrfs default Subvolumen, sondern das Subvolumen, in das gebootet wurde. Nach einem Rollback unterscheiden sie sich.  
Die Datei *09_siduction-btrfs* ermittelt das Btrfs default Subvolumen und generiert mit diesen Werten im Grub Men?? den Standard Booteintrag. Alle anderen Subvolumen stellt *grub-btrfs* im Untermen?? "siduction snapshots" bereit. Ein einfacher Reboot f??hrt so zum Rollback-Ziel.

Sollte der Benutzer sich dazu entscheiden das Btrfs default Subvolumen auf "@" zur??ck zu setzen, was er nur mit entsprechenden Vorbereitungen und der notwendigen Sachkenntnis tun sollte, wird auch hierf??r der richtige default Eintrag im Grub Men?? erstellt. Bisher war das Editieren der Kernel und initrd Bootzeile notwendig.

**systemd Units und das Skript 'test-btrfs-default'**

Die systemd Units aktivieren das Skript nach jedem Systemstart und immer dann, wenn ein Snapshot von **`/`** erstellt wurde. Das Skript pr??ft darauf hin ob sich das Btrfs Standard-, das gebootete Subvolumen und der Standard-Men??eintrag unterscheiden. Ist das der Fall, wird das Kommando `update-grub` ausgef??hrt.  

### Ereignisse, die das Grub Men?? betreffen

+ Snapshot  
  *grub-btrfs* aktualisiert das Untermen?? "siduction snapshots" Es wird automatisch von der Grub Men??datei aufgerufen.  
  `update-grub` wird nur dann ausgef??hrt, wenn sich das Btrfs Standard-, das gebootete Subvolumen und der Standard-Men??eintrag unterscheiden.  
+ Rollback  
  *grub-btrfs* aktualisiert das Untermen?? "siduction snapshots"  
  `update-grub` wird ausgef??hrt. Dadurch bootet der Grub Standard-Men??eintrag in das Rollbackziel.
+ Neustart im das Rollback-Ziel  
  `update-grub` wird ausgef??hrt. Die neu erstellte Grub-Men??-Datei im Rollback-Ziel unterscheidet sich von dem zuvor verwendeten Men??. Grub stage-1 verweist immer noch auf das vorherige Btrfs-Standard-Subvolumen. Ist der Zustand des OS nach dem Rollback so wie gew??nscht, muss manuell `grub-install` aufgerufen werden. So verweist Grub stage-1 auf das Rollback-Ziel, das nun gleichzeitig das Btrfs default Subvolumen ist.  
+ *apt install/remove*  
  *snapper* triggert apt und erstellt einen pre- und post-Snapshot (Standardeinstellung). Anschlie??end aktualisiert *grub-btrfs* das Untermen?? "siduction snapshots".
+ *apt upgrade/install/remove* mit Kernel  
  Bei apt Aktionen, an denen Kernel beteiligt sind, f??hrt apt ein `update-grub` aus, *snapper* erstellt einen pre- und post-Snapshot und *grub-btrfs* aktualisiert das Untermen?? "siduction snapshots".
