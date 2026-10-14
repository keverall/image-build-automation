# Regression coverage for complete offline packages and sensitive-data exclusions.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:IgnoreFixture = Join-Path $TestDrive 'ignore-fixture'
    New-Item -ItemType Directory -Path $script:IgnoreFixture -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:RepoRoot '.gitignore') -Destination $script:IgnoreFixture
    $script:GitExecutable = (Get-Command git -ErrorAction Stop).Source
    & $script:GitExecutable -C $script:IgnoreFixture init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize isolated Git ignore fixture.' }

    function Test-FixtureIgnored {
        param([Parameter(Mandatory)][string] $RelativePath)
        & $script:GitExecutable -C $script:IgnoreFixture check-ignore --no-index --quiet -- $RelativePath
        $code = $LASTEXITCODE
        if ($code -notin @(0, 1)) { throw "Git ignore check failed for '$RelativePath' (exit $code)." }
        return ($code -eq 0)
    }
}

Describe 'Git ignore policy for offline PowerShell delivery' {
    It 'allows approved package content: <Path>' -ForEach @(
        @{ Path = 'scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTCmdlets.psd1' }
        @{ Path = 'scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTCmdlets.psm1' }
        @{ Path = 'scripts/modules/HPRESTCmdlets/1.2.0.0/HPRESTCmdletsLicense.rtf' }
        @{ Path = 'scripts/modules/HPRESTCmdlets/1.2.0.0/lib/dependency.dll' }
        @{ Path = 'scripts/modules/HPEOneView.1000/10.0.4265.2221/HPEOneView.1000.psd1' }
        @{ Path = 'scripts/modules/HPEOneView.1000/10.0.4265.2221/lib/HPEOneView_Classes.dll' }
        @{ Path = 'scripts/modules/HPEOneView.1000/10.0.4265.2221/Appliance.format.ps1xml' }
        @{ Path = 'scripts/modules/HPEOneView.1000/10.0.4265.2221/en-US/about_HPEOneView.1000.help.txt' }
        @{ Path = 'src/powershell/Automation/Automation.types.ps1xml' }
    ) {
        Test-FixtureIgnored -RelativePath $Path | Should -BeFalse
    }

    It 'excludes unapproved or local module installs: <Path>' -ForEach @(
        @{ Path = 'scripts/modules/HPRESTCmdlets/9.9.9/HPRESTCmdlets.psm1' }
        @{ Path = 'scripts/modules/HPEOneView.1000/99.0.0.0/HPEOneView.1000.psm1' }
        @{ Path = 'scripts/modules/OperationsManager/1.0/OperationsManager.psd1' }
        @{ Path = 'scripts/modules/Unapproved/1.0/Unapproved.psd1' }
    ) {
        Test-FixtureIgnored -RelativePath $Path | Should -BeTrue
    }

    It 'excludes sensitive/runtime files even within an approved package: <File>' -ForEach @(
        @{ File = '.env' }
        @{ File = '.env.production' }
        @{ File = 'secrets.env' }
        @{ File = 'secret.json' }
        @{ File = 'config.private.json' }
        @{ File = 'private.key' }
        @{ File = 'certificate.pfx' }
        @{ File = 'id_rsa' }
        @{ File = 'debug.log' }
        @{ File = 'session_transcript.txt' }
        @{ File = '.ps_history' }
    ) {
        Test-FixtureIgnored -RelativePath "scripts/modules/HPRESTCmdlets/1.2.0.0/$File" | Should -BeTrue
        Test-FixtureIgnored -RelativePath "scripts/modules/HPEOneView.1000/10.0.4265.2221/$File" | Should -BeTrue
    }

    It 'excludes generated files and keeps nested placeholders' {
        Test-FixtureIgnored -RelativePath 'generated/logs/audit/event.json' | Should -BeTrue
        Test-FixtureIgnored -RelativePath 'generated/output/combined/image.iso' | Should -BeTrue
        Test-FixtureIgnored -RelativePath 'generated/.gitkeep' | Should -BeFalse
        Test-FixtureIgnored -RelativePath 'generated/output/combined/.gitkeep' | Should -BeFalse
    }

    It 'keeps all manifest-listed files present and trackable for <Module>' -ForEach @(
        @{ Module = 'HPRESTCmdlets'; Version = '1.2.0.0' }
        @{ Module = 'HPEOneView.1000'; Version = '10.0.4265.2221' }
    ) {
        $relativeRoot = "scripts/modules/$Module/$Version"
        $manifestPath = Join-Path $script:RepoRoot "$relativeRoot/$Module.psd1"
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.ModuleVersion | Should -Be $Version
        $files = @($manifest.RootModule) + @($manifest.FileList) + @($manifest.RequiredAssemblies) + @($manifest.FormatsToProcess) + @($manifest.TypesToProcess)
        foreach ($file in @($files | Where-Object { $_ } | Select-Object -Unique)) {
            $relativeFile = "$relativeRoot/$($file -replace '\\', '/')"
            Test-Path -LiteralPath (Join-Path $script:RepoRoot $relativeFile) -PathType Leaf | Should -BeTrue -Because "the $Module offline package requires $file"
            Test-FixtureIgnored -RelativePath $relativeFile | Should -BeFalse -Because "the $Module offline package must deliver $file"
        }
    }
}
