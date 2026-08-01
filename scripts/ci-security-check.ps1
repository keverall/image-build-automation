#Requires -Version 7.0
<#
.SYNOPSIS
    CI security gate: PSScriptAnalyzer security rules, config validation, and
    GitLab-native report generation.

.DESCRIPTION
    Replaces the previous ci-security-check.ps1, which had three defects that
    made it unfit as a regulatory control:

      1. It scanned only 'src/powershell', ignoring 'scripts/' - which contains
         the CyberArk bootstrap and the GitLab maintenance triggers.
      2. It gated on -Severity Error only. Every security rule in
         PSScriptAnalyzer emits Warning, so the gate could never fire.
      3. It explicitly excluded PSAvoidUsingInvokeExpression,
         PSAvoidUsingConvertToSecureStringWithPlainText and
         PSAvoidUsingUsernameAndPasswordParams - the exact rules that detect
         the highest-severity defects in this repository.

    Naive secret grepping has been removed. GitLab native Secret Detection
    (Gitleaks) runs as a separate pipeline job and is authoritative; duplicating
    it here with a 'password|secret|key|token' substring match produced only
    unactionable warnings that were never gated on.

    Findings are matched against .security-baseline.json. A baselined finding is
    an explicitly risk-accepted exception carrying an owner, a justification and
    an expiry date. Expired exceptions are re-raised as active findings, so the
    baseline cannot be used to bury a finding indefinitely.

.PARAMETER Mode
    'report'  - always exit 0. Findings are still written to all report
                artifacts and surfaced in the MR. Used during the remediation
                window defined in docs/compliance/SECURITY_PIPELINE.md.
    'enforce' - exit non-zero when a non-baselined finding at or above
                -FailOn severity is present.

.PARAMETER FailOn
    Minimum severity that fails the build in 'enforce' mode.

.PARAMETER UpdateBaseline
    Regenerate .security-baseline.json from the current findings. Intended for
    the initial baselining exercise only; the resulting file must be reviewed
    and have owners and expiry dates set before it is committed.

.EXAMPLE
    pwsh -File scripts/ci-security-check.ps1 -Mode report

.EXAMPLE
    pwsh -File scripts/ci-security-check.ps1 -Mode enforce -FailOn Warning
#>
[CmdletBinding()]
param(
    [ValidateSet('report', 'enforce')]
    [string] $Mode = 'report',

    [ValidateSet('Information', 'Warning', 'Error')]
    [string] $FailOn = 'Warning',

    [string] $BaselinePath = '.security-baseline.json',

    [string] $OutputDirectory = 'generated/output/security',

    [switch] $UpdateBaseline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName
$settingsPath = Join-Path $projectRoot 'PSScriptAnalyzerSettings.Security.psd1'

if (-not (Test-Path -LiteralPath $settingsPath)) {
    throw "Security ruleset not found: $settingsPath"
}

if (-not [System.IO.Path]::IsPathRooted($BaselinePath)) {
    $BaselinePath = Join-Path $projectRoot $BaselinePath
}
if (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot $OutputDirectory
}
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory

# Severity ordering used for the -FailOn comparison.
$severityRank = @{ Information = 1; Warning = 2; Error = 3 }
$failRank = $severityRank[$FailOn]

# -----------------------------------------------------------------------------
# Provenance header - this block is the evidence record for the control.
# -----------------------------------------------------------------------------
$scanStartUtc = [DateTime]::UtcNow
$analyzerModule = Get-Module PSScriptAnalyzer -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $analyzerModule) {
    throw 'PSScriptAnalyzer is not installed. The security gate cannot run.'
}

Write-Output '=============================================================================='
Write-Output ' CI SECURITY GATE'
Write-Output '=============================================================================='
Write-Output (" Scan started (UTC) : {0:yyyy-MM-ddTHH:mm:ssZ}" -f $scanStartUtc)
Write-Output " Mode               : $Mode"
Write-Output " Fail on            : $FailOn and above"
Write-Output " PSScriptAnalyzer   : $($analyzerModule.Version)"
Write-Output " PowerShell         : $($PSVersionTable.PSVersion)"
Write-Output " Ruleset            : $([System.IO.Path]::GetFileName($settingsPath))"
Write-Output " Commit             : $(if ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { 'local' })"
Write-Output " Pipeline           : $(if ($env:CI_PIPELINE_ID) { $env:CI_PIPELINE_ID } else { 'local' })"
Write-Output '=============================================================================='

# -----------------------------------------------------------------------------
# File discovery
# -----------------------------------------------------------------------------
# 'scripts/modules' and 'vendor' hold vendored third-party code (HPEOneView,
# Pester, PSScriptAnalyzer). It is not ours to remediate and its sample files
# contain deliberate demo credentials. It is excluded here and covered instead
# by dependency scanning.
$excludedPattern = '[\\/](modules|vendor|generated|bin|\.git|__pycache__)[\\/]'

$scanRoots = @('src', 'scripts', 'tests') |
    ForEach-Object { Join-Path $projectRoot $_ } |
    Where-Object { Test-Path -LiteralPath $_ }

$targets = @(
    Get-ChildItem -Path $scanRoots -Recurse -Include '*.ps1', '*.psm1', '*.psd1' -File |
        Where-Object { $_.FullName -notmatch $excludedPattern }
)
# Root-level scripts (docker-entrypoint.ps1) are in scope too.
$targets += @(Get-ChildItem -Path $projectRoot -Filter '*.ps1' -File)

$targets = $targets | Sort-Object FullName -Unique

Write-Output ''
Write-Output "Analysing $($targets.Count) PowerShell files..."

# -----------------------------------------------------------------------------
# Analysis
# -----------------------------------------------------------------------------
# Invoke-ScriptAnalyzer -Path takes a single string, so files are analysed
# individually. This also means one unparseable file cannot abort the whole run.
$findings = [System.Collections.Generic.List[object]]::new()
$analysisErrors = [System.Collections.Generic.List[string]]::new()

foreach ($file in $targets) {
    try {
        $result = Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath -ErrorAction Stop
        foreach ($item in $result) { $findings.Add($item) }
    } catch {
        $relative = [System.IO.Path]::GetRelativePath($projectRoot, $file.FullName)
        $analysisErrors.Add("${relative}: $($_.Exception.Message)")
    }
}

if ($analysisErrors.Count -gt 0) {
    # A file that cannot be analysed is an unscanned file, which is a control
    # gap rather than a warning. It fails the gate in enforce mode.
    Write-Output ''
    Write-Output "ANALYSIS FAILURES ($($analysisErrors.Count)) - these files were NOT scanned:"
    $analysisErrors | ForEach-Object { Write-Output "  - $_" }
}

# -----------------------------------------------------------------------------
# Fingerprinting
# -----------------------------------------------------------------------------
# The fingerprint deliberately excludes the line number so that a baselined
# exception survives unrelated edits above it, but includes the offending
# source text so that changing the code invalidates the exception.
function Get-FindingFingerprint {
    param([Parameter(Mandatory)] $Finding, [Parameter(Mandatory)][string] $RelativePath)

    $extentText = ''
    if ($Finding.PSObject.Properties.Name -contains 'Extent' -and $Finding.Extent) {
        $extentText = $Finding.Extent.Text
    }
    # Collapse whitespace so reformatting does not churn the baseline.
    $normalised = ($extentText -replace '\s+', ' ').Trim()

    $material = '{0}|{1}|{2}' -f $Finding.RuleName, $RelativePath, $normalised
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($material)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

$normalisedFindings = foreach ($finding in $findings) {
    # 'TypeNotFound' is a parser diagnostic, not a rule violation. The Automation
    # module defines its classes in Automation.psm1 and dot-sources Public/ and
    # Private/ at import time, so analysing those files in isolation cannot
    # resolve the types. Syntax is validated properly by scripts/lint.ps1, which
    # parses in project context. Excluded here to avoid 14 false positives.
    if ($finding.RuleName -eq 'TypeNotFound') { continue }

    $relative = [System.IO.Path]::GetRelativePath($projectRoot, $finding.ScriptPath) -replace '\\', '/'
    [PSCustomObject]@{
        Fingerprint = Get-FindingFingerprint -Finding $finding -RelativePath $relative
        RuleName    = $finding.RuleName
        Severity    = [string]$finding.Severity
        File        = $relative
        Line        = [int]$finding.Line
        Column      = [int]$finding.Column
        Message     = $finding.Message
    }
}
$normalisedFindings = @($normalisedFindings | Sort-Object File, Line, RuleName)

# -----------------------------------------------------------------------------
# Baseline
# -----------------------------------------------------------------------------
if ($UpdateBaseline) {
    $generated = [ordered]@{
        '$schema'   = 'https://gitlab.internal/schemas/security-baseline-v1.json'
        generatedAt = $scanStartUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        note        = 'Each exception REQUIRES owner, justification and expiry before merge. Unreviewed entries fail the gate.'
        exceptions  = @(
            $normalisedFindings | ForEach-Object {
                [ordered]@{
                    fingerprint   = $_.Fingerprint
                    rule          = $_.RuleName
                    file          = $_.File
                    line          = $_.Line
                    message       = $_.Message
                    owner         = 'UNASSIGNED'
                    justification = 'UNREVIEWED - generated by -UpdateBaseline'
                    expires       = $scanStartUtc.AddDays(90).ToString('yyyy-MM-dd')
                }
            }
        )
    }
    $generated | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $BaselinePath -Encoding utf8
    Write-Output ''
    Write-Output "Baseline written to $BaselinePath with $($normalisedFindings.Count) entries."
    Write-Output 'Review each entry and set owner, justification and expires before committing.'
    exit 0
}

$baselineIndex = @{}
$expiredExceptions = [System.Collections.Generic.List[object]]::new()
$invalidExceptions = [System.Collections.Generic.List[object]]::new()

if (Test-Path -LiteralPath $BaselinePath) {
    $baseline = Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
    $today = $scanStartUtc.Date

    foreach ($exception in @($baseline.exceptions)) {
        $owner = if ($exception.PSObject.Properties.Name -contains 'owner') { $exception.owner } else { '' }
        $justification = if ($exception.PSObject.Properties.Name -contains 'justification') { $exception.justification } else { '' }
        $expires = if ($exception.PSObject.Properties.Name -contains 'expires') { $exception.expires } else { '' }

        # An exception without an accountable owner is not an accepted risk.
        if ([string]::IsNullOrWhiteSpace($owner) -or $owner -eq 'UNASSIGNED' -or
            [string]::IsNullOrWhiteSpace($justification) -or $justification -like 'UNREVIEWED*') {
            $invalidExceptions.Add($exception)
            continue
        }

        $expiryDate = [DateTime]::MinValue
        if (-not [DateTime]::TryParse($expires, [ref]$expiryDate)) {
            $invalidExceptions.Add($exception)
            continue
        }
        if ($expiryDate.Date -lt $today) {
            $expiredExceptions.Add($exception)
            continue
        }

        $baselineIndex[$exception.fingerprint] = $exception
    }
}

$active = @($normalisedFindings | Where-Object { -not $baselineIndex.ContainsKey($_.Fingerprint) })
$suppressed = @($normalisedFindings | Where-Object { $baselineIndex.ContainsKey($_.Fingerprint) })

# -----------------------------------------------------------------------------
# Console report
# -----------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Findings by rule ---'
if ($normalisedFindings.Count -eq 0) {
    Write-Output '  (none)'
} else {
    $normalisedFindings |
        Group-Object RuleName |
        Sort-Object Count -Descending |
        ForEach-Object {
            $ruleActive = @($_.Group | Where-Object { -not $baselineIndex.ContainsKey($_.Fingerprint) }).Count
            '{0,5} total {1,5} active  {2}' -f $_.Count, $ruleActive, $_.Name
        } |
        ForEach-Object { Write-Output "  $_" }
}

if ($active.Count -gt 0) {
    Write-Output ''
    Write-Output "--- Active findings ($($active.Count)) ---"
    $active |
        Select-Object Severity, RuleName, @{ N = 'Location'; E = { '{0}:{1}' -f $_.File, $_.Line } }, Message |
        Format-Table -AutoSize -Wrap |
        Out-String -Width 200 |
        Write-Output
}

if ($invalidExceptions.Count -gt 0) {
    Write-Output ''
    Write-Output "--- Baseline entries rejected: missing owner/justification/expiry ($($invalidExceptions.Count)) ---"
    $invalidExceptions | ForEach-Object { Write-Output "  - $($_.rule) $($_.file)" }
}

if ($expiredExceptions.Count -gt 0) {
    Write-Output ''
    Write-Output "--- Baseline exceptions EXPIRED, now re-raised ($($expiredExceptions.Count)) ---"
    $expiredExceptions | ForEach-Object { Write-Output "  - $($_.rule) $($_.file) (expired $($_.expires), owner $($_.owner))" }
}

# -----------------------------------------------------------------------------
# GitLab report artifacts
# -----------------------------------------------------------------------------
# Code Quality (Code Climate) format - renders inline in the MR widget on all
# GitLab tiers, so the gate stays visible even without Ultimate.
$codeClimate = @(
    $active | ForEach-Object {
        [ordered]@{
            description = '[{0}] {1}' -f $_.RuleName, $_.Message
            check_name  = $_.RuleName
            fingerprint = $_.Fingerprint
            severity    = switch ($_.Severity) {
                'Error' { 'blocker' }
                'Warning' { 'major' }
                default { 'minor' }
            }
            location    = [ordered]@{
                path  = $_.File
                lines = [ordered]@{ begin = $_.Line }
            }
        }
    }
)
$codeClimatePath = Join-Path $OutputDirectory 'pssa-code-quality.json'
ConvertTo-Json -InputObject $codeClimate -Depth 6 -AsArray | Set-Content -LiteralPath $codeClimatePath -Encoding utf8

# SAST report format - consumed by the Security Dashboard on Ultimate, and a
# harmless inert artifact on Free/Premium.
$sastReport = [ordered]@{
    version = '15.0.7'
    scan    = [ordered]@{
        analyzer = [ordered]@{
            id      = 'psscriptanalyzer'
            name    = 'PSScriptAnalyzer'
            version = "$($analyzerModule.Version)"
            vendor  = [ordered]@{ name = 'Internal Platform Engineering' }
        }
        scanner  = [ordered]@{
            id      = 'psscriptanalyzer'
            name    = 'PSScriptAnalyzer'
            version = "$($analyzerModule.Version)"
            vendor  = [ordered]@{ name = 'Internal Platform Engineering' }
        }
        type     = 'sast'
        status   = 'success'
        start_time = $scanStartUtc.ToString('yyyy-MM-ddTHH:mm:ss')
        end_time   = ([DateTime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ss')
    }
    vulnerabilities = @(
        $active | ForEach-Object {
            [ordered]@{
                id          = $_.Fingerprint
                category    = 'sast'
                name        = $_.RuleName
                message     = $_.Message
                description = $_.Message
                severity    = switch ($_.Severity) {
                    'Error' { 'High' }
                    'Warning' { 'Medium' }
                    default { 'Low' }
                }
                scanner     = [ordered]@{ id = 'psscriptanalyzer'; name = 'PSScriptAnalyzer' }
                location    = [ordered]@{
                    file       = $_.File
                    start_line = $_.Line
                }
                identifiers = @(
                    [ordered]@{
                        type  = 'psscriptanalyzer_rule'
                        name  = $_.RuleName
                        value = $_.RuleName
                        url   = "https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules/$($_.RuleName -replace '^PS','')"
                    }
                )
            }
        }
    )
}
$sastPath = Join-Path $OutputDirectory 'pssa-sast-report.json'
$sastReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $sastPath -Encoding utf8

# -----------------------------------------------------------------------------
# JSON configuration validation
# -----------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Validating JSON configuration ---'
$configRoot = Join-Path $projectRoot 'configs'
$invalidJson = [System.Collections.Generic.List[string]]::new()

if (Test-Path -LiteralPath $configRoot) {
    foreach ($json in Get-ChildItem -Path $configRoot -Recurse -Include '*.json' -File) {
        try {
            $null = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $invalidJson.Add("$($json.Name): $($_.Exception.Message)")
        }
    }
}

if ($invalidJson.Count -gt 0) {
    Write-Output "  INVALID ($($invalidJson.Count)):"
    $invalidJson | ForEach-Object { Write-Output "    - $_" }
} else {
    Write-Output '  All configuration files parsed successfully.'
}

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
$gating = @($active | Where-Object { $severityRank[$_.Severity] -ge $failRank })

$blockers = @()
if ($gating.Count -gt 0) { $blockers += "$($gating.Count) active finding(s) at $FailOn or above" }
if ($invalidJson.Count -gt 0) { $blockers += "$($invalidJson.Count) invalid JSON configuration file(s)" }
if ($analysisErrors.Count -gt 0) { $blockers += "$($analysisErrors.Count) file(s) could not be analysed" }
if ($invalidExceptions.Count -gt 0) { $blockers += "$($invalidExceptions.Count) baseline exception(s) without owner/justification/expiry" }
if ($expiredExceptions.Count -gt 0) { $blockers += "$($expiredExceptions.Count) expired baseline exception(s)" }

Write-Output ''
Write-Output '=============================================================================='
Write-Output ' SUMMARY'
Write-Output '=============================================================================='
Write-Output " Files analysed        : $($targets.Count)"
Write-Output " Total findings        : $($normalisedFindings.Count)"
Write-Output " Risk-accepted         : $($suppressed.Count)"
Write-Output " Active findings       : $($active.Count)"
Write-Output " Gating ($FailOn+)     : $($gating.Count)"
Write-Output " Reports               : $([System.IO.Path]::GetRelativePath($projectRoot, $OutputDirectory))"
Write-Output '=============================================================================='

if ($blockers.Count -eq 0) {
    Write-Output 'RESULT: PASS'
    exit 0
}

Write-Output 'Blocking conditions:'
$blockers | ForEach-Object { Write-Output "  - $_" }

if ($Mode -eq 'enforce') {
    Write-Output ''
    Write-Output 'RESULT: FAIL (enforce mode)'
    exit 1
}

Write-Output ''
Write-Output 'RESULT: FAIL, not gated (report mode)'
Write-Output 'This job will begin failing the pipeline at the cutover date recorded in'
Write-Output 'docs/compliance/SECURITY_PIPELINE.md. Remediate or baseline before then.'
exit 0
