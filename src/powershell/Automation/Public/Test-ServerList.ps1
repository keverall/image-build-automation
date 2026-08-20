#
# Public/Test-ServerList.ps1 - Validate and load the server list text file.
#

function Test-ServerList {
    <#
    .SYNOPSIS
        Validate and load the server list text file.

    .DESCRIPTION
        Reads the server list text file (server_list.txt) and validates it:
        skips empty lines and comments (lines starting with #), and trims any
        comma-separated metadata from each line. Returns a structured result
        describing the file path, server count and the validated server names.

        By default the command writes a HUMAN-READABLE report to the terminal (a
        formatted list of servers) and returns NOTHING on the success stream, so
        the operator never sees a truncated raw hashtable dump. Use -PassThru to
        also capture the structured [hashtable] (Success, Path, Count, Error,
        Servers) for scripting, or -Json to emit it as a JSON string.

    .PARAMETER ServerListPath
        Explicit path to server_list.txt. When omitted, the file is resolved as
        '<ConfigDir>/server_list.txt'.

    .PARAMETER ConfigDir
        Config directory used to locate the default server_list.txt when
        -ServerListPath is not supplied. Defaults to 'configs'.

    .PARAMETER DryRun
        Accepted for parameter-surface consistency with the other automation
        commands. This command performs no modifications (it only reads a file),
        so -DryRun has no additional effect beyond a [DRY-RUN] note in the report.

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable report.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream. By
        default the command writes only the human-readable report and returns
        nothing, so the terminal/log never receives a truncated hashtable dump.
        Capture the result into a variable, e.g.
        `$r = Test-ServerList -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .EXAMPLE
        Test-ServerList

    .EXAMPLE
        Test-ServerList -ServerListPath .\staging_servers.txt -PassThru
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Alias('Path')]
        [string] $ServerListPath,
        [Alias('CfgDir')]
        [string] $ConfigDir = 'configs',
        [Alias('Dry')]
        [switch] $DryRun,
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
    )

    # Resolve the source file: explicit -ServerListPath wins, otherwise derive
    # the default path from -ConfigDir (mirrors other commands' ConfigDir default).
    $resolvedPath = if ($PSBoundParameters.ContainsKey('ServerListPath') -and $ServerListPath) {
        $ServerListPath
    } else {
        Join-Path $ConfigDir 'server_list.txt'
    }

    if (-not (Test-Path $resolvedPath)) {
        $result = @{
            Success = $false
            Path    = $resolvedPath
            Count   = 0
            Error   = "Server list not found: $resolvedPath"
            Servers = @()
        }
        return (_Emit-ServerListResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -DryRun:$DryRun)
    }

    $servers = @()
    Get-Content $resolvedPath -Encoding UTF8 | ForEach-Object {
        $hostname = $_.Trim()
        if ($hostname -and -not $hostname.StartsWith('#')) {
            $hostname = $hostname.Split(',')[0].Trim()
            if ($hostname) { $servers += $hostname }
        }
    }

    if (-not $servers) { Write-Warning "No valid servers found in $resolvedPath" }

    $result = @{
        Success = $true
        Path    = $resolvedPath
        Count   = $servers.Count
        Error   = $null
        Servers = $servers
    }

    return (_Emit-ServerListResult -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -DryRun:$DryRun)
}

# ── Result emission ───────────────────────────────────────────────────────────
function _Emit-ServerListResult {
    <#
    .SYNOPSIS
        Emits the server-list validation result via the shared, DRY
        _Publish-Result helper (consistent with every other automation command).

    .DESCRIPTION
        Delegates to _Publish-Result so behaviour is identical across all
        commands: a human-readable report by default (no truncated hashtable
        dump on the terminal / in logs), with -Json / -PassThru for data
        consumers. The rich, command-specific _Format-ServerListResult view is
        supplied as the -CustomView so the report keeps its familiar layout.
        Pass -Quiet to suppress the report when the caller handles display.
    #>
    param(
        [hashtable] $Result,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet,
        [switch] $DryRun
    )

    _Publish-Result -Result $Result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet -CustomView {
        param($r)
        _Format-ServerListResult -Result $r -DryRun:$DryRun
    }
}

# ── Output formatting ─────────────────────────────────────────────────────────
function _Format-ServerListResult {
    <#
    .SYNOPSIS
        Formats the server-list validation result as a clean, readable report.
    #>
    param([hashtable] $Result, [switch] $DryRun)

    $valid       = $Result.Success
    $header      = if ($valid) { 'VALID' } else { 'INVALID' }
    $statusColor = if ($valid) { 'Green' } else { 'Red' }
    $dryRunTag   = if ($DryRun) { ' [DRY-RUN]' } else { '' }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  Server List Validation" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Status:   ${header}${dryRunTag}" -ForegroundColor $statusColor
    Write-Host "  File:     $($Result.Path)"
    Write-Host "  Servers:  $($Result.Count)"
    Write-Host ""

    if ($Result.Error) {
        Write-Host "  Error:    $($Result.Error)" -ForegroundColor Red
        Write-Host ""
    }

    if ($valid -and $Result.Servers.Count -gt 0) {
        Write-Host "  --- Servers ---" -ForegroundColor Yellow
        foreach ($s in $Result.Servers) {
            Write-Host "    - $s"
        }
        Write-Host ""
    } elseif ($valid) {
        Write-Host "  (no servers listed)" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}
