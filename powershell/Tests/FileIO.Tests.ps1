# FileIO.Tests.ps1 — Tests for FileIO.psm1
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
    $Script:TestDir = Join-Path $Script:TempDir 'fileio'
    New-Item -ItemType Directory -Path $Script:TestDir -Force | Out-Null
}

Describe 'Ensure-DirectoryExists' {
    It 'Returns the given path' {
        $p = Join-Path $Script:TestDir 'subdir'
        $r = Ensure-DirectoryExists -Path $p
        $r | Should -Be $p
    }

    It 'Does not throw when directory already exists' {
        $p = Join-Path $Script:TestDir 'subdir'
        { Ensure-DirectoryExists -Path $p } | Should -Not -Throw
    }
}

Describe 'Save-Json / Load-Json' {
    It 'Saves and loads a hashtable round-trip' {
        $data = @{ hello='world'; number=42; nested=@{ a=1; b=@(2,3) } }
        $f    = Join-Path $Script:TestDir 'roundtrip.json'
        Save-Json -Data $data -Path $f
        $loaded = Load-Json -Path $f
        $loaded['hello']   | Should -Be 'world'
        $loaded['number']  | Should -Be 42
    }

    It 'Throws for missing required file' {
        { Load-Json -Path 'C:\nonexistent_file_xyz.json' -Required:$true } | Should -Throw
    }

    It 'Returns empty hashtable for missing non-required file' {
        $r = Load-Json -Path 'C:\nonexistent_file_xyz.json' -Required:$false
        $r.Count | Should -Be 0
    }
}

Describe 'Save-JsonResult' {
    It 'Creates a timestamped file in the right directory' {
        $r = Save-JsonResult -Data @{ ok=$true } -BaseName 'test_result' -OutputDir $Script:TestDir
        Split-Path $r -Leaf | Should -Match '^test_result_\d+\.json$'
        Test-Path $r | Should -Be $true
    }

    It 'Places file under category sub-directory when given' {
        $r = Save-JsonResult -Data @{ ok=$true } -BaseName 'cat_test' -OutputDir $Script:TestDir -Category 'sub'
        $r | Should -Match 'sub\\\\cat_test_\d+\.json$'
    }
}

Describe 'Test-PathEx' {
    It 'Returns $true for an existing file' {
        $f = Join-Path $Script:TestDir 'dummy.txt'
        'dummy' | Set-Content $f
        Test-PathEx -Path $f | Should -Be $true
    }

    It 'Returns $false for a non-existent file' {
        Test-PathEx -Path 'C:\nonexistent_xyz.txt' | Should -Be $false
    }

    It 'Returns $true for an existing directory with PathType=Container' {
        Test-PathEx -Path $Script:TestDir -PathType 'Container' | Should -Be $true
    }
}
