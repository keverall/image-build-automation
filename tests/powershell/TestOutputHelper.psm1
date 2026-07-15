# TestOutputHelper.psm1
# Provides enhanced test output with colored formatting and detailed command information
# 
# Usage: Import-Module ./TestOutputHelper.psm1
#        Write-TestCommand -Command "Set-MaintenanceMode" -Params @{Action='enable'; TargetId='TEST'}
#        Write-TestResult -Success $true -Message "Maintenance enabled" -Details @{StartTime='2025-01-01'}

# ANSI color codes for terminal output
$Script:Colors = @{
    Reset   = "`e[0m"
    Red     = "`e[31m"
    Green   = "`e[32m"
    Yellow  = "`e[33m"
    Blue    = "`e[34m"
    Magenta = "`e[35m"  # Purple
    Cyan    = "`e[36m"
    White   = "`e[37m"
    Bold    = "`e[1m"
    Dim     = "`e[2m"
}

function Get-ColorSupport {
    # Check if terminal supports colors
    if ($env:NO_COLOR) { return $false }
    if ($env:TERM -eq 'dumb') { return $false }
    if ([System.Console]::IsOutputRedirected) { return $false }
    return $true
}

function Format-ParamsString {
    <#
    .SYNOPSIS
        Formats a hashtable of parameters into a readable string for test output.
    #>
    param(
        [hashtable]$Params,
        [string[]]$ExcludeKeys = @()
    )
    
    if (-not $Params -or $Params.Count -eq 0) { return "" }
    
    $parts = @()
    foreach ($key in $Params.Keys | Sort-Object) {
        if ($key -in $ExcludeKeys) { continue }
        $value = $Params[$key]
        if ($value -is [switch]) {
            if ($value.IsPresent) { $parts += "-$key" }
        } elseif ($value -is [bool]) {
            if ($value) { $parts += "-$key" }
        } elseif ($null -ne $value -and "$value" -ne "") {
            $displayValue = if ($value -is [array]) { "[$($value -join ', ')]" } else { "$value" }
            # Truncate long values
            if ($displayValue.Length -gt 50) { $displayValue = $displayValue.Substring(0, 47) + "..." }
            $parts += "-$key $displayValue"
        }
    }
    return ($parts -join " ")
}

function Write-TestCommand {
    <#
    .SYNOPSIS
        Writes the command being tested with its parameters in cyan/blue.
    #>
    param(
        [Parameter(Mandatory)][string]$Command,
        [hashtable]$Params = @{},
        [string]$Description = ""
    )
    
    $useColor = Get-ColorSupport
    $paramStr = Format-ParamsString -Params $Params
    
    $output = if ($Description) {
        "  CMD: $Command $paramStr ($Description)"
    } else {
        "  CMD: $Command $paramStr"
    }
    
    if ($useColor) {
        Write-Output "$($Script:Colors.Cyan)$output$($Script:Colors.Reset)"
    } else {
        Write-Output $output
    }
}

function Write-TestResponse {
    <#
    .SYNOPSIS
        Writes the response/result from a command execution.
        Purple for success, Red for failure/unexpected results.
    #>
    param(
        [Parameter(Mandatory)][bool]$Success,
        [Parameter(Mandatory)][bool]$ExpectedSuccess,
        [string]$Message = "",
        [hashtable]$Details = @{},
        [string]$ErrorDetail = ""
    )
    
    $useColor = Get-ColorSupport
    
    # Determine if this is an expected outcome
    $isExpected = ($Success -eq $ExpectedSuccess)
    
    # Choose color: Purple for expected success, Red for unexpected or expected failure
    $color = if ($isExpected -and $Success) {
        $Script:Colors.Magenta  # Purple for successful expected outcome
    } elseif (-not $isExpected) {
        $Script:Colors.Red      # Red for unexpected outcome (test anomaly)
    } else {
        $Script:Colors.Yellow   # Yellow for expected failure
    }
    
    $statusIcon = if ($isExpected) {
        if ($Success) { "[OK]" } else { "[EXPECTED FAIL]" }
    } else {
        "[UNEXPECTED]"
    }
    
    $lines = @()
    $lines += "  RESPONSE $statusIcon : $Message"
    
    # Add details if provided
    if ($Details -and $Details.Count -gt 0) {
        foreach ($key in ($Details.Keys | Sort-Object)) {
            $val = $Details[$key]
            if ($null -ne $val -and "$val" -ne "") {
                $lines += "           $key = $val"
            }
        }
    }
    
    if ($ErrorDetail) {
        $lines += "           Error: $ErrorDetail"
    }
    
    $output = $lines -join "`n"
    
    if ($useColor) {
        Write-Output "$color$output$($Script:Colors.Reset)"
    } else {
        Write-Output $output
    }
}

function Write-TestSection {
    <#
    .SYNOPSIS
        Writes a section header for grouping related tests.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Subtitle = ""
    )
    
    $useColor = Get-ColorSupport
    $separator = "=" * 70
    
    if ($useColor) {
        Write-Output "$($Script:Colors.Bold)$($Script:Colors.Blue)$separator$($Script:Colors.Reset)"
        Write-Output "$($Script:Colors.Bold)$($Script:Colors.Blue)  $Title$($Script:Colors.Reset)"
        if ($Subtitle) {
            Write-Output "$($Script:Colors.Dim)  $Subtitle$($Script:Colors.Reset)"
        }
        Write-Output "$($Script:Colors.Bold)$($Script:Colors.Blue)$separator$($Script:Colors.Reset)"
    } else {
        Write-Output $separator
        Write-Output "  $Title"
        if ($Subtitle) { Write-Output "  $Subtitle" }
        Write-Output $separator
    }
}

function Format-TestDescription {
    <#
    .SYNOPSIS
        Creates a descriptive test name that includes key parameters.
    #>
    param(
        [Parameter(Mandatory)][string]$BaseDescription,
        [hashtable]$Params = @{},
        [string[]]$KeyParams = @()
    )
    
    if ($KeyParams.Count -eq 0 -or $Params.Count -eq 0) {
        return $BaseDescription
    }
    
    $paramParts = @()
    foreach ($kp in $KeyParams) {
        if ($Params.ContainsKey($kp)) {
            $val = $Params[$kp]
            if ($null -ne $val) {
                $paramParts += "${kp}=${val}"
            }
        }
    }
    
    if ($paramParts.Count -gt 0) {
        return "$BaseDescription [$($paramParts -join ', ')]"
    }
    return $BaseDescription
}

function Write-MaintenanceResult {
    <#
    .SYNOPSIS
        Specialized output for Set-MaintenanceMode results with detailed information.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Result,
        [Parameter(Mandatory)][hashtable]$InputParams,
        [bool]$ExpectedSuccess = $true
    )
    
    $success = $Result.Success
    $message = $Result.Message
    $startTime = $Result.StartTimeUtc
    $endTime = $Result.EndTimeUtc
    $error = $Result.Error
    
    $details = @{}
    if ($startTime) { $details['StartTimeUtc'] = $startTime }
    if ($endTime) { $details['EndTimeUtc'] = $endTime }
    if ($InputParams.ContainsKey('TargetId')) { $details['Cluster'] = $InputParams['TargetId'] }
    if ($InputParams.ContainsKey('Action')) { $details['Action'] = $InputParams['Action'] }
    if ($InputParams.ContainsKey('DryRun') -and $InputParams['DryRun']) { $details['Mode'] = 'DRY-RUN' }
    
    Write-TestResponse -Success $success -ExpectedSuccess $ExpectedSuccess `
        -Message $message -Details $details -ErrorDetail $error
}

# Export functions
Export-ModuleMember -Function @(
    'Write-TestCommand',
    'Write-TestResponse', 
    'Write-TestSection',
    'Format-TestDescription',
    'Write-MaintenanceResult',
    'Format-ParamsString',
    'Get-ColorSupport'
)
