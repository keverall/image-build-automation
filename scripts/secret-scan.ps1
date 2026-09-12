#Requires -Version 5.1
<#
.SYNOPSIS
    Repository secret scanner: tokens, SHA/HMAC keys, SSH private and public keys.

.DESCRIPTION
    PowerShell-native, offline secret scanner. It complements - does not replace -
    GitLab-managed Secret Detection (Gitleaks), which remains the authoritative
    CI scanner and the only one that scans full git history. This script exists
    because it adds three things Gitleaks does not do in this repository:

      1. A repo-specific policy: findings in Markdown (.md/.markdown) are
         REPORT-ONLY (documentation legitimately contains example tokens and
         key snippets); findings in code/config are gate-eligible.
      2. A -Fix path that rewrites a hardcoded PowerShell secret into an
         environment-variable reference ($env:NAME), per DevSecOps practice.
      3. No external binary and no network, so it runs in a pre-commit hook and
         on an air-gapped developer workstation.

    Rules cover the four categories named by the platform standard:
      * Tokens        - GitLab / GitHub / AWS / Google / Slack / JWT / bearer
      * SHA keys      - HMAC / signing / symmetric / salt material
      * SSH keys      - private blocks (OpenSSH/RSA/EC/DSA/PGP/PuTTY) and
                        public key bodies (authorized_keys material)
      * Connection strings / storage account keys

    Findings are matched against .secret-scan-allowlist.json by fingerprint
    (rule + file + normalised matched text). Risk acceptance is explicit: each
    entry carries an owner, justification and expiry, and an expired entry is
    re-raised. Inline suppression is also supported with a trailing comment
    'secret-scan:allow' on the offending line, for one-off false positives.

.PARAMETER Mode
    'report'  - always exit 0; findings are still written to all artifacts.
    'enforce' - exit non-zero when an active code/config finding is present.

.PARAMETER FailOn
    Minimum severity that gates in 'enforce' mode.

.PARAMETER Fix
    Rewrite hardcoded PowerShell secret literals into $env:NAME references.
    Creates a .bak backup next to each modified file. Never touches Markdown.
    Honours -WhatIf / -Confirm.

.PARAMETER Path
    Roots to scan. Defaults to the repository root.

.EXAMPLE
    pwsh -File scripts/secret-scan.ps1 -Mode report

.EXAMPLE
    pwsh -File scripts/secret-scan.ps1 -Mode enforce -FailOn Warning

.EXAMPLE
    pwsh -File scripts/secret-scan.ps1 -Fix -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('report', 'enforce')]
    [string] $Mode = 'report',

    [ValidateSet('Information', 'Warning', 'Error')]
    [string] $FailOn = 'Warning',

    [string[]] $Path,

    [string] $OutputDirectory = 'generated/output/security',

    [string] $AllowlistPath = '.secret-scan-allowlist.json',

    [switch] $Fix
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

if (-not $Path -or $Path.Count -eq 0) { $Path = @($projectRoot) }
$Path = @($Path | ForEach-Object {
        if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $projectRoot $_ }
    })

if (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot $OutputDirectory
}
if (-not [System.IO.Path]::IsPathRooted($AllowlistPath)) {
    $AllowlistPath = Join-Path $projectRoot $AllowlistPath
}
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory

$severityRank = @{ Information = 1; Warning = 2; Error = 3 }
$failRank = $severityRank[$FailOn]

# Directories that are never ours to remediate, or are generated build output.
$excludedDirPattern = '[\\/](\.git|node_modules|vendor|generated|bin|__pycache__|\.ruff_cache|\.venv|scripts[\\/]modules)[\\/]'

# Binary / archive extensions that cannot carry reviewable text secrets.
$excludedExtensions = @(
    '.iso', '.exe', '.dll', '.png', '.jpg', '.jpeg', '.gif', '.pdf', '.deb',
    '.zip', '.gz', '.woff', '.woff2', '.ico', '.docx', '.xlsx', '.pptx'
)

# Text extensions eligible for automatic -Fix. Markdown is deliberately absent.
$fixableExtensions = @('.ps1', '.psm1', '.psd1')

# -----------------------------------------------------------------------------
# Rules
# -----------------------------------------------------------------------------
# CaptureGroup: the regex group holding the secret material (0 = whole match).
# Fixable: whether -Fix may rewrite this finding in a PowerShell file.
function Get-SecretScanRuleSet {
    return @(
        # --- SSH keys -------------------------------------------------------
        [PSCustomObject]@{
            Id = 'ssh-private-key'; Severity = 'Error'; Category = 'ssh-key'; Fixable = $false; CaptureGroup = 0
            Regex = '-----BEGIN (?:OPENSSH|RSA|EC|DSA|ECDSA|PGP|ENCRYPTED)? ?PRIVATE KEY-----'
        }
        [PSCustomObject]@{
            Id = 'putty-private-key'; Severity = 'Error'; Category = 'ssh-key'; Fixable = $false; CaptureGroup = 0
            Regex = 'PuTTY-User-Key-File-[0-9]+'
        }
        [PSCustomObject]@{
            Id = 'ssh-public-key'; Severity = 'Warning'; Category = 'ssh-key'; Fixable = $false; CaptureGroup = 0
            Regex = '(?:ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp(?:256|384|521))[ \t]+AAAA[A-Za-z0-9+/]{40,}={0,3}'
        }

        # --- Tokens ---------------------------------------------------------
        [PSCustomObject]@{
            Id = 'gitlab-token'; Severity = 'Error'; Category = 'token'; Fixable = $true; CaptureGroup = 0
            Regex = 'gl(?:pat|ptt|dt|rt|soat|cbt|ft|imt|agent|ffct)-[0-9A-Za-z_\-]{20,}'
        }
        [PSCustomObject]@{
            Id = 'github-token'; Severity = 'Error'; Category = 'token'; Fixable = $true; CaptureGroup = 0
            Regex = '(?:ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{36,}|github_pat_[0-9A-Za-z_]{60,}'
        }
        [PSCustomObject]@{
            Id = 'aws-access-key'; Severity = 'Error'; Category = 'token'; Fixable = $true; CaptureGroup = 0
            Regex = '(?:A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}'
        }
        [PSCustomObject]@{
            Id = 'google-api-key'; Severity = 'Error'; Category = 'token'; Fixable = $true; CaptureGroup = 0
            Regex = 'AIza[0-9A-Za-z_\-]{35}'
        }
        [PSCustomObject]@{
            Id = 'slack-token'; Severity = 'Error'; Category = 'token'; Fixable = $true; CaptureGroup = 0
            Regex = 'xox[baprs]-[0-9A-Za-z\-]{10,}'
        }
        [PSCustomObject]@{
            Id = 'jwt'; Severity = 'Warning'; Category = 'token'; Fixable = $false; CaptureGroup = 0
            Regex = 'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'
        }
        [PSCustomObject]@{
            Id = 'bearer-token'; Severity = 'Warning'; Category = 'token'; Fixable = $false; CaptureGroup = 0
            Regex = '(?i)bearer\s+[A-Za-z0-9_\-\.=]{20,}'
        }

        # --- SHA / HMAC / signing keys --------------------------------------
        [PSCustomObject]@{
            Id = 'sha-hmac-signing-key'; Severity = 'Error'; Category = 'sha-key'; Fixable = $true; CaptureGroup = 'value'
            Regex = '(?i)(?<name>(?:sha[0-9]*|hmac|signing|signature|symmetric|master|encryption|crypto)[_\- ]?(?:key|secret|salt))\s*[:=]\s*["'']?(?<value>[A-Za-z0-9+/=_\-]{16,})'
        }

        # --- Weak / default credentials (short, must not rely on entropy) ---
        [PSCustomObject]@{
            Id = 'weak-default-credential'; Severity = 'Warning'; Category = 'credential'; Fixable = $true; CaptureGroup = 'value'
            Regex = '(?i)(?<name>\w*(?:password|passwd|pwd|secret|token)\w*)\s*[:=]\s*["''](?<value>password|passw0rd|p@ssw0rd|admin|administrator|letmein|welcome|changeit|secret|123456|qwerty)["'']'
        }

        # --- Connection strings / storage keys ------------------------------
        [PSCustomObject]@{
            Id = 'connection-string-credential'; Severity = 'Error'; Category = 'connection-string'; Fixable = $false; CaptureGroup = 0
            Regex = '(?i)(?:AccountKey|SharedAccessKey|SharedAccessSignature)\s*=\s*[^;"''\s]{8,}'
        }

        # --- Generic secret assignment (last; lowest confidence) -------------
        [PSCustomObject]@{
            Id = 'generic-secret-assignment'; Severity = 'Warning'; Category = 'generic'; Fixable = $true; CaptureGroup = 'value'
            Regex = '(?i)(?<name>\w*(?:password|passwd|pwd|secret|token|api[_-]?key|apikey|access[_-]?key|client[_-]?secret)\w*)\s*[:=]\s*["''](?<value>[^"''\r\n]{8,})["'']'
        }
    )
}

# Values that are structurally not secrets: placeholders, interpolation, blanks.
$placeholderPattern = '(?i)^(?:\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|\$\(|%[A-Za-z_][A-Za-z0-9_]*%|\{\{[^}]+\}\}|<[^>]+>|redacted|changeme|change_me|placeholder|example|sample|dummy|fake|test[_-]?only|your[_-]?(?:token|key|password|secret|api[_-]?key)|none|null|true|false|mysecret.*)$'

# Names that describe where a secret lives, rather than being one. A value that
# is itself an env-var name / path / regex is not a disclosed credential.
$nonValueNamePattern = '(?i)(?:Env|EnvVar|Name|Path|Paths|Regex|Suffix|Url|Uri|File|Dir|Directory|KeyName|TokenName)$'
$allCapsSnakePattern = '^[A-Z0-9_]+$'

function Test-Placeholder {
    param([Parameter(Mandatory)] [string] $Value)
    if ($Value -match $placeholderPattern) { return $true }
    # A run of placeholder characters (e.g. glptt-xxxxxxxx) is not a real token.
    if ($Value -match '[xX]{4,}') { return $true }
    return $false
}

# Generic assignments are noisy by nature. A candidate must look like a real
# credential: long enough, high entropy, no structural characters, and not a
# capitalised NAME (env-var name) masquerading as a value.
function Test-GenericSecret {
    param(
        [Parameter(Mandatory)] [string] $Value,
        [Parameter(Mandatory)] [string] $VariableName
    )
    if ($Value.Length -lt 12) { return $false }
    if ($Value -notmatch '^[A-Za-z0-9!@#$%^&*_.+\-]+$') { return $false }
    if ($Value -match $allCapsSnakePattern) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($VariableName) -and $VariableName -match $nonValueNamePattern) { return $false }
    if ((Get-ShannonEntropy -Value $Value) -lt 3.0) { return $false }
    return $true
}

# [System.IO.Path]::GetRelativePath is .NET Core only; keep Windows PowerShell 5.1
# working by resolving relative paths ourselves.
function Get-RelativePathCompat {
    param(
        [Parameter(Mandatory)] [string] $BasePath,
        [Parameter(Mandatory)] [string] $TargetPath
    )
    $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\', '/')
    $target = (Resolve-Path -LiteralPath $TargetPath).Path
    if ($target.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $target.Substring($base.Length).TrimStart('\', '/')
    }
    return $target
}

function Get-ShannonEntropy {
    param([Parameter(Mandatory)] [string] $Value)
    if ($Value.Length -eq 0) { return 0.0 }
    $counts = @{}
    foreach ($char in $Value.ToCharArray()) {
        $key = [string]$char
        if ($counts.ContainsKey($key)) { $counts[$key]++ } else { $counts[$key] = 1 }
    }
    $entropy = 0.0
    foreach ($count in $counts.Values) {
        $p = $count / $Value.Length
        $entropy -= $p * [Math]::Log($p, 2)
    }
    return [Math]::Round($entropy, 2)
}

function Get-FindingFingerprint {
    param(
        [Parameter(Mandatory)] [string] $RuleId,
        [Parameter(Mandatory)] [string] $RelativePath,
        [Parameter(Mandatory)] [string] $MatchedText
    )
    $normalised = ($MatchedText -replace '\s+', ' ').Trim()
    $material = '{0}|{1}|{2}' -f $RuleId, $RelativePath, $normalised
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($material)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Format-MaskedValue {
    param([Parameter(Mandatory)] [string] $Value)
    $flat = $Value -replace '\s+', ' '
    if ($flat.Length -le 8) { return ('*' * $flat.Length) }
    return '{0}...{1} ({2} chars)' -f $flat.Substring(0, 4), $flat.Substring($flat.Length - 4), $flat.Length
}

# -----------------------------------------------------------------------------
# File discovery
# -----------------------------------------------------------------------------
$rules = Get-SecretScanRuleSet
$ruleIndex = @{}
foreach ($rule in $rules) { $ruleIndex[$rule.Id] = $rule }

$files = [System.Collections.Generic.List[object]]::new()
foreach ($root in $Path) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $item = Get-Item -LiteralPath $root
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
            if ($_.FullName -match $excludedDirPattern) { return }
            if ($excludedExtensions -contains $_.Extension.ToLowerInvariant()) { return }
            $files.Add($_)
        }
    } else {
        $files.Add($item)
    }
}
$files = @($files | Sort-Object FullName -Unique)

Write-Output '=============================================================================='
Write-Output ' SECRET SCAN (tokens / SHA keys / SSH keys)'
Write-Output '=============================================================================='
Write-Output (" Scan started (UTC) : {0:yyyy-MM-ddTHH:mm:ssZ}" -f [DateTime]::UtcNow)
Write-Output " Mode               : $Mode"
Write-Output " Fail on            : $FailOn and above"
Write-Output " Fix                : $([bool]$Fix)"
Write-Output " Files in scope     : $($files.Count)"
Write-Output " Commit             : $(if ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { 'local' })"
Write-Output '=============================================================================='

# -----------------------------------------------------------------------------
# Scan
# -----------------------------------------------------------------------------
$findings = [System.Collections.Generic.List[object]]::new()
$skippedBinary = 0

foreach ($file in $files) {
    $extension = $file.Extension.ToLowerInvariant()
    $relativePath = (Get-RelativePathCompat -BasePath $projectRoot -TargetPath $file.FullName) -replace '\\', '/'
    $isMarkdown = @('.md', '.markdown') -contains $extension

    try {
        $content = [System.IO.File]::ReadAllText($file.FullName)
    } catch {
        continue
    }
    if ([string]::IsNullOrEmpty($content)) { continue }
    # Cheap binary check: a NUL byte in the first 8 KB means this is not text.
    $head = $content.Substring(0, [Math]::Min(8192, $content.Length))
    if ($head.Contains([char]0)) { $skippedBinary++; continue }

    foreach ($rule in $rules) {
        foreach ($match in [regex]::Matches($content, $rule.Regex)) {
            if ($rule.CaptureGroup -eq 0) {
                $value = $match.Value
                $variableName = ''
                $valueStart = $match.Index
                $valueLength = $match.Length
            } else {
                $group = if ($rule.CaptureGroup -is [int]) { $match.Groups[$rule.CaptureGroup] } else { $match.Groups[$rule.CaptureGroup] }
                if (-not $group.Success) { continue }
                $value = $group.Value
                $variableName = if ($match.Groups['name'].Success) { $match.Groups['name'].Value } else { '' }
                $valueStart = $group.Index
                $valueLength = $group.Length
            }

            if (Test-Placeholder -Value $value) { continue }
            # Generic findings additionally require real entropy so that prose
            # and obvious non-secrets do not flood the report.
            if ($rule.Id -eq 'generic-secret-assignment' -and -not (Test-GenericSecret -Value $value -VariableName $variableName)) { continue }

            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $lineText = ($content -split "`n")[$lineNumber - 1]
            $inlineAllowed = $lineText -match 'secret-scan:\s*allow'

            $finding = [PSCustomObject]@{
                RuleId = $rule.Id
                Severity = $rule.Severity
                Category = $rule.Category
                File = $relativePath
                Line = $lineNumber
                Match = $value
                VariableName = $variableName
                IsMarkdown = $isMarkdown
                InlineAllowed = $inlineAllowed
                ValueStart = $valueStart
                ValueLength = $valueLength
                Fingerprint = Get-FindingFingerprint -RuleId $rule.Id -RelativePath $relativePath -MatchedText $value
            }
            $findings.Add($finding)
        }
    }
}

# -----------------------------------------------------------------------------
# Allowlist
# -----------------------------------------------------------------------------
$allowIndex = @{}
$expiredAllow = [System.Collections.Generic.List[object]]::new()
$invalidAllow = [System.Collections.Generic.List[object]]::new()
$today = [DateTime]::UtcNow.Date

if (Test-Path -LiteralPath $AllowlistPath) {
    $allowlist = Get-Content -LiteralPath $AllowlistPath -Raw | ConvertFrom-Json
    foreach ($entry in @($allowlist.exceptions)) {
        $owner = if ($entry.PSObject.Properties.Name -contains 'owner') { $entry.owner } else { '' }
        $justification = if ($entry.PSObject.Properties.Name -contains 'justification') { $entry.justification } else { '' }
        $expires = if ($entry.PSObject.Properties.Name -contains 'expires') { $entry.expires } else { '' }

        if ([string]::IsNullOrWhiteSpace($owner) -or $owner -eq 'UNASSIGNED' -or
            [string]::IsNullOrWhiteSpace($justification) -or $justification -like 'UNREVIEWED*') {
            $invalidAllow.Add($entry); continue
        }
        $expiry = [DateTime]::MinValue
        if (-not [DateTime]::TryParse($expires, [ref]$expiry)) { $invalidAllow.Add($entry); continue }
        if ($expiry.Date -lt $today) { $expiredAllow.Add($entry); continue }
        $allowIndex[$entry.fingerprint] = $entry
    }
}

$active = [System.Collections.Generic.List[object]]::new()
$suppressed = [System.Collections.Generic.List[object]]::new()
foreach ($finding in $findings) {
    if ($finding.InlineAllowed -or $allowIndex.ContainsKey($finding.Fingerprint)) {
        $suppressed.Add($finding)
    } else {
        $active.Add($finding)
    }
}

# -----------------------------------------------------------------------------
# Optional fix
# -----------------------------------------------------------------------------
$fixedCount = 0
if ($Fix) {
    $byFile = $active | Where-Object { $ruleIndex[$_.RuleId].Fixable -and -not $_.IsMarkdown -and ($fixableExtensions -contains [System.IO.Path]::GetExtension($_.File).ToLowerInvariant()) } |
        Group-Object File

    foreach ($group in $byFile) {
        $relative = $group.Name
        $absolute = Join-Path $projectRoot $relative
        $content = [System.IO.File]::ReadAllText($absolute)
        $changed = $content

        # Apply by exact character offsets, highest first, so earlier offsets
        # remain valid and the surrounding quotes/flow are untouched. Offsets
        # come from the same content that was scanned.
        foreach ($finding in ($group.Group | Sort-Object ValueStart -Descending)) {
            $envName = if ([string]::IsNullOrWhiteSpace($finding.VariableName)) {
                'SECRET_VALUE'
            } else {
                ($finding.VariableName -replace '[^A-Za-z0-9]+', '_').Trim('_').ToUpperInvariant()
            }
            $replacement = '$env:' + $envName
            $changed = $changed.Remove($finding.ValueStart, $finding.ValueLength).Insert($finding.ValueStart, $replacement)
        }

        if ($changed -ne $content) {
            if ($PSCmdlet.ShouldProcess($relative, 'Replace hardcoded secret with $env: reference')) {
                $backup = "$absolute.secret-scan.bak"
                if (-not (Test-Path -LiteralPath $backup)) {
                    Copy-Item -LiteralPath $absolute -Destination $backup -Force
                }
                Set-Content -LiteralPath $absolute -Value $changed -Encoding utf8 -NoNewline
                $fixedCount++
                Write-Output ("  FIXED  {0} ({1} finding(s)); backup -> {2}" -f $relative, $group.Count, [System.IO.Path]::GetFileName($backup))
            }
        }
    }
}

# -----------------------------------------------------------------------------
# Console report
# -----------------------------------------------------------------------------
$codeActive = @($active | Where-Object { -not $_.IsMarkdown })
$markdownActive = @($active | Where-Object { $_.IsMarkdown })

Write-Output ''
Write-Output '--- Active findings by rule ---'
if ($active.Count -eq 0) {
    Write-Output '  (none)'
} else {
    $active | Group-Object RuleId | Sort-Object Count -Descending | ForEach-Object {
        $mdCount = @($_.Group | Where-Object { $_.IsMarkdown }).Count
        '{0,5} total  {1,5} code  {2,5} markdown  {3}' -f $_.Count, ($_.Count - $mdCount), $mdCount, $_.Name
    } | ForEach-Object { Write-Output "  $_" }
}

if ($codeActive.Count -gt 0) {
    Write-Output ''
    Write-Output "--- CODE/CONFIG FINDINGS ($($codeActive.Count)) - gate-eligible ---"
    $codeActive | Select-Object Severity, RuleId, @{ N = 'Location'; E = { '{0}:{1}' -f $_.File, $_.Line } }, @{ N = 'Match'; E = { Format-MaskedValue -Value $_.Match } } |
        Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output
}

if ($markdownActive.Count -gt 0) {
    Write-Output ''
    Write-Output "--- MARKDOWN FINDINGS ($($markdownActive.Count)) - report-only ---"
    $markdownActive | Select-Object RuleId, @{ N = 'Location'; E = { '{0}:{1}' -f $_.File, $_.Line } }, @{ N = 'Match'; E = { Format-MaskedValue -Value $_.Match } } |
        Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Output
}

if ($suppressed.Count -gt 0) { Write-Output ''; Write-Output "Risk-accepted / inline-allowed: $($suppressed.Count)" }
if ($invalidAllow.Count -gt 0) { Write-Output ''; Write-Output "Allowlist entries REJECTED (missing owner/justification/expiry): $($invalidAllow.Count)" }
if ($expiredAllow.Count -gt 0) { Write-Output ''; Write-Output "Allowlist entries EXPIRED and re-raised: $($expiredAllow.Count)" }
if ($skippedBinary -gt 0) { Write-Output "Binary files skipped: $skippedBinary" }

# -----------------------------------------------------------------------------
# GitLab Code Quality artifact (renders inline in the MR on all tiers)
# -----------------------------------------------------------------------------
$codeQuality = @(
    $codeActive | ForEach-Object {
        [ordered]@{
            description = '[{0}] {1} in {2}' -f $_.RuleId, $_.Category, $_.File
            check_name = $_.RuleId
            fingerprint = $_.Fingerprint
            severity = switch ($_.Severity) { 'Error' { 'blocker' } 'Warning' { 'major' } default { 'minor' } }
            location = [ordered]@{ path = $_.File; lines = [ordered]@{ begin = $_.Line } }
        }
    }
)
$codeQualityPath = Join-Path $OutputDirectory 'secret-scan-code-quality.json'
ConvertTo-Json -InputObject $codeQuality -Depth 6 -AsArray | Set-Content -LiteralPath $codeQualityPath -Encoding utf8

# Machine-readable report (includes markdown findings and allowlist state).
$reportPath = Join-Path $OutputDirectory 'secret-scan-report.json'
[ordered]@{
    generatedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    mode = $Mode
    failOn = $FailOn
    filesScanned = $files.Count
    summary = [ordered]@{
        total = $findings.Count
        active = $active.Count
        codeActive = $codeActive.Count
        markdownActive = $markdownActive.Count
        suppressed = $suppressed.Count
        fixed = $fixedCount
    }
    findings = @($active | ForEach-Object {
            [ordered]@{
                rule = $_.RuleId; severity = $_.Severity; category = $_.Category
                file = $_.File; line = $_.Line; markdown = $_.IsMarkdown
                maskedMatch = Format-MaskedValue -Value $_.Match; fingerprint = $_.Fingerprint
            }
        })
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
$gating = @($codeActive | Where-Object { $severityRank[$_.Severity] -ge $failRank })
$blockers = [System.Collections.Generic.List[string]]::new()
if ($gating.Count -gt 0) { $blockers.Add("$($gating.Count) active code/config secret finding(s) at $FailOn or above") }
if ($invalidAllow.Count -gt 0) { $blockers.Add("$($invalidAllow.Count) allowlist entr(y/ies) without owner/justification/expiry") }
if ($expiredAllow.Count -gt 0) { $blockers.Add("$($expiredAllow.Count) expired allowlist entr(y/ies)") }

Write-Output ''
Write-Output '=============================================================================='
Write-Output ' SUMMARY'
Write-Output '=============================================================================='
Write-Output " Files scanned        : $($files.Count)"
Write-Output " Total findings       : $($findings.Count)"
Write-Output " Code/config active   : $($codeActive.Count)"
Write-Output " Markdown (report)    : $($markdownActive.Count)"
Write-Output " Risk-accepted        : $($suppressed.Count)"
Write-Output " Fixed                : $fixedCount"
Write-Output " Gating ($FailOn+)    : $($gating.Count)"
Write-Output " Reports              : $(Get-RelativePathCompat -BasePath $projectRoot -TargetPath $OutputDirectory)"
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
exit 0
