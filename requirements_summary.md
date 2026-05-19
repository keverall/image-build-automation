# Requirements 

What we are planning to achieve: 

regarding Physical server automation build, 
below Marin's view of what we should be doing regarding automating physical build. 
Bear in mind that I planned this path with tools that we have already available, 
or we are in process of getting (Like Microsoft MCM and HPE CoM).

## 2 simple steps :

1. Hardware Prep (OneView)

- Server Profile Templates (SPT): Create a template in OneView that defines your BIOS settings, RAID levels, and boot order.
- Automation: When a new server is added, OneView applies this profile automatically, ensuring the hardware is ready for the OS. 

2. OS Delivery (MECM + iLO)

-  Create Boot Media: In MECM, generate a Bootable ISO (or Prestaged Media ISO). Store this on a web server or network share accessible to your iLOs.
-  Virtual Media Mounting: Use a script (PowerShell or Python) to call the OneView/iLO API and mount that MECM ISO as a virtual drive.
-  Boot & Install: Set the server to "Boot Once" from Virtual Media. The server boots into the MECM Task Sequence, partitions the local disks, and installs the OS. 
 
## Summary of Component Roles

|Tool|Primary Role in this Path|
|--|---|
|OneView  |Automates BIOS, RAID, and Network fabric setup via Server Profiles.|
|Compute Ops Mgmt  |Centralized monitoring and firmware baseline management for OneView sites.|
|MECM (SCCM)  |Provides the Task Sequence and OS image via an ISO instead of PXE.|
|iLO Virtual Media  |Acts as the "virtual thumb drive" that bridges OneView and MECM.|

## Simple Automation Logic

1.  Trigger: New server detected or Profile assigned in OneView.
2.  Script: OneView PowerShell module calls Set-HPOVServerProfile to apply the hardware config.
3.  Mount: The script uses iLO Redfish or OneView APIs to mount the MECM ISO.
4.  Reboot: Server boots from the virtual ISO and runs the MECM Task Sequence automatically.

Regarding number one, that part is basically covered, as I have profiles on some server. 
Will need to expand those on all servers that are already build, for firmware updates and drivers mostly. 

For the new install Marin will create new server profile and do all of the settings, including BIOS, RAID and other low-level config.

### Kev's focus in this would be second part, OS delivery. 

Think about options there. 

### Marin's view:

- is that I would maybe go with build image with MECM 
- and deliver image to the server using PowerShell or something similar.
- Maybe ansible if needed, with of course using HPE iLo API.

Please take a look at this and let me know what do you think about this approach ? And please suggest any other option, 
if you think it would be better suited. Just please try to stay in the limits what we have / will have on disposal, 
as I don’t want to spend another bunch of time on somethgin that will be too expensive and will be scraped, 
even before POC 😉 If you get me..
