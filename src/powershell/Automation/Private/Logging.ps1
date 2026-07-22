#
# Private/Logging.ps1 - Centralized logging setup.
# Standard logging pattern implementation.
#

function Get-CallingCommandName {
    <#
    .SYNOPSIS
        Derive the owning command name from the call stack.

    .DESCRIPTION
        Walks the PowerShell call stack and returns the first (innermost) frame
        outside the logging infrastructure whose function name matches the
        Verb-Noun command pattern (e.g. Test-ServerConnectivity). This lets any
        command that logs via Get-Logger (which auto-calls Initialize-Logging)
        write to its own logs/commands/<Command>/ folder without having to pass
        -CommandName explicitly.

        Frames from the logging plumbing (Initialize-Logging, Get-Logger) and
        anonymous script blocks are skipped. If no command frame is found
        (e.g. logging triggered from a Pester It block) $null is returned so the
        caller can fall back to the shared testing/production behaviour.
    #>
    [CmdletBinding()]
    param()
    $infra = @('Initialize-Logging', 'Get-Logger', 'Get-CallingCommandName')
    # Only attribute logging to functions defined inside the Automation module
    # (Public/Private). This excludes Pester's Invoke-ScriptBlock wrapper, test
    # files, and cmdlets (which have no module script path), so the derived
    # CommandName is always a real command rather than test/infra plumbing.
    # $PSScriptRoot is the directory of this file (.../Automation/Private), so
    # its parent is the Automation module root.
    $automationRoot = (Split-Path $PSScriptRoot -Parent) -replace '\\', '/'
    $stack = Get-PSCallStack
    foreach ($frame in $stack) {
        $fn = $frame.FunctionName
        if (-not $fn) { continue }
        if ($infra -contains $fn) { continue }
        if ($fn -match '^(<ScriptBlock>|<No file>|\{.*\})$') { continue }
        if ($fn -match '^[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*$') {
            $sn = $frame.ScriptName -replace '\\', '/'
            if ($sn -and $sn.StartsWith($automationRoot)) {
                return $fn
            }
        }
    }
    return $null
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize centralized logging system.

    .DESCRIPTION
        Configures logging with specified log file path and level.
        By default creates timestamped log files in generated/logs/testing or
        generated/logs/production. When -CommandName is supplied the log is
        written to a dedicated per-command folder so every command's run history
        stays isolated (critical logs are never pruned early or lost in a shared,
        mixed folder):

            generated/logs/commands/<CommandName>/<LogName|CommandName>_<isotimestamp>_<level>.log

        -CommandName is optional: when omitted on the Get-Logger auto-init path
        (no -LogFile either), it is auto-derived from the PowerShell call stack
        as the innermost Verb-Noun command frame, so any command that logs
        through Get-Logger gets an isolated log automatically.

        All filenames carry an ISO-8601 UTC timestamp
        (e.g. 2026-07-22T15-03-27Z), never a unix epoch.

    .PARAMETER LogFile
        Base name for the log file (without timestamp). Defaults to
        '<CommandName>.log' when -CommandName is supplied without -LogFile.

    .PARAMETER CommandName
        Name of the command owning this log. When set, the log is stored under
        generated/logs/commands/<CommandName>/.

    .PARAMETER LogName
        Optional explicit base name for the log file (e.g. include significant
        parameters such as the target host). Used verbatim for the filename stem.

    .PARAMETER Level
        Minimum log level: Verbose, Debug, Information, Warning, or Error (default: Information)

    .EXAMPLE
        Initialize-Logging -LogFile 'automation.log' -Level 'Debug'
        Initialize-Logging -CommandName 'Test-ServerConnectivity' -LogName 'Test-ServerConnectivity-ManagementHost-va-ov-01'
    #>
    [CmdletBinding()]
    param(
        [string] $LogFile = $null,
        [string] $CommandName = $null,
        [string] $LogName = $null,
        [ValidateSet('Verbose','Debug','Information','Warning','Error')]
        [string] $Level   = 'Information'
    )
    # Auto-derive the owning command from the call stack so any command that
    # logs via Get-Logger automatically gets an isolated per-command log folder
    # without editing every command file. Only applies to the Get-Logger
    # auto-init path (no explicit -CommandName and no explicit -LogFile) so an
    # explicit call's behaviour is never changed.
    if (-not $CommandName -and -not $LogFile) {
        $derived = Get-CallingCommandName
        if ($derived) { $CommandName = $derived }
    }
    if ($CommandName -and -not $LogFile) { $LogFile = "$CommandName.log" }
    $script:_LogFile    = $LogFile
    $script:_LogLevel   = $Level
    $script:_Configured = $true

    if ($LogFile) {
        $projectRoot = Get-ProjectRoot
        if (-not $projectRoot) { $projectRoot = Get-Location }

        if ($CommandName) {
            $dir = Join-Path $projectRoot "generated/logs/commands/$CommandName"
            $baseName = if ($LogName) { $LogName } else { [System.IO.Path]::GetFileNameWithoutExtension($LogFile) }
        } else {
            $isTesting = (Get-PSCallStack | Where-Object { $_.ScriptName -match '\.Tests?\.ps1$' }) -ne $null
            if ($isTesting) {
                $dir = Join-Path $projectRoot 'generated/logs/testing'
            } else {
                $dir = Join-Path $projectRoot 'generated/logs/production'
            }
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
        }
        if (-not (Test-Path $dir -PathType Container)) { Ensure-DirectoryExists -Path $dir }

        $ext = [System.IO.Path]::GetExtension($LogFile)
        $timestamp = Get-UtcFileTimestamp
        $levelStr = $Level.ToUpper()

        if ($levelStr -eq 'INFORMATION') { $levelStr = 'INFO' }
        if ($levelStr -eq 'VERBOSE') { $levelStr = 'DEBUG' }

        $realLogFile = "${baseName}_${timestamp}_${levelStr}${ext}"
        $global:__AutomationLogPath = Join-Path $dir $realLogFile
    }
    $global:__AutomationLogLevel = $Level
}

function Get-Logger {
    <#
    .SYNOPSIS
        Gets logger.
    #>

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
        # Use Write-Host (information stream) rather than Write-Output so log
        # lines are never collected into a command's return value / pipeline.
        Write-Host $line
        if ($global:__AutomationLogPath) { $line | Add-Content $global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Warning' -Value {
        param([string]$msg)
        $ts  = Get-LogTimestamp
        $line = "$ts - $($this.Name) - WARNING - $msg"
        # -WarningAction Continue keeps log writes non-terminating regardless of
        # the caller's $WarningPreference (e.g. when a command runs under -Stop).
        Write-Warning -Message $line -WarningAction Continue
        if ($global:__AutomationLogPath) { $line | Add-Content $global:__AutomationLogPath }
    }
    Add-Member -InputObject $logger -MemberType ScriptMethod -Name 'Error' -Value {
        param([string]$msg)
        $ts  = Get-LogTimestamp
        $line = "$ts - $($this.Name) - ERROR - $msg"
        # -ErrorAction Continue keeps log writes non-terminating regardless of
        # the caller's $ErrorActionPreference (e.g. when a command runs under -Stop).
        Write-Error -Message $line -ErrorAction Continue
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
