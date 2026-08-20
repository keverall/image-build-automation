# OneViewAliasInventory.Unit.Tests.ps1
# Table-driven sweep: every documented custom alias on the OneView/Server commands
# must be present in the command's parameter metadata. Catches doc/code drift
# (e.g. the historical inversion of ServerIdentifier/SrvrId) automatically.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 6.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # command -> ( parameter -> expected alias )
    $Script:AliasMap = @{
        'Connect-OneView'              = @{ OneViewHost = 'OVHost'; DryRun = 'Dry'; PassThru = 'PT' }
        'Get-OneViewConnectionStatus'  = @{ OneViewHost = 'OVHost'; ServerIdentifier = 'SrvrId'; IdentifierType = 'IdTyp'; Credential = 'Cred'; OneViewUser = 'OVUser'; OneViewPassword = 'OVPwd'; SkipCertificateCheck = 'SkipCert'; TimeoutSec = 'Timeout'; IncludeServerCount = 'SrvrCount'; MockResult = 'Mock'; DryRun = 'Dry'; PassThru = 'PT' }
        'Get-OneViewServerList'        = @{ OneViewHost = 'OVHost'; Credential = 'Cred'; OneViewUser = 'OVUser'; OneViewPassword = 'OVPwd'; SkipCertificateCheck = 'SkipCert'; TimeoutSec = 'Timeout'; PageSize = 'Page'; MockResult = 'Mock'; DryRun = 'Dry'; PassThru = 'PT' }
        'Get-OneViewServerTarget'      = @{ OneViewHost = 'OVHost'; ServerIdentifier = 'SrvrId'; IdentifierType = 'IdTyp'; Credential = 'Cred'; OneViewUser = 'OVUser'; OneViewPassword = 'OVPwd'; SkipCertificateCheck = 'SkipCert'; TimeoutSec = 'Timeout'; MockResult = 'Mock'; DryRun = 'Dry'; PassThru = 'PT' }
        'Get-OneViewVersion'           = @{ OneViewHost = 'OVHost'; DryRun = 'Dry'; Quiet = 'Q'; SkipCertificateCheck = 'SkipCert'; TimeoutSec = 'Timeout' }
        'New-OneViewMaintenanceScript' = @{ Appliance = 'Appl'; Operation = 'Op'; ScopeName = 'Scope' }
        'Start-PhysicalServerBuild'    = @{ OneViewHost = 'OVHost'; ServerIdentifier = 'SrvrId'; IloIp = 'Ilo'; ExternalIsoPath = 'ExtIso'; DryRun = 'Dry'; SkipConfirmation = 'SkipConf' }
        'Test-ServerConnectivity'      = @{ OneViewHost = 'OVHost'; ConfigDir = 'CfgDir'; Credential = 'Cred'; DryRun = 'Dry'; Environment = 'Env'; JsonConfig = 'JsonCfg'; PassThru = 'PT'; PingTimeoutMs = 'PingMs' }
    }
}

Describe 'OneView command alias inventory' {
    foreach ($cmdName in $Script:AliasMap.Keys) {
        It "Command '$cmdName' exposes all documented aliases" {
            $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
            $cmd | Should -Not -Be $null
            foreach ($param in $Script:AliasMap[$cmdName].Keys) {
                $cmd.Parameters.ContainsKey($param) | Should -Be $true
                $cmd.Parameters[$param].Aliases -contains $Script:AliasMap[$cmdName][$param] | Should -Be $true
            }
        }
    }
}
