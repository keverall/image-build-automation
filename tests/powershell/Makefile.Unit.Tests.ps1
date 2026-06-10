Describe 'Makefile Targets' {
    BeforeAll {
        $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    It 'make help should execute without errors' {
        Set-Location $projectRoot
        $output = & make help 2>&1
        $exitCode = $LASTEXITCODE
        $outputString = $output -join "`n"
        
        if ($exitCode -ne 0) {
            Write-Host "Make output: $outputString"
        }
        
        $exitCode | Should -Be 0
        $outputString | Should -Match 'Available Commands'
    }
}
