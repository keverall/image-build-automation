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

    .PARAMETER Json
        Emit the result as a JSON string on the success stream instead of the
        human-readable report.

    .PARAMETER PassThru
        Also return the structured [hashtable] result on the success stream. By
        default the command writes only the human-readable report and returns
        nothing, so the terminal/log never receives a truncated hashtable dump.
        Capture the result into a variable, e.g.
        `$r = Disconnect-OneView -PassThru`, for scripting.

    .PARAMETER Quiet
        Suppress the human-readable report (use with -PassThru / -Json when the
        caller handles display itself).

    .EXAMPLE
        Disconnect-OneView

        Disconnect from the current OneView session.

    .EXAMPLE
        Disconnect-OneView -Force

        Force disconnection, suppressing any cleanup errors.

    .OUTPUTS
        By default, nothing is returned on the success stream (the
        human-readable report is written to the host). With -PassThru, a
        [hashtable] with keys Success, Message, Timestamp. With -Json, a JSON
        [string] representation of the same data.

    .NOTES
        This command is the counterpart to Connect-OneView (and the underlying
        Test-ServerConnectivity), which establishes the persistent OneView
        session. The session is also automatically closed when the PowerShell
        session ends.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch] $Force,
        [switch] $Json,
        [Alias('PT')]
        [switch] $PassThru,
        [switch] $Quiet
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
            return (_Publish-Result -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
        }

        # Disconnect using the HPE OneView module
        if ($Force) {
            Disconnect-OVMgmt -ErrorAction SilentlyContinue
        } else {
            Disconnect-OVMgmt -ErrorAction Stop
        }

        $result.Success = $true
        $result.Message = "Successfully disconnected from OneView appliance."
        $script:ActiveOneViewSession = $null
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

    return (_Publish-Result -Result $result -Json:$Json -PassThru:$PassThru -Quiet:$Quiet)
}
