#
# Automation.psm1 — Root module for HPE ProLiant Windows Server ISO Automation
#
# PowerShell class definitions MUST live here in the root module so they are
# resolved before any NestedModule (Private/*.psm1, Public/*.psm1) is parsed.
# PowerShell resolves [TypeName] annotations at *parse time*; if the type is in
# a NestedModule that hasn't been loaded yet the parse fails.
#

Set-StrictMode -Off   # allow $null comparisons, unset variables in classes

# ──────────────────────────────────────────────────────────────────────────────
# Shared value type: CommandResult  (mirrors Python executor.CommandResult)
# ──────────────────────────────────────────────────────────────────────────────
class CommandResult {
    [int]    $ReturnCode
    [string] $StandardOutput
    [string] $StandardError
    [bool]   $Success

    CommandResult([int]$rc, [string]$stdout, [string]$stderr) {
        $this.ReturnCode     = $rc
        $this.StandardOutput = $stdout
        $this.StandardError  = $stderr
        $this.Success        = ($rc -eq 0)
    }

    [string] Output() { return $this.StandardOutput + $this.StandardError }
}

# ──────────────────────────────────────────────────────────────────────────────
# Shared reference type: AuditLogger  (mirrors Python AuditLogger)
# ──────────────────────────────────────────────────────────────────────────────
class AuditLogger {
    [string]  $Category
    [string]  $LogDir
    [string]  $MasterLogPath
    [System.Collections.ArrayList] $Entries

    AuditLogger([string]$Category, [string]$LogDir, [string]$MasterLogName) {
        $this.Category      = $Category
        $this.LogDir        = $LogDir
        $this.MasterLogPath = [System.IO.Path]::Combine($LogDir, $MasterLogName)
        $this.Entries       = [System.Collections.ArrayList]::new()
        if (-not (Test-Path $this.LogDir)) {
            New-Item -ItemType Directory -Path $this.LogDir -Force | Out-Null
        }
    }

    [hashtable] Log([string]$Action, [string]$Status, [string]$Server,
                    [string]$Details, [hashtable]$Extra) {
        $entry = @{
            timestamp = (Get-Date -Format o)
            category  = $this.Category
            action    = $Action
            status    = $Status
            server    = $Server
            details   = $Details
        }
        if ($Extra) { foreach ($k in $Extra.Keys) { $entry[$k] = $Extra[$k] } }
        $null = $this.Entries.Add($entry)
        Write-Host "[$Status] $Action | $Server | $Details"
        return $entry
    }

    [string] Save([string]$Filename) {
        if (-not $Filename) {
            $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $Filename = "$($this.Category)_$ts.json"
        }
        $fp = [System.IO.Path]::Combine($this.LogDir, $Filename)
        @{ category = $this.Category; generatedAt = (Get-Date -Format o); entries = $this.Entries } |
            ConvertTo-Json -Depth 64 | Set-Content -Path $fp -Encoding UTF8
        return $fp
    }

    [void] AppendToMaster() {
        foreach ($e in $this.Entries) {
            ($e | ConvertTo-Json -Depth 10 -Compress) | Add-Content -Path $this.MasterLogPath -Encoding UTF8
        }
    }

    [void] Clear() { $this.Entries.Clear() }
}

# ──────────────────────────────────────────────────────────────────────────────
# Shared value type: ServerInfo  (mirrors Python ServerInfo dataclass)
# ──────────────────────────────────────────────────────────────────────────────
class ServerInfo {
    [string] $Hostname
    [string] $IPMI_IP
    [string] $ILO_IP
    [int]    $LineNumber

    ServerInfo([string]$Hostname, [string]$IPMI_IP, [string]$ILO_IP, [int]$LineNumber) {
        $this.Hostname   = $Hostname
        $this.IPMI_IP    = $IPMI_IP
        $this.ILO_IP     = $ILO_IP
        $this.LineNumber = $LineNumber
    }

    [string] ShortName() {
        $idx = $this.Hostname.IndexOf('.')
        if ($idx -ge 0) { return $this.Hostname.Substring(0, $idx) }
        return $this.Hostname
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Load Private helpers and Public surface modules.
# Use Import-Module (not dot-source) so functions land in the module system and
# can be discovered via Get-Command / Export-ModuleMember.
# ──────────────────────────────────────────────────────────────────────────────
$_moduleBase  = $PSScriptRoot
$_privateRoot = Join-Path $_moduleBase 'Private'
$_publicRoot  = Join-Path $_moduleBase 'Public'

# Load order: dependency-ordered so classes are ready before consumers
$_privateOrder = @(
    'Audit.psm1',       # needs classes from root — defines New-AuditLogger
    'Config.psm1',      # standalone
    'Credentials.psm1', # standalone
    'Executor.psm1',    # defines New-CommandResult, Invoke-NativeCommand
    'FileIO.psm1',      # uses Config functions
    'Inventory.psm1',   # uses Config, FileIO functions
    'Logging.psm1',     # standalone
    'Base.psm1',        # uses AuditLogger, CommandResult classes + FileIO, Config fns
    'Router.psm1'       # routing helper
)

foreach ($_f in $_privateOrder) {
    $_fp = Join-Path $_privateRoot $_f
    if (Test-Path $_fp) {
        try   { Import-Module $_fp -Force -DisableNameChecking -Global -ErrorAction Stop }
        catch { Write-Warning "Failed to load private module $($_f): $_" }
    }
}

# Public psm1 modules
if (Test-Path $_publicRoot) {
    Get-ChildItem $_publicRoot -Filter '*.psm1' | ForEach-Object {
        try   { Import-Module $_.FullName -Force -DisableNameChecking -Global -ErrorAction Stop }
        catch { Write-Warning "Failed to load public module $($_.Name): $_" }
    }
}

# Export everything from this module
Export-ModuleMember -Function * -Alias *

# vim: ts=4 sw=4 et
