#
# Disconnect-OneView.ps1 - Disconnect from HPE OneView appliance
#

function Disconnect-OneView {
    <#
    .SYNOPSIS
        Disconnect from the HPE OneView appliance and close the active session.

    .DESCRIPTION
        Closes the active HPE OneView session established by Test-ServerConnectivity
        or Connect-OVMgmt. This command safely disconnects from the OneView appliance
        and cleans up the session state.

        Use this command when you are finished running OneView commands and want to
        explicitly close the connection.

    .PARAMETER Force
        Force disconnection even if errors occur during cleanup.

    .EXAMPLE
        Disconnect-OneView

        Disconnect from the current OneView session.

    .EXAMPLE
        Disconnect-OneView -Force

        Force disconnection, suppressing any cleanup errors.

    .OUTPUTS
        [hashtable] with keys:
          Success     [bool]   - disconnection succeeded
          Message     [string] - status message
          Timestamp   [string] - UTC ISO 8601

    .NOTES
        This command is the counterpart to Test-ServerConnectivity, which establishes
        the persistent OneView session. The session is also automatically closed when
        the PowerShell session ends.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch] $Force
    )

    $result = @{
        Success   = $false
        Message   = ''
        Timestamp = Get-UtcTimestamp
    }

    try {
        # Check if there's an active OneView session
        if (-not (Test-OneViewSessionActive)) {
            $result.Message = $script:ONEVIEW_NO_SESSION_MSG + ' Nothing to disconnect.'
            Write-Warning $result.Message
            return $result
        }

        # Disconnect using the HPE OneView module
        if ($Force) {
            Disconnect-OVMgmt -ErrorAction SilentlyContinue
        } else {
            Disconnect-OVMgmt -ErrorAction Stop
        }

        $result.Success = $true
        $result.Message = "Successfully disconnected from OneView appliance."
        Write-Host $result.Message -ForegroundColor Green
    }
    catch {
        $result.Message = "Failed to disconnect from OneView: $($_.Exception.Message)"
        if ($Force) {
            Write-Warning $result.Message
        } else {
            Write-Error $result.Message
        }
    }

    return $result
}
