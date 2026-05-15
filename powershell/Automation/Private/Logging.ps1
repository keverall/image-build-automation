#
# Private/Logging.ps1 — Centralized logging setup.
# Mirrors Python logging_setup.py (init_logging / get_logger).
#

$script:_LogFile    = $null
$script:_LogLevel   = 'Information'
$script:_Configured = $false

function Initialize-Logging {
    <#
    .SYNOPSIS
        Configure logging with console and optional file output.

    .PARAMETER LogFile
        Optional log filename written under the 'logs/' directory.

    .PARAMETER Level
        Verbose | Debug | Information | Warning | Error  (default: Information).

    .EXAMPLE
        Initialize-Logging -LogFile 'build.log'
    #>
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
        $dir = Join-Path ([System.IO.Path]::GetFullPath('.')) 'logs'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
        $Global:__AutomationLogPath = Join-Path $dir $LogFile
    }
    $Global:__AutomationLogLevel = $Level
}

function Get-Logger {
    <#
    .SYNOPSIS
        Returns a lightweight named logger object with Info / Warning / Error methods.

    .EXAMPLE
        $log = Get-Logger 'MyModule'
        $log.Info('Started')
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string] $Name)
    if (-not $script:_Configured) { Initialize-Logging }
    $logger = [PSCustomObject]@{ Name = $Name }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Info' -Value {
        param([string]$msg)
        $ts  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = "$ts - $($this.Name) - INFO - $msg"
        Write-Host $line
        if ($Global:__AutomationLogPath) { $line | Add-Content $Global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Warning' -Value {
        param([string]$msg)
        $ts  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = "$ts - $($this.Name) - WARNING - $msg"
        Write-Warning $line
        if ($Global:__AutomationLogPath) { $line | Add-Content $Global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Error' -Value {
        param([string]$msg)
        $ts  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = "$ts - $($this.Name) - ERROR - $msg"
        Write-Error $line
        if ($Global:__AutomationLogPath) { $line | Add-Content $Global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Debug' -Value {
        param([string]$msg)
        if ($Global:__AutomationLogLevel -in @('Debug','Verbose')) {
            $ts  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $line = "$ts - $($this.Name) - DEBUG - $msg"
            Write-Verbose $line
            if ($Global:__AutomationLogPath) { $line | Add-Content $Global:__AutomationLogPath }
        }
    }
    return $logger
}
