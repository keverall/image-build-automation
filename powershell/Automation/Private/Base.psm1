#
# Base.psm1 — AutomationBase class helper functions.
# NOTE: AutomationBase CLASS is defined here; it references AuditLogger and
#       CommandResult which are already loaded by Automation.psm1 (root module).
#

class AutomationBase {
    <#
    .SYNOPSIS
        Base class providing shared config loading, logging and audit support.
    #>
    [string]      $ConfigDir
    [string]      $OutputDir
    [bool]        $DryRun
    [object]      $Logger        # TraceSource or $null
    [AuditLogger] $Audit

    AutomationBase([string]$ConfigDir, [string]$OutputDir, [bool]$DryRun) {
        $this.ConfigDir = $ConfigDir
        $this.OutputDir = $OutputDir
        $this.DryRun    = $DryRun

        Ensure-DirectoryExists -Path $OutputDir
        $logDir = Join-Path ([System.IO.Path]::GetFullPath('.')) 'logs'
        Ensure-DirectoryExists -Path $logDir

        $this.Logger = $null   # lightweight – use Write-Host/Verbose
        $this.Audit  = [AuditLogger]::new($this.GetType().Name.ToLower(), $logDir, 'audit.log')
        $this.Audit.Log('initialization', 'INFO',
            '', "ConfigDir=$ConfigDir OutputDir=$OutputDir DryRun=$DryRun", $null)
    }

    [hashtable] LoadConfig([string]$FileName, [bool]$Required) {
        $path = [System.IO.Path]::Combine($this.ConfigDir, $FileName)
        return Import-JsonConfig -Path $path -Required $Required
    }

    [object[]] LoadServers([string]$FileName) {
        $path = [System.IO.Path]::Combine($this.ConfigDir, $FileName)
        return Load-ServerList -Path $path -IncludeDetails
    }

    [string] SaveResult([hashtable]$Data, [string]$BaseName, [string]$Category) {
        return Save-JsonResult -Data $Data -BaseName $BaseName -OutputDir $this.OutputDir -Category $Category
    }

    [void] LogAndAudit([string]$Action, [string]$Status, [string]$Server, [string]$Details) {
        Write-Host "[$Status] $Action | $Server | $Details"
        $this.Audit.Log($Action, $Status, $Server, $Details, $null)
    }

    [string] SaveAudit([string]$Filename) {
        $fp = $this.Audit.Save($Filename)
        $this.Audit.AppendToMaster()
        return $fp
    }

    [CommandResult] RunCommand([string[]]$CmdArgs) {
        return Invoke-NativeCommand -Command $CmdArgs
    }
}

function New-AutomationBase {
    <#
    .SYNOPSIS
        Factory for AutomationBase (useful for classes that cannot inherit in PS without extra steps).
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

# vim: ts=4 sw=4 et
