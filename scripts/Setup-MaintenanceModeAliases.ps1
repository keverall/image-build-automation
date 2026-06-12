# Setup script for maintenance mode shortcuts
# Run this once to add mm commands to your profile

$profilePath = $PROFILE
$modulePath = Join-Path $PSScriptRoot '../src/powershell/Automation/Automation.psd1'

# Check if profile exists
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host "Created new profile at: $profilePath"
}

# Check if module exists
if (-not (Test-Path $modulePath)) {
    Write-Host "ERROR: Automation module not found at: $modulePath"
    exit 1
}

# Add module import if not already present
$profileContent = Get-Content $profilePath -Raw
if ($profileContent -notmatch 'Automation\.psd1') {
    Add-Content -Path $profilePath -Value "`n# Image Build Automation`nImport-Module '$modulePath' -WarningAction SilentlyContinue"
    Write-Host "Added module import to profile"
}

# Add mm function if not already present
if ($profileContent -notmatch 'function mm ') {
    $mmFunction = @'

# Maintenance Mode shortcut
function mm {
    param(
        [Parameter(Position=0)][string]$Action = 'enable',
        [Parameter(Position=1)][string]$Target,
        [Parameter(Position=2)][string]$Mode = 'scom',
        [Parameter(Position=3)][string]$Environment = 'Prod',
        [switch]$DryRun,
        [string]$Start = 'now',
        [string]$End = '+2hours',
        [Parameter(ValueFromRemainingArguments=$true)]$ExtraArgs
    )
    
    $params = @{
        Action = $Action
        Mode = $Mode
        Environment = $Environment
        Start = $Start
        End = $End
    }
    
    if ($Target) { $params['TargetId'] = $Target }
    if ($DryRun) { $params['DryRun'] = $true }
    if ($ExtraArgs) { $params += $ExtraArgs }
    
    $result = Set-MaintenanceMode @params
    
    # Format output
    Write-Host "=== Maintenance Mode ===" -ForegroundColor Cyan
    Write-Host "Action: $($result.Action) | Target: $($result.TargetId) | Mode: $($result.Mode)" -ForegroundColor Yellow
    Write-Host "Environment: $($result.Environment) | Time: $($result.StartTimeUtc) → $($result.EndTimeUtc)" -ForegroundColor Yellow
    Write-Host "Status: $(if($result.Success){'✓ Success'}else{'✗ Failed'})" -ForegroundColor $(if($result.Success){'Green'}else{'Red'})
    if ($result.Error) { Write-Host "Error: $($result.Error)" -ForegroundColor Red }
    if ($result.DryRun) { Write-Host "[DRY RUN MODE]" -ForegroundColor Magenta }
    Write-Host "========================" -ForegroundColor Cyan
    
    return $result
}

# Quick aliases
function mmenable { mm enable @args }
function mmdisable { mm disable @args }
function mmvalidate { mm validate @args }
'@
    
    Add-Content -Path $profilePath -Value $mmFunction
    Write-Host "Added mm function and aliases to profile"
}

Write-Host "`n✅ Setup complete! Restart PowerShell or run: . `$PROFILE"
Write-Host "`nUsage examples:"
Write-Host "  mm enable PROD-CLUSTER-01 scom Prod -DryRun"
Write-Host "  mmenable PROD-CLUSTER-01"
Write-Host "  mmdisable PROD-CLUSTER-01"
Write-Host "  mmvalidate PROD-CLUSTER-01"
