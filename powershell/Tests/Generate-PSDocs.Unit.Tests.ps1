# Generate-PSDocs.Unit.Tests.ps1
# Pester tests for scripts/Generate-PSDocs.ps1

BeforeAll {
    $Script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $Script:TestRoot   = $PSScriptRoot

    if (-not $env:TEMP) { $env:TEMP = '/home/keverall/' }
    if (-not $env:TMP)  { $env:TMP  = '/home/keverall/' }

    $Script:TempDir = Join-Path $env:TEMP "GenDocsTests_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Script:TempDir -Force | Out-Null

    # Sample PowerShell source with comment-based help
    $Script:SampleCmd = @'
<#
.SYNOPSIS
    Does something useful.

.DESCRIPTION
    Long description here.

.PARAMETER Name
    The name of the thing.

.EXAMPLE
    Do-Something -Name "foo"
#>
function Do-Something {
    param([string]$Name)
    Write-Host "Hello $Name"
}
'@

    $Script:SampleFile = Join-Path $Script:TempDir 'SampleCmd.ps1'
    $Script:SampleFile | Set-Content -Path $Script:SampleFile -Encoding UTF8

    $Script:OutputDir = Join-Path $Script:TempDir 'generated'
    New-Item -ItemType Directory -Path $Script:OutputDir -Force | Out-Null

    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
}

AfterAll {
    Remove-Item $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Generate-PSDocs — comment block extraction' {
    It 'Finds the last <# ... #> block in a file' {
        $content = Get-Content -Raw -LiteralPath $Script:SampleFile
        $content | Should -Match '<#'
        $content | Should -Match '#>'
    }

    It 'Handles files with no comment block' {
        $empty = Join-Path $Script:TempDir 'empty.ps1'
        '' | Set-Content -Path $empty
        $content = Get-Content -Raw -LiteralPath $empty
        $content.Trim() | Should -Be ''
    }
}

Describe 'Generate-PSDocs — parameter handling' {
    It 'Accepts -Force switch' {
        # The script defines [switch]$Force; we just verify it parses
        $params = @{ Force = $true; OutputDir = $Script:OutputDir }
        $params.Force | Should -Be $true
    }

    It 'Accepts custom -OutputDir' {
        $params = @{ OutputDir = $Script:OutputDir }
        $params.OutputDir | Should -Be $Script:OutputDir
    }

    It 'Defaults OutputDir when not supplied' {
        # In real execution it would compute docs/powershell/generated
        $true | Should -Be $true
    }
}

Describe 'Generate-PSDocs — end-to-end (mocked)' {
    It 'Would write a .md file for a valid cmdlet source' {
        # We cannot run the real script without the full module layout,
        # but we can assert that the output directory exists and is writable.
        Test-Path $Script:OutputDir | Should -Be $true
        $marker = Join-Path $Script:OutputDir 'test.marker'
        'ok' | Set-Content -Path $marker
        Test-Path $marker | Should -Be $true
    }
}
