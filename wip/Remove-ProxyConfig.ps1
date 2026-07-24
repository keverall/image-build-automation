# =============================================================================
# Remove-ProxyConfig.ps1 - Find and remove ALL proxy configuration on this host
# =============================================================================
# Run on the Windows automation server where Connect-OVMgmt fails with:
#   "The proxy tunnel request to proxy 'http://webcorp...' failed ..."
#
# The repo is proxy-free (verified at commit 7167f91). The proxy address is
# fed to .NET's HttpClient by THIS SERVER's environment: PowerShell profile
# env vars, persisted User/Machine env vars, WinINet (IE) proxy registry, or
# WinHTTP. Every interactive pwsh session re-loads the profile, which is why
# the failure keeps coming back.
#
# USAGE:
#   pwsh -File Remove-ProxyConfig.ps1          # REPORT ONLY (default, safe)
#   pwsh -File Remove-ProxyConfig.ps1 -Apply   # REPORT + REMOVE everything found
#
# After -Apply, open a NEW pwsh window and re-run:
#   Test-ServerConnectivity -ManagementHost <oneview-appliance-host>
# =============================================================================
[CmdletBinding()]
param([switch]$Apply)

$ErrorActionPreference = 'Continue'
$found = 0

function Report([string]$Where, [string]$What) {
    $script:found++
    Write-Host "  [FOUND] $Where : $What" -ForegroundColor Red
}
function Ok([string]$Where) {
    Write-Host "  [clean] $Where" -ForegroundColor Green
}

Write-Host "`n=== 1. Process environment (current session) ===" -ForegroundColor Cyan
$proxyVars = Get-ChildItem Env: | Where-Object { $_.Name -match 'proxy' }
if ($proxyVars) {
    foreach ($v in $proxyVars) {
        Report "process env" "`$env:$($v.Name) = $($v.Value)"
        if ($Apply) { Remove-Item "Env:$($v.Name)" -ErrorAction SilentlyContinue; Write-Host "    -> removed from this session" -ForegroundColor Yellow }
    }
} else { Ok "process env (no proxy variables in this session)" }

Write-Host "`n=== 2. Persisted environment variables (User + Machine registry) ===" -ForegroundColor Cyan
$names = 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY','http_proxy','https_proxy','all_proxy','no_proxy'
foreach ($scope in 'User','Machine') {
    $hit = $false
    foreach ($n in $names) {
        $val = [Environment]::GetEnvironmentVariable($n, $scope)
        if ($null -ne $val) {
            $hit = $true
            Report "$scope scope" "$n = $val"
            if ($Apply) { [Environment]::SetEnvironmentVariable($n, $null, $scope); Write-Host "    -> deleted ($scope)" -ForegroundColor Yellow }
        }
    }
    if (-not $hit) { Ok "$scope scope" }
}

Write-Host "`n=== 3. PowerShell profile files ===" -ForegroundColor Cyan
$profilePaths = @(
    $PROFILE.AllUsersAllHosts,
    $PROFILE.AllUsersCurrentHost,
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.CurrentUserCurrentHost
) | Select-Object -Unique
$proxyPattern = '(?i)(proxy|webcorp)'
foreach ($p in $profilePaths) {
    if (Test-Path $p) {
        $lines = Select-String -Path $p -Pattern $proxyPattern
        if ($lines) {
            foreach ($l in $lines) { Report $p "line $($l.LineNumber): $($l.Line.Trim())" }
            if ($Apply) {
                $kept = Get-Content $p | Where-Object { $_ -notmatch $proxyPattern }
                Set-Content -Path $p -Value $kept -Encoding UTF8
                Write-Host "    -> proxy lines stripped from $p" -ForegroundColor Yellow
            }
        } else { Ok $p }
    } else {
        Write-Host "  [absent] $p" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== 4. WinINet (Internet Options) proxy - HKCU ===" -ForegroundColor Cyan
$ie = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$props = Get-ItemProperty $ie
if ($props.ProxyEnable -eq 1 -or $props.ProxyServer -or $props.AutoConfigURL) {
    if ($props.ProxyEnable -eq 1) { Report "$ie\ProxyEnable" "1 (proxy enabled), server: $($props.ProxyServer)" }
    if ($props.AutoConfigURL)     { Report "$ie\AutoConfigURL" $props.AutoConfigURL }
    if ($Apply) {
        Set-ItemProperty $ie -Name ProxyEnable -Value 0
        Remove-ItemProperty $ie -Name ProxyServer -ErrorAction SilentlyContinue
        Remove-ItemProperty $ie -Name AutoConfigURL -ErrorAction SilentlyContinue
        Write-Host "    -> WinINet proxy disabled and cleared" -ForegroundColor Yellow
    }
} else { Ok "WinINet proxy disabled / not set" }

Write-Host "`n=== 5. WinHTTP system proxy (netsh) ===" -ForegroundColor Cyan
$winhttp = (netsh winhttp show proxy) 2>&1 | Out-String
if ($winhttp -match 'Proxy Server\s*:\s*(\S+)' -and $Matches[1] -ne '(none)') {
    Report "WinHTTP" $Matches[1]
    if ($Apply) {
        netsh winhttp reset proxy | Out-Null
        Write-Host "    -> WinHTTP proxy reset (requires elevation)" -ForegroundColor Yellow
    }
} else { Ok "WinHTTP: direct access (no proxy)" }

Write-Host "`n=== 6. .NET runtime proxy view (what Connect-OVMgmt will actually use) ===" -ForegroundColor Cyan
$def = [System.Net.WebRequest]::DefaultWebProxy
try {
    $probe = $def.GetProxy('https://oneview.invalid')
    if ($probe -and $probe.AbsoluteUri -notlike 'https://oneview.invalid*') {
        Report ".NET DefaultWebProxy" $probe.AbsoluteUri
        if ($Apply) {
            [System.Net.WebRequest]::DefaultWebProxy = $null
            Write-Host "    -> DefaultWebProxy set to `$null for this session" -ForegroundColor Yellow
        }
    } else { Ok ".NET resolves DIRECT for https targets" }
} catch { Write-Host "  [info] could not probe DefaultWebProxy: $($_.Exception.Message)" }

Write-Host "`n==================================================================" -ForegroundColor Cyan
if ($found -eq 0) {
    Write-Host "RESULT: No proxy configuration found anywhere on this host." -ForegroundColor Green
    Write-Host "If Connect-OVMgmt still fails, the HPEOneView module cache or a GPO is re-applying it - re-run this script in the exact session that fails." -ForegroundColor Yellow
} elseif (-not $Apply) {
    Write-Host "RESULT: $found proxy setting(s) found. Re-run with -Apply to remove them:" -ForegroundColor Yellow
    Write-Host "  pwsh -File Remove-ProxyConfig.ps1 -Apply" -ForegroundColor White
} else {
    Write-Host "RESULT: $found proxy setting(s) found and removed." -ForegroundColor Green
    Write-Host "NEXT: open a NEW pwsh window, then run:" -ForegroundColor Cyan
    Write-Host "  Test-ServerConnectivity -ManagementHost <oneview-appliance-host>" -ForegroundColor White
}
Write-Host ""
