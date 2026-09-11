#
# Public/Invoke-PowerShellWinRM.ps1 - Execute a PowerShell script on a remote server via WinRM.
#

function Invoke-PowerShellWinRM {
    <#
    .SYNOPSIS
        Execute a PowerShell script on a remote server via WinRM.

    .DESCRIPTION
        Executes PowerShell scripts on remote Windows servers using WinRM (WS-Man).
        Creates a temporary PSSession for the operation and returns results
        including stdout and any errors encountered during execution.

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

    .PARAMETER ArgumentList
        Optional arguments passed to the remote script block (which should
        declare a param() block to receive them). Use this to pass secrets so
        they travel over the encrypted remoting channel instead of being
        embedded in the script text.

    .RETURNS
        [hashtable] with keys: Success (bool), Output (string).

    .EXAMPLE
        $r = Invoke-PowerShellWinRM -Script 'Get-Process' -Server 'srv01.corp.local' -Username 'admin' -Password 'pass'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 0)][string] $Script,
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 1)][string] $Server,
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 2)][string] $Username,
        [Parameter(Mandatory, ParameterSetName = 'Run', Position = 3)][SecureString] $Password,
        [Parameter(Mandatory, ParameterSetName = 'Run' = $false)][string]    $Transport  = 'NTLM',
        [Parameter(Mandatory, ParameterSetName = 'Run' = $false)][int]       $TimeoutSeconds = 300,
        [Parameter(Mandatory, ParameterSetName = 'Run' = $false)][object[]]  $ArgumentList,
        [Parameter(Mandatory, ParameterSetName = 'Help')][switch]$Help
    )
    if ($Help) { Get-CommandHelp -Name 'Invoke-PowerShellWinRM'; return }
    try {
        $cred    = New-Object System.Management.Automation.PSCredential($Username, $Password)
        $session = New-PSSession -ComputerName $Server -Credential $cred -Authentication $Transport -ErrorAction Stop
        try {
            $invokeArgs = @{
                Session     = $session
                ScriptBlock = ([scriptblock]::Create($Script))
                ErrorAction = 'Stop'
            }
            if ($ArgumentList) { $invokeArgs['ArgumentList'] = $ArgumentList }
            $output = Invoke-Command @invokeArgs
        } finally {
            Remove-PSSession $session -ErrorAction SilentlyContinue | Out-Null
        }
        return @{ Success = $true; Output = ($output | Out-String) }
    }
    catch {
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}
