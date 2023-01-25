# grub-btrfs-rollback_settings
Btrfs file system - improved handling of rollback by Grub.  
Grub menu is incorrect after a rollback.  

## Cause (EN)

+ The default boot entry always points to the "/@" subvolume using "rootflags=".  
+ For kernel and initrd, the snapshot that was booted into is always used and not the one that is Btrfs-default after the rollback.  
+ The boot target is not clear from the title.

## Workaround

The file "09_siduction-btrfs" provided here.

## Support / Cooperation

The file was created and tested on an x86_64 system.  
We need testers for other hardware platforms.

**Be sure to read the Info.txt file before testing.**

## Known problems and bugs

Currently unknown, but likely, are incorrect paths when used on platforms other than x86_64 and x686.

## Ursache (DE)

+ Der Standard Booteintrag zeigt mittels "rootflags=" immer auf das "/@" Subvolumen.  
+ Für Kernel und initrd wird immer der Snapshot verwendet, in den gebootet wurde und nicht der, der nach dem Rollback Btrfs-default ist.  
+ Aus dem Titel geht das Bootziel nicht hervor.

## Abhilfe

Die hier bereitgestellte Datei "09_siduction-btrfs"

## Unterstützung / Mitarbeit

Die Datei wurde auf einem x86_64 System erstellt und getestet.  
Wir benötigen Tester für andere Hardware Plattformen.

**Vor dem Test bitte unbedingt die Datei Info.txt lesen.**

## Bekannte Probleme und Fehler

Derzeit nicht bekannt, aber wahrscheinlich, sind fehlerhafte Pfade bei Verwendung auf anderen Plattformen als x86_64 und x686.
