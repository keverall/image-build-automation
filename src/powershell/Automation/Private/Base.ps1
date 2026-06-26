#
# Private/Base.ps1 - AutomationBase class helper functions.
#

function Get-UtcTimestamp {
    <#
    .SYNOPSIS
        Returns current UTC timestamp in ISO 8601 format.
    #>
    return [DateTime]::UtcNow.ToString('o')
}

function Get-LocalTimestamp {
    <#
    .SYNOPSIS
        Returns current local timezone timestamp in ISO 8601 format.
    #>
    return [DateTime]::Now.ToString('o')
}

function Get-UtcFileTimestamp {
    <#
    .SYNOPSIS
        Returns current UTC timestamp for file naming (yyyy-MM-ddTHH-mm-ssZ).
    #>
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ssZ')
}

function Get-UtcApiTimestamp {
    <#
    .SYNOPSIS
        Returns current UTC timestamp for SCOM REST API calls (yyyy-MM-ddTHH:mm:ss).
    #>
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss')
}

function Convert-ToUtcIso8601 {
    <#
    .SYNOPSIS
        Converts a DateTime to UTC ISO 8601 format string.
    .PARAMETER Date
        The DateTime value to convert. If $null, returns $null.
    .EXAMPLE
        $utcStr = Convert-ToUtcIso8601 $startDt
    #>
    param([DateTime] $Date)
    if ($null -eq $Date) { return $null }
    return $Date.ToUniversalTime().ToString('o')
}

function Get-LogTimestamp {
    <#
    .SYNOPSIS
        Returns current UTC timestamp in log format (yyyy-MM-dd HH:mm:ss).
    #>
    return [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')
}

function Get-FileTimestamp {
    <#
    .SYNOPSIS
        Returns current UTC timestamp for file naming (yyyyMMdd_HHmmss).
    #>
    return [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')
}

function Get-DateFileTimestamp {
    <#
    .SYNOPSIS
        Returns current UTC date for daily log file naming (yyyy-MM-dd).
    #>
    return [DateTime]::UtcNow.ToString('yyyy-MM-dd')
}

function New-AutomationBase {
    <#
    .SYNOPSIS
        Factory for AutomationBase (useful for classes that cannot inherit in PS without extra steps).

    .EXAMPLE
        $base = New-AutomationBase -ConfigDir 'configs' -OutputDir 'output'
    #>
    [CmdletBinding()]
    [OutputType([AutomationBase])]
    param(
        [string] $ConfigDir = 'configs',
        [string] $OutputDir = 'output',
        [bool]   $DryRun    = $false
    )
    return [AutomationBase]::new($ConfigDir, $OutputDir, $DryRun)
}
