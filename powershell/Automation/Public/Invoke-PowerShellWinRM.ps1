#
# Public/Invoke-PowerShellWinRM.ps1 — Execute a PowerShell script on a remote server via WinRM.
#

function Invoke-PowerShellWinRM {
    <#
    .SYNOPSIS
        Execute a PowerShell script on a remote server via WinRM.

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
