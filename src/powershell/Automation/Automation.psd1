#
# Module manifest for module 'Automation'
#
# Source project : HPE ProLiant Windows Server ISO Automation
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'Automation.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = 'b3d1e2a4-5c6f-4e8a-9b0c-1d2e3f4a5b6c'

    # Author of this module
    Author = 'Kev Everall'

    # Company or vendor of this module
    CompanyName = 'HPE Automation'

    # Copyright statement for this module
    Copyright = '(c) 2026 Kev Everall. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'HPE ProLiant Windows Server ISO Automation - PowerShell module for maintenance mode orchestration, ISO build, firmware updates, security patching, deployment, and monitoring.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of the .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NOTE: Classes are defined in Automation.psm1 (root) to ensure type visibility.
    #       All Private/*.psm1 and Public/*.psm1 files are dot-sourced by Automation.psm1.
    NestedModules = @()

    # Functions to export from this module — explicit public API surface.
    # '_'-prefixed names are private helpers dot-sourced by other scripts.
    FunctionsToExport = @(
        # ── Orchestrator ────────────────────────────────────────────────────────
        'Start-AutomationOrchestrator'
        # ── Control ─────────────────────────────────────────────────────────────
        'New-CIPipelineCtrl'
        'New-IRequestCtrl'
        'New-SchedulerCtrl'
        'New-GitLabCtrl'
        'Run-CIPipeline'
        'Run-IRequest'
        'Run-Scheduler'
        'Run-GitLab'
        # ── Entry-point handlers invoked by Invoke-RoutedRequest ────────────────
        'Invoke-IsoDeploy'
        'Invoke-WindowsSecurityUpdate'
        'New-IsoBuild'
        'Set-MaintenanceMode'
        'Start-InstallMonitor'
        'New-Uuid'
        'Update-Firmware'
        # OpsRamp API client
        'Invoke-OpsRamp'
        'Invoke-OpsRampClient'
        # ── PowerShell execution ────────────────────────────────────────────────
        'Invoke-PowerShellScript'
        'Invoke-PowerShellWinRM'
        'New-ScomConnection'
        'New-ScomMaintenanceScript'
        'New-OneViewMaintenanceScript'
        # ── Validators ──────────────────────────────────────────────────────────
        'Test-BuildParams'
        'Test-ClusterId'
        'Test-ServerList'
        # ── Config / credential helpers ─────────────────────────────────────────
        'Import-JsonConfig'
        'Import-YamlConfig'
        'Get-EnvCredential'
        'Get-IloCredentials'
        'Get-OpenViewCredentials'
        'Get-OneViewCredentials'
        'Get-ScomCredentials'
        'Get-SmtpCredentials'
        # ── Process execution ───────────────────────────────────────────────────
        'Invoke-NativeCommand'
        'Invoke-NativeCommandWithRetry'
        'New-CommandResult'
        # ── File I/O ────────────────────────────────────────────────────────────
        'Ensure-DirectoryExists'
        'Load-Json'
        'Save-Json'
        'Save-JsonResult'
        'Test-PathEx'
        # ── Inventory ───────────────────────────────────────────────────────────
        'Load-ClusterCatalogue'
        'Load-ServerList'
        'New-ServerInfo'
        'Test-ClusterDefinition'
        # ── Logging / audit / timestamps ────────────────────────────────────────
        'Get-Logger'
        'Get-LocalTimestamp'
        'Get-ProjectRoot'
        'Get-UtcApiTimestamp'
        'Get-UtcFileTimestamp'
        'Get-UtcTimestamp'
        'Initialize-Logging'
        'Convert-ToUtcIso8601'
        # ── Routing ─────────────────────────────────────────────────────────────
        'Invoke-RoutedRequest'
        # ── Introspection ─────────────────────────────────────────────────────────
        'Get-RouteMap'
        # ── Base / factories ────────────────────────────────────────────────────
        'New-AutomationBase'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @('LogDir')

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('HPE', 'Automation', 'Maintenance', 'Deployment')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/example/automation'
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module.
    # Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
