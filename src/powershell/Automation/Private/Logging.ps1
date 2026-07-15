#
# Private/Logging.ps1 - Centralized logging setup.
# Standard logging pattern implementation.
#

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize centralized logging system.

    .DESCRIPTION
        Configures logging with specified log file path and level.
        Creates timestamped log files in generated/logs/testing or generated/logs/production directories.

    .PARAMETER LogFile
        Base name for the log file (without timestamp)

    .PARAMETER Level
        Minimum log level: Verbose, Debug, Information, Warning, or Error (default: Information)

    .EXAMPLE
        Initialize-Logging -LogFile 'automation.log' -Level 'Debug'
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
        $projectRoot = Get-ProjectRoot
        if (-not $projectRoot) { $projectRoot = Get-Location }
        $isTesting = (Get-PSCallStack | Where-Object { $_.ScriptName -match '\.Tests?\.ps1$' }) -ne $null
        if ($isTesting) {
            $dir = Join-Path $projectRoot 'generated/logs/testing'
        } else {
            $dir = Join-Path $projectRoot 'generated/logs/production'
        }
        if (-not (Test-Path $dir -PathType Container)) { Ensure-DirectoryExists -Path $dir }
        
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
        $ext = [System.IO.Path]::GetExtension($LogFile)
        $timestamp = Get-UtcFileTimestamp
        $levelStr = $Level.ToUpper()
        
        if ($levelStr -eq 'INFORMATION') { $levelStr = 'INFO' }
        if ($levelStr -eq 'VERBOSE') { $levelStr = 'DEBUG' }
        
        $realLogFile = "${baseName}_${timestamp}_${levelStr}${ext}"
        $script:__AutomationLogPath = Join-Path $dir $realLogFile
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
        Write-Output $line
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
