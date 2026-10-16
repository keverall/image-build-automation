BeforeAll {
    $script:packageRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts/modules/PSRedfish/0.1.4'
    $script:manifest = Join-Path $script:packageRoot 'PSRedfish.psd1'
}

Describe 'PSRedfish 0.1.4 vendored package' {
    It 'contains the manifest, root module, and help files' {
        Test-Path -LiteralPath $script:manifest | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:packageRoot 'PSRedfish.psm1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:packageRoot 'en-US/PSRedfish/PSRedfish-Help.xml') | Should -BeTrue
    }

    It 'imports and exports the session request commands' {
        Import-Module $script:manifest -Force -ErrorAction Stop
        (Get-Command -Module PSRedfish).Name | Should -Contain 'New-RedfishSession'
        (Get-Command -Module PSRedfish).Name | Should -Contain 'Invoke-RedfishRequest'
        (Get-Command -Module PSRedfish).Name | Should -Contain 'Remove-RedfishSession'
    }
}
