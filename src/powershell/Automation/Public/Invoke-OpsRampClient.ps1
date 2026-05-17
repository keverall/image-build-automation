#
# Public/Invoke-OpsRampClient.ps1 — OpsRamp client factory + CLI test helper.
#

function Invoke-OpsRampClient {
    <#
    .SYNOPSIS
        Factory function: creates a new OpsRampClient class instance from a config path.

    .DESCRIPTION
        Instantiates the OpsRamp_Client class which provides methods for sending
        metrics, alerts, and events to the OpsRamp monitoring platform. Use this
        to obtain a client object for programmatic OpsRamp integrations.

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

    .DESCRIPTION
        Convenience function to test OpsRamp API connectivity by obtaining an
        authentication token. Useful for verifying credentials and network
        access before running full integrations.

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
