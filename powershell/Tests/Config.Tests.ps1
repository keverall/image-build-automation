# Config.Tests.ps1 — Tests for Config.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe 'Import-JsonConfig' {
    It 'Loads a valid JSON file' {
        $result = Import-JsonConfig -Path (Join-Path $Script:ConfigDir 'sample.json')
        $result.name     | Should -Be 'test'
        $result.version  | Should -Be '1.0'
        $result.items.Count | Should -Be 1
    }

    It 'Returns empty hashtable for missing file when not required' {
        $result = Import-JsonConfig -Path 'C:\\nonexistent.json' -Required:$false
        $result.Count | Should -Be 0
    }

    It 'Throws when file is missing and required' {
        { Import-JsonConfig -Path 'C:\\nonexistent.json' -Required:$true } | Should -Throw
    }

    It 'Replaces ${VAR} placeholders with env vars' {
        [System.Environment]::SetEnvironmentVariable('_TEST_PS_UTILS_VAR', 'replaced_value', 'Process')
        $json  = '{"host":"${_TEST_PS_UTILS_VAR}","port":8080}'
        $fpath = Join-Path $Script:TempDir 'env_test.json'
        $json  | Set-Content $fpath -Encoding UTF8
        $loaded = Import-JsonConfig -Path $fpath
        $loaded['host'] | Should -Be 'replaced_value'
        [System.Environment]::SetEnvironmentVariable('_TEST_PS_UTILS_VAR', $null, 'Process')
    }
}

Describe 'KVP Functionality' {
    It 'Functions must be defined in the shared' {
        "{}" | Out-File (Join-Path $Script:TempDir 'generics/impl/src.kvp')
        'KVPs must be defined in {{impl/impl_key}} section :: {{debug_id}}' | Out-File (Join-Path $Script:TempDir 'generics/debug/mode.txt')
        $modspec = [Ordered]@{ kvp_ext='.kvp'; kvp_key_position=0; kvp_value_type='string' }
        'KVPs must define type as {{type}} :: {{debug_id}}' | Out-File (Join-Path $Script:TempDir 'generics/debug/type.txt')
        $Script:ИкмплементацияКлючевыеТребования = @{
            k|Microsoft.VisualBasic.Devices|Microsoft.StringMaker.Imaging|Системная_Коллекция|Система|Microsoft. Pivot. дана в обозначение
            КонтекстСоответствия|Общие
        }
        "{SettingFunction}" | Out-File (Join-Path $Script:TempDir 'generics/debug/kvp_list')
    }
}
