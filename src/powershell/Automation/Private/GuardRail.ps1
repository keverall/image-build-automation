#
# Private/GuardRail.ps1 - Destructive-action guard rail for build/deploy commands.
#
# When a -GuardRail pattern is supplied to a build/deploy command, the resolved
# target server name MUST match that pattern before any destructive action is
# taken. This protects shared/production networks where the client's test server
# sits alongside production servers: a typo or wrong serial must never result in
# a production server being overwritten with a Windows ISO + firmware.
#
# The guard is a CASE-INSENSITIVE REGULAR EXPRESSION matched against the resolved
# server name. Examples:
#   -GuardRail 'quickview\.ilo0'   matches 'quickview.ilo03.alp'
#   -GuardRail 'quickview.*ilo3'   matches 'quickview.ilo03.alp' and 'quickviewXilo3y'
#   -GuardRail 'test\-srv'         matches any name containing 'test-srv'
#   -GuardRail '.*'                matches everything (use with care)
#
# If the name does NOT match, the command aborts with NO changes and a clear
# message telling the operator to make the names match. If it matches, a
# destructive confirmation (typing YES) is required unless -SkipConfirmation or
# -DryRun are supplied, or the run is automated (where it auto-cancels unless
# -SkipConfirmation is explicitly set). Use -NonDestructive for review-only
# commands (e.g. Configure-PhysicalBuild) so the guard still gates the target but
# does not demand a destructive-confirm prompt.

function Assert-GuardRail {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string] $GuardRail,
        [string] $ResolvedServerName,
        [string] $SerialNumber,
        [string] $ApplianceName,
        [string] $ActionDescription = 'build/deploy',
        [switch] $DryRun,
        [switch] $SkipConfirmation,
        [switch] $NonDestructive
    )

    # No guard rail requested - no restriction.
    if ([string]::IsNullOrWhiteSpace($GuardRail)) { return $true }

    $logger = Get-Logger 'GuardRail'
    $resolved = if ($ResolvedServerName) { $ResolvedServerName } else { $null }

    $matched = $false
    if ($resolved) {
        # Guard is a case-insensitive regex; '.' matches any character.
        try {
            $matched = [bool]($resolved -match $GuardRail)
        } catch {
            $logger.Error("Guard rail pattern '$GuardRail' is not a valid regular expression: $($_.Exception.Message)")
            return $false
        }
    }

    if (-not $matched) {
        $logger.Error("GUARD RAIL MISMATCH: target '$resolved' does not match guard pattern '$GuardRail'. Refusing to $ActionDescription. No changes made. Make the server name match the guard to proceed.")
        Write-Host "`n  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  GUARD RAIL MISMATCH - ACTION BLOCKED                            ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host "  Target server : $resolved" -ForegroundColor White
        Write-Host "  Guard pattern : $GuardRail" -ForegroundColor White
        Write-Host "  Action        : $ActionDescription" -ForegroundColor Yellow
        Write-Host "  Result        : No changes made." -ForegroundColor Green
        Write-Host ""
        return $false
    }

    # Matched - show the guard context and require explicit confirmation for
    # destructive actions.
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "  GUARD RAIL MATCH - DESTRUCTIVE ACTION" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Guard pattern : $GuardRail" -ForegroundColor Yellow
    Write-Host "  Target server : $resolved" -ForegroundColor White
    if ($SerialNumber)  { Write-Host "  Serial number : $SerialNumber" -ForegroundColor White }
    if ($ApplianceName) { Write-Host "  Appliance     : $ApplianceName" -ForegroundColor White }
    if (-not $NonDestructive) {
        Write-Host ""
        Write-Host "  WARNING: this will OVERWRITE '$resolved' with a Windows ISO image," -ForegroundColor Red
        Write-Host "  partition layout, Windows setup, and firmware from the supplied" -ForegroundColor Red
        Write-Host "  archive. This is DESTRUCTIVE." -ForegroundColor Red
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Skipping confirmation prompt." -ForegroundColor DarkYellow
        return $true
    }

    if ($SkipConfirmation) {
        $logger.Info("Guard rail matched and -SkipConfirmation supplied; proceeding with $ActionDescription for '$resolved'.")
        return $true
    }

    $isAutomated = ([System.Environment]::GetEnvironmentVariable('AUTOMATED_MODE') -eq 'true') -or `
                   ([System.Environment]::GetEnvironmentVariable('CI') -eq 'true')
    if ($isAutomated) {
        $logger.Warning("AUTOMATED_MODE/CI detected with no -SkipConfirmation: auto-cancelling $ActionDescription for '$resolved' to avoid an unconfirmed destructive action.")
        Write-Host "  Non-interactive / automated mode: confirmation unavailable - auto-cancelled." -ForegroundColor Yellow
        return $false
    }

    if ($NonDestructive) {
        # Review-only command: a matched guard is sufficient; no destructive
        # confirmation prompt is required to simply display the plan.
        return $true
    }

    $response = Read-Host "  Type 'YES' to confirm the destructive $ActionDescription of '$resolved'"
    if ($response -ne 'YES') {
        $logger.Warning("Operator did not confirm with 'YES'; cancelling $ActionDescription for '$resolved'.")
        Write-Host "  Action CANCELLED by operator." -ForegroundColor Yellow
        return $false
    }
    return $true
}

<#
.SYNOPSIS
    Enforce that -GuardRail was supplied to a build/deploy command.

.DESCRIPTION
    -GuardRail is MANDATORY on the build/deploy commands. On shared/production
    networks (where the client's test server lives alongside production servers)
    a guard rail is the only thing that stops a Windows ISO + firmware overwrite
    from hitting the wrong machine. If the operator omits it, this fails EARLY
    with an expressive, logged message and returns an error hashtable so the
    caller gets a clean result instead of an unguarded action.

.PARAMETER GuardRail
    The caller-supplied guard rail pattern.

.PARAMETER CommandName
    The owning command (used for logging + the error text).

.PARAMETER ActionDescription
    Human-readable description of the action being gated.

.OUTPUTS
    [hashtable] An error result to return from the command, or $null when the
    guard rail was supplied and the command may continue.
#>
function Assert-GuardRailRequired {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $GuardRail,
        [string] $CommandName,
        [string] $ActionDescription = 'build/deploy'
    )

    if ([string]::IsNullOrWhiteSpace($GuardRail)) {
        $logger = Get-Logger $CommandName
        $msg = "GUARD RAIL REQUIRED: -GuardRail must be supplied to $CommandName. " +
               "On shared/production networks a guard rail restricts which servers may be " +
               "overwritten by a Windows ISO image, partition layout, Windows setup, and " +
               "firmware. Supply a CASE-INSENSITIVE REGEX the target server name must match " +
               "(e.g. -GuardRail 'quickview\.ilo0'). Refusing to proceed without an explicit guard."
        $logger.Error($msg)
        Write-Host "`n  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  GUARD RAIL REQUIRED - ACTION BLOCKED                            ║" -ForegroundColor Red
        Write-Host "  ╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host "  Command : $CommandName" -ForegroundColor White
        Write-Host "  Action  : $ActionDescription" -ForegroundColor Yellow
        Write-Host "  Fix     : supply -GuardRail '<regex>' matching the approved target server(s)." -ForegroundColor Cyan
        Write-Host ""
        return @{
            Success             = $false
            GuardRailRequired   = $true
            Error               = $msg
        }
    }
    return $null
}
