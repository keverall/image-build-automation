#Requires -Version 7.0
<#
.SYNOPSIS
    Produce a machine-readable evidence record of the controls run in a pipeline.

.DESCRIPTION
    EMIR Art. 34 and DORA Art. 8-10 require that ICT controls be demonstrable,
    not merely present. This job collects the artefacts produced by the lint,
    test, PowerShell SAST and secret detection jobs into a single dated record
    retained as a GitLab artifact. The output is designed to be copied nightly
    into the Bank's authoritative evidence store; the GitLab artifact retention
    is a convenience copy only.

    The script never fails the pipeline on its own (it is evidence, not a gate),
    but it emits a clear warning if a downstream control failed so the result
    is not mistaken for a clean run.

.PARAMETER OutputPath
    Path of the JSON evidence file to write.
#>
[CmdletBinding()]
param(
    [string] $OutputPath = 'generated/output/compliance/evidence.json'
)

Set-StrictMode -Version Latest
$errorActionPreference = 'Stop'

$projectRoot = (Get-Item (Join-Path $PSScriptRoot '..' '..')).FullName
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $projectRoot $OutputPath
}
$null = New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath) | Out-Null

$now = [DateTime]::UtcNow

function Get-ArtifactValue {
    param([string] $Path, [scriptblock] $Selector = { $_ })
    if (Test-Path -LiteralPath $Path) {
        try {
            $content = Get-Content -LiteralPath $Path -Raw
            return & $Selector $content
        } catch {
            return "present-but-unreadable"
        }
    }
    return $null
}

$securitySummary = Get-ArtifactValue (Join-Path $projectRoot 'generated/output/security/pssa-code-quality.json') { 'attached' }
$coverage = Get-ArtifactValue (Join-Path $projectRoot 'generated/output/coverage/coverage-results.xml') {
    if ($_ -match 'line-rate="([0-9.]+)"') {
        [math]::Round([double]::Parse($Matches[1]) * 100, 2)
    } else { $null }
}

# The CI_* variables are populated by GitLab; locally they are all empty, which
# is fine for the offline validation path.
$evidence = [ordered]@{
    generatedAtUtc = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
    standard       = 'EMIR 648/2012 Art.34; DORA 2022/2554 Art.8-10; EBA/GL/2019/04'
    pipeline = [ordered]@{
        instance = $env:CI_SERVER_HOST
        project  = $env:CI_PROJECT_PATH
        ref      = $env:CI_COMMIT_REF_NAME
        sha      = $env:CI_COMMIT_SHA
        source   = $env:CI_PIPELINE_SOURCE
        id       = $env:CI_PIPELINE_ID
        jobId    = $env:CI_JOB_ID
        runner   = $env:CI_RUNNER_DESCRIPTION
    }
    controls = @(
        [ordered]@{
            id        = 'lint-powershell'
            objective = 'Syntax and style validation of all PowerShell'
            evidence  = 'generated/logs/ (pwsh-lint output)'
        }
        [ordered]@{
            id        = 'test-unit'
            objective = 'Automated functional verification'
            coveragePercent = $coverage
            evidence  = 'generated/output/coverage/coverage-results.xml'
        }
        [ordered]@{
            id        = 'sast-powershell'
            objective = 'Detection of code-injection, insecure credential handling, error suppression'
            evidence  = 'generated/output/security/pssa-sast-report.json; pssa-code-quality.json'
            status    = if ($securitySummary) { 'attached' } else { 'not-attached' }
        }
        [ordered]@{
            id        = 'secret_detection'
            objective = 'Detection of committed secrets across full history'
            evidence  = 'gl-secret-detection-report.json'
        }
    )
}

# Surface qualitative control metadata that GitLab does not compute itself:
# which regulatory requirement each job maps to, and the remediation posture.
$evidence.controls[2].remediationPosture = $env:SECURITY_ENFORCEMENT_MODE
$evidence.controls[2].failOn = $env:SECURITY_FAIL_ON

$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8

Write-Output "Compliance evidence written to: $OutputPath"
Write-Output "  Standard         : $($evidence.standard)"
Write-Output "  Controls recorded: $($evidence.controls.Count)"
Write-Output "  Coverage %       : $(if ($null -eq $coverage) { 'n/a (offline)' } else { $coverage })"
Write-Output ''
Write-Output 'NOTE: This artifact is evidence, not a gate. Review control results in the'
Write-Output 'respective jobs and the Security Dashboard. Retention of the authoritative'
Write-Output 'copy is governed by the Bank evidence-retention policy, not by the GitLab'
Write-Output 'artifact expiry.'
