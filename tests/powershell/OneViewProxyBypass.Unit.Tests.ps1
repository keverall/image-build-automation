#
# OneViewProxyBypass.Unit.Tests.ps1 - Tests for Set-OneViewProxyBypass.
#
# Validates that internal OneView appliances are reached directly (bypassing the
# corporate web proxy) by adding the host (and its resolved FQDN / IP addresses)
# to the .NET WebRequest proxy bypass list and to the no_proxy / NO_PROXY
# environment variables. Because the bypass is process-wide, the session
# established by Test-ServerConnectivity (and any later Get-OneViewServerList or
# manual Connect-OVMgmt in the same PowerShell session) also benefits.
#
# Set-OneViewProxyBypass is a private module function, so it is exercised via
# InModuleScope. Process-wide proxy / env state is preserved and restored.

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop

    # Preserve process-wide state so we do not leak into other test files.
    $Script:OrigProxy        = [System.Net.WebRequest]::DefaultWebProxy
    $Script:OrigNoProxy      = [System.Environment]::GetEnvironmentVariable('no_proxy')
    $Script:OrigNoProxyUpper = [System.Environment]::GetEnvironmentVariable('NO_PROXY')
}

AfterAll {
    [System.Net.WebRequest]::DefaultWebProxy = $Script:OrigProxy
    [System.Environment]::SetEnvironmentVariable('no_proxy', $Script:OrigNoProxy)
    [System.Environment]::SetEnvironmentVariable('NO_PROXY', $Script:OrigNoProxyUpper)
}

Describe 'Set-OneViewProxyBypass - WebRequest proxy bypass list' {

    BeforeEach {
        $proxy = New-Object System.Net.WebProxy('http://webcorp.prd.aib.pri:8082')
        $proxy.BypassProxyOnLocal = $false
        $proxy.BypassList = @('192\.168\.\d{1,3}\.\d{1,3}')
        [System.Net.WebRequest]::DefaultWebProxy = $proxy
    }

    It 'Adds the appliance host to the WebRequest proxy bypass list' {
        InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01' }
        $list = [System.Net.WebRequest]::DefaultWebProxy.BypassList -join ','
        $list | Should -Match 'va-oneviewt-01'
    }

    It 'Preserves existing bypass entries while adding the host' {
        InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01' }
        $list = [System.Net.WebRequest]::DefaultWebProxy.BypassList -join ','
        $list | Should -Match '192\\?\.168'   # pre-existing entry retained (literal backslash in the regex pattern)
        $list | Should -Match 'va-oneviewt-01'
    }

    It 'Resolves and adds the FQDN and IP addresses (localhost resolves)' {
        InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'localhost' }
        $list = [System.Net.WebRequest]::DefaultWebProxy.BypassList
        $list -contains 'localhost' | Should -Be $true          # raw host always added
        # The function adds every address localhost resolves to (IPv4 and/or IPv6);
        # assert each actually-resolved address is present rather than assuming a
        # specific address family, so the test passes on IPv6-only hosts too.
        $addrs = ([System.Net.Dns]::GetHostEntry('localhost')).AddressList
        $addrs.Count | Should -BeGreaterThan 0
        foreach ($addr in $addrs) {
            $list -contains $addr.IPAddressToString | Should -Be $true
        }
    }

    It 'Is idempotent - re-applying does not duplicate the host' {
        InModuleScope Automation {
            Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01'
            Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01'
        }
        $count = ([System.Net.WebRequest]::DefaultWebProxy.BypassList | Where-Object { $_ -eq 'va-oneviewt-01' }).Count
        $count | Should -Be 1
    }
}

Describe 'Set-OneViewProxyBypass - no_proxy environment variable' {

    BeforeEach {
        [System.Environment]::SetEnvironmentVariable('no_proxy', 'existing.internal')
        [System.Environment]::SetEnvironmentVariable('NO_PROXY', 'existing.internal')
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy('http://proxy:8082')
    }

    It 'Appends the host to both no_proxy and NO_PROXY' {
        InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01' }
        [System.Environment]::GetEnvironmentVariable('no_proxy') | Should -Match 'va-oneviewt-01'
        [System.Environment]::GetEnvironmentVariable('NO_PROXY') | Should -Match 'va-oneviewt-01'
    }

    It 'Does not duplicate an already-present host in no_proxy' {
        [System.Environment]::SetEnvironmentVariable('no_proxy', 'va-oneviewt-01')
        InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01' }
        $np = [System.Environment]::GetEnvironmentVariable('no_proxy') -split ','
        ($np | Where-Object { $_ -eq 'va-oneviewt-01' }).Count | Should -Be 1
    }
}

Describe 'Set-OneViewProxyBypass - graceful handling' {

    It 'Does not throw and still adds the raw host when DNS resolution fails' {
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy('http://proxy:8082')
        { InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'nonexistent.invalid.test' } } | Should -Not -Throw
        [System.Net.WebRequest]::DefaultWebProxy.BypassList -join ',' | Should -Match 'nonexistent.invalid.test'
    }

    It 'Does not throw when no proxy is configured (DefaultWebProxy is null)' {
        [System.Net.WebRequest]::DefaultWebProxy = $null
        { InModuleScope Automation { Set-OneViewProxyBypass -ApplianceHost 'va-oneviewt-01' } } | Should -Not -Throw
    }
}

Describe 'Test-ServerConnectivity is wired to the proxy bypass' {

    It 'Calls Set-OneViewProxyBypass for the appliance host (source wiring)' {
        $path = Join-Path $Script:ModuleRoot 'Automation\Public\Test-ServerConnectivity.ps1'
        $content = Get-Content -Path $path -Raw
        $content | Should -Match 'Set-OneViewProxyBypass'
    }
}
