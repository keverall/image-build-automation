#
# Public/Invoke-PowerShellScript.ps1 — Execute a PowerShell script block / string locally.
#

function Invoke-PowerShellScript {
    <#
    .SYNOPSIS
        Execute a PowerShell script block / string locally via `powershell.exe`.

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
        $p   = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit($TimeoutSeconds * 1000) | Out-Null
        $out  = if ($CaptureOutput) { $p.StandardOutput.ReadToEnd().Trim() } else { '' }
        $err  = if ($CaptureOutput) { $p.StandardError.ReadToEnd().Trim() }  else { '' }
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
