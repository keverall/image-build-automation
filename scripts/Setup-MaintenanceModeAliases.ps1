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
    [CmdletBinding()]
    param(
        [Parameter(Position=0)][string]$Action,
        [Parameter(Position=1)][string]$TargetId,
        [string]$Mode,
        [string]$Environment = 'Prod',
        [string]$Start = 'now',
        [string]$End = '+2hours',
        [string]$SerialNumber,
        [string]$Username,
        [string]$ManagementHost,
        [switch]$DryRun
    )
    
    # Detect double-dash arguments (bash syntax, not PowerShell)
    $MyInvocation.Line -match '--\w+' | Out-Null
    if ($Matches) {
        Write-Error "Invalid arguments: $($Matches.Values -join ', '). PowerShell uses single-dash syntax (e.g., '-DryRun' not '--dryrun')"
        return
    }
    
    if (-not $Action) {
        Get-Help Set-MaintenanceMode
        return
    }
    
    # Case-insensitive validation
    $validActions = @('enable', 'disable', 'validate', 'status')
    $actionLower = $Action.ToLower()
    if ($validActions -notcontains $actionLower) {
        Write-Error "Invalid action: '$Action'. Valid actions: $($validActions -join ', ')"
        return
    }
    
    if ($Mode) {
        $modeLower = $Mode.ToLower()
        if (@('scom', 'oneview') -notcontains $modeLower) {
            Write-Error "Invalid mode: '$Mode'. Valid modes: scom, oneview"
            return
        }
        $Mode = $modeLower
    }
    
    if ($Environment) {
        $envLower = $Environment.ToLower()
        if (@('test', 'prod') -notcontains $envLower) {
            Write-Error "Invalid environment: '$Environment'. Valid environments: Test, Prod"
            return
        }
        $Environment = $envLower.Substring(0, 1).ToUpper() + $envLower.Substring(1)
    }
    
    $params = @{ Action = $actionLower }
    if ($TargetId) { $params['TargetId'] = $TargetId }
    if ($Mode) { $params['Mode'] = $Mode }
    if ($Environment) { $params['Environment'] = $Environment }
    if ($Start) { $params['Start'] = $Start }
    if ($End) { $params['End'] = $End }
    if ($SerialNumber) { $params['SerialNumber'] = $SerialNumber }
    if ($Username) { $params['Username'] = $Username }
    if ($ManagementHost) { $params['ManagementHost'] = $ManagementHost }
    if ($DryRun) { $params['DryRun'] = $true }
    
    Set-MaintenanceMode @params
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
Write-Host "  mm enable CLU-CLUSTER-01 scom Prod -DryRun"
Write-Host "  mmenable CLU-CLUSTER-01"
Write-Host "  mmdisable CLU-CLUSTER-01"
Write-Host "  mmvalidate CLU-CLUSTER-01"
