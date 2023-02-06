# EN

## preface

**09_siduction-btrfs** improves the grub menu file "/boot/grub/**grub.cfg**" for siduction installed in Btrfs filesystem.

It does not replace the basic understanding of the function of Btrfs filesystem, its subvolumes and snapshots.

For this reason, an important note right at the beginning:  
After a rollback followed by a reboot into the new Btrfs default subvolume, a *grub-install* is required. Otherwise, the reference to the previous default subvolume in Grub stage-1 remains and Grub loads the menu file from there.

### Involved components

+ Btrfs with subvolumes (With Btrfs, snaphots are also subvolumes, just with default contents).  
+ Grub with its configuration files  
+ Snapper as frontend for Btrfs  
+ Manual Btrfs commands  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), which is very helpful. Its functionality remains unchanged.  
+ Own systemd units and scripts.

### How the file works

**Filename**

The numbering (09\_) causes Grub to execute the file before *10_linux*. This is necessary to prevent duplicate entries in the Grub menu.

**Basic function**

If the file system is **not** Btrfs, the file revokes its own execution rights and exits without editing the Grub menu file. Henceforth, Grub ignores it when updating the menu.  
If the file system is Btrfs, the file *10_linux* is stripped of the execution rights and *09_siduction-btrfs* creates the default menu items of the Grub menu.

**Changes from `10_linux'**

The Grub function `make_system_path_relative_to_its_root /` (10_linux from line 84) always generates the kernel option *rootflags=subvol=@*. This is only correct as long as Btrfs does not know a default subvolume, or no rollback has been done. This is a known bug in Debian based OS. The solution is to disable this kernel option. Btrfs uses the default subvolume by itself.

Grub does not use the Btrfs default subvolume for the paths to the kernel and initrd, but the subvolume that was booted into. After a rollback, they differ. The file *09_siduction-btrfs* changes the paths and generates the default boot entry in the Grub menu fully compatible with the new Btrfs default subvolume. All other subvolumes are provided by *grub-btrfs* in the submenu "siduction snapshots". A simple reboot thus leads to the rollback target.  
If the user decides to reset the btrfs default subvolume to "@", which should only be done with proper preparation and knowledge, the correct default entry is created in the grub menu. Previously, editing the kernel and initrd boot lines was necessary.

The default entry in the grub menu contains the boot target in the form of *subvolume @* or *snapshot #*. Thus the user immediately recognizes the boot target and can select another one in the submenu "siduction snapshots" if necessary.

### Events affecting the Grub menu

+ snapshot  
  *grub-btrfs* updates the submenu "siduction snapshots". It is automatically called from the grub menu file.  
  `update-grub` is executed when the Btrfs default, the booted subvolume, and the Grub default menu item differ.  
+ rollback  
  *grub-btrfs* updates the submenu "siduction snapshots".  
  `update-grub` is executed. Then the default Grub menu entry boots into the rollback target.  
+ `grub-install` in the rollback target  
  The Grub menu file in the rollback target is different from the menu just used. Grub stage-1 still points to the previous Btrfs default subvolume. If the state of the OS after the rollback is as desired, `grub-install` must be called manually. So Grub stage-1 points to the rollback target, which is now also the Btrfs default subvolume.  
+ *apt install/remove*  
  *snapper* triggers apt and creates a pre- and post-snapshot (default). Then *grub-btrfs* updates the "siduction snapshots" submenu.
+ *apt upgrade/install/remove* with kernel  
  For apt actions involving kernels, apt runs an `update-grub`, *snapper* takes a pre- and post-snapshot, and *grub-btrfs* updates the "siduction snapshots" submenu.

## systemd and scripts

The archive *files-siduction-btrfs.tar.gz* contains a set of systemd units and the script *test-btrfs-default.sh*. The systemd units check after a shnapshot or rollback if the file *grub.cfg* has to be rebuilt and then activate the script.  
The script *install.sh* simplifies the installation for the user.

Download the archive, unpack it at an arbitrary place, change into the folder *files-siduction-btrfs/* and call **`install.sh`** with **root** privileges.

Afterwards the functions described above are available.

---------

# DE

## Vorwort

**09_siduction-btrfs** verbessert bei einem auf Btrfs installierten siduction die Grub Menüdatei "/boot/grub/**grub.cfg**".

Sie ersetzt nicht das grundlegende Verständniss der Funktion des Btrfs Dateisystems, seiner Subvolumen und Snapshots.

Aus diesem Grund gleich zu Beginn ein wichtiger Hinweis:  
Nach einem Rollback mit anschließendem Reboot in das neue Btrfs default Subvolumen ist ein *grub-install* notwendig. Sonst bleibt in Grub stage-1 der Verweis auf das vorherige default Subvolumen erhalten und Grub lädt von dort die Menüdatei.

### Beteiligten Konponenten

+ Btrfs mit Subvolumen (Für Btrfs sind Snaphots auch Subvolumen, nur mit einem vorgegebenen Inhalt.)  
+ Grub mit seinen Konfigurationsdateien  
+ snapper als Frontend für Btrfs  
+ Manuelle Btrfs Kommandos  
+ [grub-btrfs](https://github.com/Antynea/grub-btrfs), das sehr hilfreich ist. Seine Funktionalität bleibt unverändert erhalten.  
+ Eigene systemd Units und Scripte.

### Wie die Datei arbeitet

**Dateiname**

Die Nummerierung (09\_) bewirkt, dass Grub die Datei vor *10_linux* ausführt. Das ist notwendig um doppelte Einträge im Grub Menü zu verhindern.

**Basis Funktion**

Ist das Dateisysten **nicht** Btrfs, entzieht sich die Datei selbst die Ausführrechte und beendet sich ohne die Grub Menüdatei zu bearbeiten. Fortan ignoriert Grub sie bei einem Update des Menüs.  
Ist das Dateisystem Btrfs, werden der Datei *10_linux* die Ausführrecht entzogen und *09_siduction-btrfs* erstellt die Standard Menüeinträge des Grub Menüs.

**Änderungen gegenüber '10_linux'**

Die Grub Funktion `make_system_path_relative_to_its_root /` (10_linux ab Zeile 84) generiert immer die Kerneloption *rootflags=subvol=@*. Das ist nur richtig solange Btrfs kein default Subvolumen kennt, oder kein Rollback vollzogen wurde. Der Fehler ist bei Debian basierten OS bekannt. Die Lösung besteht darin diese Kerneloption zu unterbinden. Btrfs benutzt von sich aus das default Subvolumen.

Grub verwendet für die Pfade zum Kernel und der initrd nicht das Btrfs default Subvolumen, sondern das Subvolumen, in das gebootet wurde. Nach einem Rollback unterscheiden sie sich. Die Datei *09_siduction-btrfs* ändert die Pfade und generiert im Grub Menü den Standard Booteintrag vollständig kompatibel zum neuen Btrfs default Subvolumen. Alle anderen Subvolumen stellt *grub-btrfs* im Untermenü "siduction snapshots" bereit. Ein einfacher Reboot führt so zum Rollback-Ziel.  
Sollte der Benutzer sich dazu entscheiden das Btrfs default Subvolumen auf "@" zurück zu setzen, was er nur mit entsprechenden Vorbereitungen und der notwendigen Sachkenntnis tun sollte, wird auch hierfür der richtige default Eintrag im Grub Menü erstellt. Bisher war das Editieren der Kernel- und initrd-Bootzeile notwendig.

Der default Eintrag im Grubmenü enthält das Bootziel in Form von *subvolume @* oder *snapshot #*. Somit erkennt der Benutzer sofort das Bootziel und kann bei Bedarf im Untermenü "siduction snapshots" ein anderes auswählen.

### Ereignisse, die das Grub Menü betreffen

+ Snapshot  
  *grub-btrfs* aktualisiert das Untermenü "siduction snapshots" Es wird automatisch von der Grub Menüdatei aufgerufen.  
  `update-grub` wird ausgeführt, wenn sich das Btrfs Standard-, das gebootete Subvolumen und der Standard-Menüeintrag unterscheiden.  
+ Rollback  
  *grub-btrfs* aktualisiert das Untermenü "siduction snapshots"  
  `update-grub` wird ausgeführt. Dadurch bootet der Grub Standard-Menüeintrag in das Rollbackziel.
+ `grub-install` im Rollback-Ziel  
  Die Grub-Menü-Datei im Rollback-Ziel unterscheidet sich von dem gerade verwendeten Menü. Grub stage-1 verweist immer noch auf das vorherige Btrfs-Standard-Subvolume. Ist der Zustand des OS nach dem Rollback so wie gewünscht, muss manuell `grub-install` aufgerufen werden. So verweist Grub stage-1 auf das Rollback-Ziel, das nun gleichzeitig das Btrfs default Subvolumen ist.  
+ *apt install/remove*  
  *snapper* triggert apt und erstellt einen pre- und post-Snapshot (Standardeinstellung). Anschließend aktualisiert *grub-btrfs* das Untermenü "siduction snapshots".
+ *apt upgrade/install/remove* mit Kernel  
  Bei apt Aktionen, an denen Kernel beteiligt sind, führt apt ein `update-grub` aus, *snapper* erstellt einen pre- und post-Snapshot und *grub-btrfs* aktualisiert das Untermenü "siduction snapshots".

## systemd und Scripte

Das Archiv *files-siduction-btrfs.tar.gz* enthält einen Satz systemd Units und das Script *test-btrfs-default.sh*. Die systemd Units überprüfen nach einem Shnapshot oder Rollback ob die Datei *grub.cfg* neu erstellt werden muss und aktivieren dann das Script.  
Das Script *install.sh* vereinfacht für den Anwender die Installation.

Das Archiv herunterladen, an einem beliebigen Ort entpacken, in den Ordner *files-siduction-btrfs/* wechseln und mit **root**-Rechten **`install.sh`** aufrufen.

Anschließend sind die oben beschriebenen Funktionen verfügbar.
