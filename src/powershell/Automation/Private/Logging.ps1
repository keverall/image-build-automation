#
# Private/Logging.ps1 — Centralized logging setup.
# Standard logging pattern implementation.
#

$script:_LogFile    = $null
$script:_LogLevel   = 'Information'
$script:_Configured = $false

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [string] $LogFile = $null,
        [ValidateSet('Verbose','Debug','Information','Warning','Error')]
        [string] $Level   = 'Information'
    )
    $script:_LogFile    = $LogFile
    $script:_LogLevel   = $Level
    $script:_Configured = $true

    if ($LogFile) {
        $dir = Join-Path ([System.IO.Path]::GetFullPath('.')) 'generated/logs/production'
        if (-not (Test-Path $dir -PathType Container)) { Ensure-DirectoryExists -Path $dir }
        $script:__AutomationLogPath = Join-Path $dir $LogFile
    }
    $script:__AutomationLogLevel = $Level
}

function Get-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Name
    )
    if (-not $script:_Configured) { Initialize-Logging }
    $logger = [PSCustomObject]@{ Name = $Name }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Info' -Value {
        param([string]$msg)
        $ts  = Get-LogTimestamp
        $line = "$ts - $($this.Name) - INFO - $msg"
        Write-Host $line
        if ($global:__AutomationLogPath) { $line | Add-Content $global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Warning' -Value {
        param([string]$msg)
        $ts  = Get-LogTimestamp
        $line = "$ts - $($this.Name) - WARNING - $msg"
        Write-Warning $line
        if ($global:__AutomationLogPath) { $line | Add-Content $global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Error' -Value {
        param([string]$msg)
        $ts  = Get-LogTimestamp
        $line = "$ts - $($this.Name) - ERROR - $msg"
        Write-Error $line
        if ($global:__AutomationLogPath) { $line | Add-Content $global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Debug' -Value {
        param([string]$msg)
        if ($global:__AutomationLogLevel -in @('Debug','Verbose')) {
            $ts  = Get-LogTimestamp
            $line = "$ts - $($this.Name) - DEBUG - $msg"
            Write-Verbose $line
            if ($global:__AutomationLogPath) { $line | Add-Content $global:__AutomationLogPath }
        }
    }
    return $logger
}
