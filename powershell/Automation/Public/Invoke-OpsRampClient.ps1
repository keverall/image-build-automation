#
# Public/Invoke-OpsRampClient.ps1 — OpsRamp client factory + CLI test helper.
#

function Invoke-OpsRampClient {
    <#
    .SYNOPSIS
        Factory function: creates a new OpsRampClient class instance from a config path.

    .PARAMETER ConfigPath
        Path to opsramp_config.json.

    .EXAMPLE
        $client = Invoke-OpsRampClient -ConfigPath 'configs\opsramp_config.json'
    #>
    [CmdletBinding()]
    [OutputType([OpsRamp_Client])]
    param(
        [Parameter(Mandatory, Position = 0)][string] $ConfigPath
    )
    return [OpsRamp_Client]::new($ConfigPath)
}

function Invoke-OpsRamp {
    <#
    .SYNOPSIS
        Quick CLI test of the OpsRamp API connection.

    .PARAMETER ConfigPath
        Path to opsramp_config.json.

    .EXAMPLE
        Invoke-OpsRamp -ConfigPath 'configs\opsramp_config.json'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([string]$ConfigPath = 'configs\opsramp_config.json')
    $client = [OpsRamp_Client]::new($ConfigPath)
    return $client.EnsureToken()
}
