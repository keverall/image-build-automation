#
# Private/Executor.ps1 — Process execution utilities with retry support.
#

function Invoke-NativeCommand {
    <#
    .SYNOPSIS
        Execute a native command and return a CommandResult.

    .PARAMETER Command
        Command and arguments as a string array.

    .PARAMETER TimeoutSeconds
        Execution timeout (default 300 s).

    .PARAMETER WorkingDirectory
        Optional working directory.

    .EXAMPLE
        $r = Invoke-NativeCommand -Command @('git','status')
    #>
    [CmdletBinding()]
    [OutputType([CommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)][string[]] $Command,
        [int]    $TimeoutSeconds   = 300,
        [string] $WorkingDirectory = $null
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName  = $Command[0]
    $psi.Arguments = if ($Command.Count -gt 1) {
        ($Command[1..($Command.Count - 1)] | ForEach-Object { '"' + $_.Replace('"','`"') + '"' }) -join ' '
    } else { '' }
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

    $stdOut = [System.Text.StringBuilder]::new()
    $stdErr = [System.Text.StringBuilder]::new()

    try {
        $proc = [System.Diagnostics.Process]::new()
        $proc.StartInfo = $psi
        $proc.add_OutputDataReceived({ param($s,$e) if ($e.Data) { $stdOut.AppendLine($e.Data) | Out-Null } })
        $proc.add_ErrorDataReceived({  param($s,$e) if ($e.Data) { $stdErr.AppendLine($e.Data) | Out-Null } })
        $null = $proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill() } catch { }
            return [CommandResult]::new(-1, '', "Timed out after $TimeoutSeconds s")
        }
        $proc.WaitForExit()
        return [CommandResult]::new($proc.ExitCode, $stdOut.ToString(), $stdErr.ToString())
    }
    catch {
        return [CommandResult]::new(-1, '', $_.Exception.Message)
    }
}

function Invoke-NativeCommandWithRetry {
    <#
    .SYNOPSIS
        Run a native command with exponential back-off retry.

    .EXAMPLE
        Invoke-NativeCommandWithRetry -Command @('ping','-c','1','8.8.8.8') -MaxAttempts 3
    #>
    [CmdletBinding()]
    [OutputType([CommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)][string[]] $Command,
        [int]    $MaxAttempts    = 3,
        [double] $DelaySeconds   = 5.0,
        [int]    $TimeoutSeconds = 300
    )
    $last = $null
    for ($i = 0; $i -le $MaxAttempts; $i++) {
        if ($i -gt 0) { Start-Sleep -Seconds ([math]::Pow(2, $i - 1) * $DelaySeconds) }
        $last = Invoke-NativeCommand -Command $Command -TimeoutSeconds $TimeoutSeconds
        if ($last.Success) { return $last }
        Write-Warning "Attempt $($i+1)/$($MaxAttempts+1) failed: $($last.StandardError.Trim())"
    }
    return $last
}

function New-CommandResult {
    <#
    .SYNOPSIS
        Factory for CommandResult (useful in tests / dry-run stubs).
    #>
    [CmdletBinding()]
    [OutputType([CommandResult])]
    param([int]$ReturnCode, [string]$StandardOutput, [string]$StandardError)
    return [CommandResult]::new($ReturnCode, $StandardOutput, $StandardError)
}
