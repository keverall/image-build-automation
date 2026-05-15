#
# Invoke-PowerShell.psm1 — PowerShell execution helpers (Public)
# Equivalent of Python utils/powershell.py
#

<#

.SYNOPSIS
    PowerShell execution helpers: local script invocation, WinRM remoting, and SCOM script templates.

#>

function Invoke-PowerShellScript {
    <#
    .SYNOPSIS
        Execute a PowerShell script block / string locally via `powershell.exe`.

        Mirrors Python run_powershell(script, capture_output, timeout, execution_policy).

    .PARAMETER Script
        PowerShell script to execute.

    .PARAMETER CaptureOutput
        Capture stdout / stderr (default: `$true`).

    .PARAMETER TimeoutSeconds
        Per-script timeout in seconds (default: 300).

    .PARAMETER ExecutionPolicy
        PowerShell execution-policy override (default: Bypass).

    .RETURNS
        [hashtable] with keys: Success (bool), Output (string).

    .EXAMPLE
        $r = Invoke-PowerShellScript -Script 'Get-Service | Select-Object -First 5 Name' -TimeoutSeconds 30
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Script,

        [Parameter(Mandatory = $false)][bool]      $CaptureOutput  = $true,

        [Parameter(Mandatory = $false)][int]       $TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)][string]    $ExecutionPolicy = 'Bypass'
    )

    $psArgs = @(
        '-ExecutionPolicy', $ExecutionPolicy,
        '-NoProfile',
        '-NonInteractive',
        '-Command', $Script
    )

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName              = 'powershell.exe'
        $psi.Arguments             = ($psArgs -join ' ')
        $psi.RedirectStandardOutput = $CaptureOutput
        $psi.RedirectStandardError  = $CaptureOutput
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true

        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit($TimeoutSeconds * 1000) | Out-Null

        $out = if ($CaptureOutput) { $p.StandardOutput.ReadToEnd().Trim() } else { '' }
        $err = if ($CaptureOutput) { $p.StandardError.ReadToEnd().Trim() }  else { '' }
        $combined = "$out`n$err"

        if ($p.ExitCode -ne 0) {
            Write-Error "PowerShell error (exit code $($p.ExitCode)): $err"
            return @{ Success = $false; Output = $combined }
        }
        return @{ Success = $true;  Output = $combined }
    }
    catch [System.TimeoutException] {
        return @{ Success = $false; Output = "PowerShell script timed out after $TimeoutSeconds s" }
    }
    catch {
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}

function Invoke-PowerShellWinRM {
    <#
    .SYNOPSIS
        Execute a PowerShell script on a remote server via WinRM.

        Mirrors Python run_powershell_winrm(script, server, username, password, transport, timeout).

    .PARAMETER Script
        PowerShell script to execute remotely.

    .PARAMETER Server
        Remote server hostname or IP.

    .PARAMETER Username
        Username for WinRM authentication.

    .PARAMETER Password
        Password for WinRM authentication.

    .PARAMETER Transport
        WinRM transport (default: NTLM).

    .PARAMETER TimeoutSeconds
        Timeout per command in seconds (default: 300).

    .RETURNS
        [hashtable] with keys: Success (bool), Output (string).

    .EXAMPLE
        $r = Invoke-PowerShellWinRM -Script 'Get-Process' -Server 'srv01.corp.local' -Username 'admin' -Password 'pass'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Script,
        [Parameter(Mandatory, Position = 1)][string] $Server,
        [Parameter(Mandatory, Position = 2)][string] $Username,
        [Parameter(Mandatory, Position = 3)][string] $Password,
        [Parameter(Mandatory = $false)][string]    $Transport  = 'NTLM',
        [Parameter(Mandatory = $false)][int]       $TimeoutSeconds = 300
    )

    try {
        $secPass = ConvertTo-SecureString $Password -AsPlainText -Force
        $cred    = New-Object System.Management.Automation.PSCredential($Username, $secPass)
        $session = New-PSSession -ComputerName $Server -Credential $cred -Authentication $Transport -ErrorAction Stop
        $output  = Invoke-Command -Session $session -ScriptBlock ([scriptblock]::Create($Script)) -ErrorAction Stop
        Remove-PSSession $session | Out-Null
        return @{ Success = $true; Output = ($output | Out-String) }
    }
    catch {
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}

function New-ScomConnection {
    <#
    .SYNOPSIS
        Returns a PowerShell command string that creates an SCOM 2015 management-group connection.

    .PARAMETER ManagementServer
        SCOM management server hostname / IP.

    .EXAMPLE
        $script = New-ScomConnection -ManagementServer 'scom01.corp.local'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ManagementServer
    )
    return @"
Import-Module OperationsManager -ErrorAction Stop
`$conn = New-SCOMManagementGroupConnection -ComputerName "$ManagementServer" -ErrorAction Stop
"@
}

function New-ScomMaintenanceScript {
    <#
    .SYNOPSIS
        Build a PowerShell script for SCOM maintenance mode start/stop on a group.

    .PARAMETER GroupDisplayName
        SCOM group display name.

    .PARAMETER DurationSeconds
        Duration in seconds (used for start).

    .PARAMETER Comment
        Maintenance comment string.

    .PARAMETER Operation
        'start' or 'stop' (default: start).

    .EXAMPLE
        $ps = New-ScomMaintenanceScript -GroupDisplayName 'PROD-CLUSTER-01' -DurationSeconds 14400 -Comment 'iRequest'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $GroupDisplayName,
        [Parameter(Mandatory, Position = 1)][int]    $DurationSeconds,
        [Parameter(Mandatory, Position = 2)][string] $Comment,
        [ValidateSet('start','stop')]
        [Parameter(Mandatory = $false)][string] $Operation = 'start'
    )
    $safeComment = $Comment.Replace("'", "''")
    if ($Operation -eq 'start') {
        return @"
Import-Module OperationsManager -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$duration = New-TimeSpan -Seconds $DurationSeconds
`$comment = '$safeComment'
`$failed = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        Write-Host "`$(`$inst.Name) already in maintenance - skipping"
    } else {
        try {
            Start-SCOMMaintenanceMode -Instance `$inst -Duration `$duration -Comment `$comment -ErrorAction Stop
            Write-Host "Maintenance started: `$(`$inst.Name)"
        } catch {
            Write-Error "Failed for `$(`$inst.Name): `$_"
            `$failed += `$inst.Name
        }
    }
}
if (`$failed.Count -gt 0) {
    Write-Error "Failed for: `$(`$failed -join ', ')"
    exit 1
} else {
    Write-Host "All instances entered maintenance successfully"
}
"@
    }
    else {
        return @"
Import-Module OperationsManager -ErrorAction Stop
`$group = Get-SCOMGroup -DisplayName "$GroupDisplayName" -ErrorAction Stop
`$instances = Get-SCOMClassInstance -Group `$group
`$stopped = @()
foreach (`$inst in `$instances) {
    if (`$inst.InMaintenanceMode) {
        try {
            Stop-SCOMMaintenanceMode -Instance `$inst -ErrorAction Stop
            Write-Host "Maintenance stopped: `$(`$inst.Name)"
            `$stopped += `$inst.Name
        } catch {
            Write-Error "Failed to stop for `$(`$inst.Name): `$_"
        }
    } else {
        Write-Host "`$(`$inst.Name) not in maintenance - skipping"
    }
}
if (`$stopped.Count -gt 0) {
    Write-Host "Stopped maintenance for `$(`$stopped.Count) instances"
} else {
    Write-Host "No instances were in maintenance"
}
"@
    }
}

# vim: ts=4 sw=4 et
