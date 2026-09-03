# Path Parameter Formats

<a id="top"></a>

## Table of Contents

- [Overview](#overview)
- [Valid formats](#valid-formats)
  - [Single/double-slash UNC ( /vm-srvr-19/...)](#singledouble-slash-unc-vm-srvr-19)
  - [Windows UNC (backslashes)](#windows-unc-backslashes)
  - [CIFS/SMB URL](#cifssmb-url)
  - [HTTP/HTTPS](#httphttps)
  - [NFS](#nfs)
  - [Autocorrection](#autocorrection)
- [Invalid formats](#invalid-formats)

<a id="overview"></a>

## Overview

All three Path parameters (-ExternalIsoPath, -IsoPath internally, -FirmwareFolders) 

are resolved by the same Resolve-ExternalIsoPath helper in src/powershell/Automation/Private/ExternalIso.ps1:94, 
so they accept identical formats. Based on your command's paths:

<a id="valid-formats"></a>

## Valid formats

<a id="singledouble-slash-unc-vm-srvr-19"></a>

### Single/double-slash UNC ( /vm-srvr-19/...)

/vm-ewismgt-19/Kev/WIN2019Auto.iso ✅ (single slash, now auto-corrected)
//vm-ewismgt-19/Kev/WIN2019Auto.iso ✅ → cifs://vm-ewismgt-19/Kev/WIN2019Auto.iso

<a id="windows-unc-backslashes"></a>

### Windows UNC (backslashes)

\\vm-ewismgt-19\Kev\WIN2019Auto.iso → cifs://vm-ewismgt-19/Kev/WIN2019Auto.iso
Mapped drive (your Y:\... folders)
Y:\Drivers for Windows ISO\FC-14.4.624.0-1 ✅ (Y: must map to a UNC)
Y:\Drivers for Windows ISO\MR216i-a Win19Drivers ✅

→ cifs://<UNC-root-of-Y>/...

<a id="cifssmb-url"></a>

### CIFS/SMB URL

cifs://vm-ewismgt-19/Kev/WIN2019Auto.iso
smb://vm-ewismgt-19/Kev/WIN2019Auto.iso (normalised to cifs://)

<a id="httphttps"></a>

### HTTP/HTTPS

https://artifacts.internal/isos/WIN2019Auto.iso

<a id="nfs"></a>

### NFS

nfs://nfs-host/export/WIN2019Auto.iso

<a id="autocorrection"></a>

### Autocorrection

missing double "//" is a common mistake and "/" is autocorrected to "//"

-ExternalIsoPath '/vm-ewismgt-19/Kev/WIN2019Auto.iso' resolves to a  
cifs:// URL,  
and both Y:\... firmware folders resolve via their mapped-drive UNC.

<a id="invalid-formats"></a>

## Invalid formats

Invalid (iLO can't reach local disks): 

1. C:\isos\WIN2019Auto.iso  
2. /home/user/WIN2019Auto.iso (single-segment local path)  
3. or a mapped drive that points to a local disk  
