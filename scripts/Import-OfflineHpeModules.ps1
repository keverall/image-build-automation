<#
.SYNOPSIS
    Loads the approved local HPE modules without reimporting an active module.
.DESCRIPTION
    Reuses a matching loaded module and preserves existing OneView connections.
    Conflicting module versions and residual HPREST types require a fresh shell;
    this script never unloads modules, removes types, deletes files, downloads
    dependencies, or bypasses HPE's license script.
.EXAMPLE
    .\scripts\Import-OfflineHpeModules.ps1
.EXAMPLE
    .\scripts\Import-OfflineHpeModules.ps1 -Name HPEOneView.1000
#>
[CmdletBinding()]
param(
    [ValidateSet('HPEOneView.1000', 'HPRESTCmdlets')]
    [string[]]$Name = @('HPEOneView.1000', 'HPRESTCmdlets')
)

function Test-HprestImportResidue {
    [CmdletBinding()]
    param()
    return ($null -ne ('AsyncPipeline' -as [type]))
}

function Import-OfflineHpeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][version]$ExpectedVersion,
        [Parameter(Mandatory)][string[]]$RequiredCommands
    )

    $metadata = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
    if ([version]$metadata.ModuleVersion -ne $ExpectedVersion) {
        throw "Local $ModuleName manifest does not match approved version $ExpectedVersion. Files were preserved."
    }

    $modulePattern = if ($ModuleName -like 'HPEOneView.*') { 'HPEOneView.*' } else { $ModuleName }
    $loadedModules = @(Get-Module -Name $modulePattern | Where-Object { $_ })
    $conflicts = @($loadedModules | Where-Object {
        $_.Name -ne $ModuleName -or $_.Version -ne $ExpectedVersion -or $_.Guid -ne [guid]$metadata.GUID
    })
    if ($conflicts.Count -gt 0) {
        throw "A different HPE module version or identity is already loaded. Open a fresh 'pwsh -NoProfile' shell and run scripts/Import-OfflineHpeModules.ps1. Existing modules and sessions were left untouched."
    }

    if ($loadedModules.Count -eq 0) {
        if ($ModuleName -eq 'HPRESTCmdlets' -and (Test-HprestImportResidue)) {
            throw "HPRESTCmdlets is not loaded, but its AsyncPipeline type remains from an earlier import. .NET types cannot be unloaded with Remove-Module. Open a fresh 'pwsh -NoProfile' shell and run scripts/Import-OfflineHpeModules.ps1 once. No files were changed and the license script was not bypassed."
        }
        try {
            Import-Module -Name $ManifestPath -Global -ErrorAction Stop
        } catch {
            throw "Unable to import local $ModuleName from '$ManifestPath'. Files were preserved. After a previous failed HPE import, start a fresh 'pwsh -NoProfile' shell rather than forcing a reload. Original error: $($_.Exception.Message)"
        }
    }

    foreach ($commandName in $RequiredCommands) {
        $command = Get-Command -Name $commandName -Module $ModuleName -ErrorAction SilentlyContinue
        if (-not $command) {
            throw "$ModuleName is loaded but '$commandName' is unavailable. Start a fresh 'pwsh -NoProfile' shell and retry the approved local importer; do not force a reload or delete the package."
        }
    }
    Write-Verbose "$ModuleName $ExpectedVersion is available; an existing matching module was reused when present."
}

$moduleRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/modules'
foreach ($moduleName in $Name) {
    $version = if ($moduleName -eq 'HPEOneView.1000') { '10.0.4265.2221' } else { '1.2.0.0' }
    $commands = if ($moduleName -eq 'HPEOneView.1000') { @('Get-OVServer', 'Get-OVIloSso') } else { @('Connect-HPREST', 'Get-HPRESTDataRaw') }
    $manifest = Join-Path $moduleRoot "$moduleName/$version/$moduleName.psd1"
    Import-OfflineHpeModule -ModuleName $moduleName -ManifestPath $manifest -ExpectedVersion $version -RequiredCommands $commands
}
