# Maintenance mode code extracts and samples

## Table of Contents

- [SCOM Management Group Server names](#scom-management-group-server-names)
- [Powershell scripts as examples of Group and Cluster Support maintenance mode:](#powershell-scripts-as-examples-of-group-and-cluster-support-maintenance-mode)
  - [SCOM 2012](#scom-2012)
  - [SCOM 2016](#scom-2016)
  - [SCOM 2019](#scom-2019)
- [Questions that group needs to clarify on and still has not](#questions-that-group-needs-to-clarify-on-and-still-has-not)


``` PWSH
Import-Module OperationsManager
New-SCOMManagementGroupConnection -ComputerName alpasopm12ms1.ad.example.com
$servers = Get-SCOMGroup -DisplayName "Contoso Maintenance Mode Non 24-Hour Servers" | Get-SCOMClassInstance
$Time = ((Get-Date).AddMinutes(3660))

 

foreach ($server in $servers) {
    Start-SCOMMaintenanceMode -Instance $server -EndTime $Time -Comment "Weekend Maintenance Mode"

 

}
```

relevant documentation -
- [SCOM Maintenance Mode Overview](https://learn.microsoft.com/en-us/system-center/scom/manage-maintenance-mode-overview?view=sc-om-2016&tabs=Edit#create-maintenance-schedule-in-the-operations-console)

[SCOM Maintenance Mode REST API Schedule Maintenance](https://learn.microsoft.com/en-us/rest/api/operationsmanager/schedule-maintenance)

[SCOM REST API Operations manager](https://learn.microsoft.com/en-us/rest/api/operationsmanager/)


```PWSH
#==============================================================================================================================# 
#                                                                                                                              #
#                                                                                                                              # 
# SCOM2012_MM_0_2.ps1                                                                                                          # 
# Powershell Script to put a Host or Group into maintenance mode. Tested with SCOM 2012 and SCOM 2012 SP1                      #      #                                                 #
# Created by: Arjan Vroege                               #      #                                                                                                                              #
# Version: 0.2                                                                                                                 #
#                                                                                                                              # 
# Usage: .\SCOM2012_MM_0_2.ps1 -Minutes <<Duration>> -Comment "<<Comment>>" -Type <<Group or Agent>> -Name  << Name >>     #
#                                                                                                                              #
# -Minutes:   Number of Minutes                                                                                              #
# -Comment:   Maintenance Mode comment                                                                                       #
# -Type:     Agent or SCOM Group                                                                                    #
# -Name:     Name of the Group or Display Name of Agent                                                             #
#                                                                                                                              #
#                                                                                                                              #
#==============================================================================================================================#

 

Param(
  [int32]$minutes,
  [string]$comment,
  [string]$type,
  [string]$name
)

 

#Import the Operations Manager Powershell Module
Import-Module OperationsManager

 

#Defining Variables
$MgntSrv   = "alpasopm12ms2.ad.example.com"
$startTime = (Get-Date).ToUniversalTime() 
$endTime   = $startTime.AddMinutes($Minutes)
$reason    = "PlannedOther";

 

if($type -eq "Group") {
    #Getting Group Objects
    $group = Get-SCOMGroup -ComputerName $MgntSrv -DisplayName $name

  #Check if Group is already in Maintenance Mode
    If($group.InMaintenanceMode -eq $false) {
        Write-Output "Putting Group $Name into maintenance mode." -ForeGroundColor Blue 
    $group.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive")
    }
} elseif($type -eq "Agent") {
    #Gets the SCOM Agent
    $SCOMAgent = Get-SCOMAgent -ComputerName $MgntSrv -Name $name
    $Instance  = $scomagent.HostComputer

    if(($clusters = $SCOMagent.GetRemotelyManagedComputers())) { 
      $clusterNodeClass = Get-SCOMClass -ComputerName $MgntSrv -Name Microsoft.Windows.Cluster.Node 
      foreach($cluster in $clusters) {
         $ClusterAgentName = $cluster.ComputerName
         $SCOMClass        = Get-SCOMClass -ComputerName $MgntSrv -Name Microsoft.Windows.Cluster
         $ClusterInstance  = Get-SCOMClassinstance -ComputerName $MgntSrv -Class $SCOMClass | where {$_.Displayname -like “*$ClusterAgentName*”} 
         if($ClusterInstance) {     
          $ClusterInstance.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive") 
          $nodes = $ClusterInstance.GetRelatedMonitoringObjects($clusterNodeClass) 
          if($nodes) { 
            foreach($node in $nodes) { 
              Write-Output "Putting $node into maintenance mode." -ForeGroundColor Green 
            } 
           } 
         }
        Write-Output "Putting $($cluster.Computer) into maintenance mode." -ForeGroundColor Blue 
        $ClusterComputer = $cluster.Computer
        $ClusterComputer.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive") 
      } 
    } else { 
      #Setting maintenance mode for computer object and/or cluster components 
      Write-Output "Putting $Instance into maintenance mode." -ForeGroundColor Blue 
      $Instance.ScheduleMaintenanceMode($startTime,$endTime,$reason,$Comment,"Recursive")
    }
} else {
    Write-Output "Exiting" -ForeGroundColor Red 
}
```

<a name="scom-management-group-server-names"></a>
## SCOM Management Group Server names

- [SCOM Rest API quick start:](https://www.cookdown.com/blog/quick-start-scom-rest-api)

- [Microsoft Rest API documentation (the Schedule Maintenance section will be relevant): ](https://learn.microsoft.com/en-us/rest/api/operationsmanager/)

- [SCOM Maintenance Mode with Powershell: ](https://kevinjustin.com/blog/tag/maintenance-mode/)

<a name="powershell-scripts-as-examples-of-group-and-cluster-support-maintenance-mode"></a>
## Powershell scripts as examples of Group and Cluster Support maintenance mode:

<a name="scom-2012"></a>
### SCOM 2012

#### PRODUCTION

Management Group Name:  ***REMOVED***
Management Servers:  ***REMOVED***, ***REMOVED***, ***REMOVED*** and ***REMOVED***
Operational Database Server:  ***REMOVED***
Datawarehouse Server:  ***REMOVED***

<a name="scom-2016"></a>
### SCOM 2016

#### TEST

Management Group Name:  ***REMOVED***
Management Servers:  ***REMOVED*** and ***REMOVED***
Operational Database Server:  ***REMOVED***
Datawarehouse Server:  ***REMOVED***

#### PRODUCTION

Management Group Name:  ***REMOVED***
Management Servers:  ***REMOVED***, ***REMOVED***, ***REMOVED***, ***REMOVED***, ***REMOVED*** and ***REMOVED***
Operational Database Servers:  ***REMOVED*** and ***REMOVED*** (SQL AlwaysOn)
Datawarehouse Server:  ***REMOVED*** and ***REMOVED*** (SQL AlwaysOn)

<a name="scom-2019"></a>
### SCOM 2019

#### TEST

Management Group Name:  ***REMOVED***
Management Servers:  ***REMOVED*** and ***REMOVED***
Operational Database Server:  ***REMOVED***
Datawarehouse Server:  ***REMOVED***

#### PRODUCTION

Management Group Name:  ***REMOVED***
Management Servers:  ***REMOVED***, ***REMOVED***, ***REMOVED*** and ***REMOVED***
Operational Database Server:  ***REMOVED***
Datawarehouse Server:  ***REMOVED***

I need to verify the below so I build automation that is as its expected and not how I assume it should be, so can I get responses for my questions below, please? Alternatively, I could book a call if preferred?

<a name="questions-that-group-needs-to-clarify-on-and-still-has-not"></a>
## Questions that group needs to clarify on and still has not

1) Is this automation just to enable or disable maintenance mode using Start-SCOMAgentMaintenanceMode -Duration <Double (in minutes)> [-Reason <string>] [-Comments <string>] to enable/disable the cluster/servers,
2) Or is it to orchestrate the full SCOM maintenance schedule suite of functionality Schedule Maintenance - REST API (Operations Manager) | Microsoft Learn which is significantly larger task?
3) My understanding from last week’s call was the requirement is just enable and disable maintenance mode but after a discussion with Noel earlier and checking the MS Learn API doc for SCOM 2016/2019/2025 I see there is much more to this maintenance schedule/mode functionality.
Schedule Maintenance covers the following functionality - REST API (Operations Manager - Schedule Maintenance API Version:v1

- Create Schedule Maintenance
Adds the schedule maintenance for provided schedule request.

- Delete Schedule Maintenance
Deletes the schedule maintenance details for the specified schedule ID

- Disable Maintenance Schedule
Disables the schedule maintenance details for the specified schedule ID.

- Edit Schedule Maintenance
Updates the scheduled Maintenance for the provided schedule request.

- Enable Maintenance Schedule
Enables the schedule maintenance for the specified schedule ID.

- Extend Schedule Maintenance
Extends the scheduled maintenance for the provided schedule request.

- Get Schedule Maintenance
Retrieves the schedule maintenance details for the specified schedule ID.

- Get Schedule Maintenance List
Retrieves the schedule maintenance List.

- Stop Maintenance Schedule
Stops the scheduled maintenance details for specified schedule ID.

 

 

1.  Noel also asked that the automation handle 3 different SCOM versions, prior to this i thought initially just 2016 was being covered in this release? So 2012/2016/2019 and 2025 need to be covered with the earliest two being HTTP calls non REST and the latter two being REST API specific, I can check the SCOM server version , hopefully when the script PowerShell remotes in and either use rest or http as appropriate for that cluster/servers SCOM version, if required.
