#
# Logging.Unit.Tests.ps1 - Functional tests for the centralized logging subsystem.
#
# Covers every log type / level and the path-resolution behaviour so that the
# logging used by all automation commands is validated:
#   - Initialize-Logging: timestamped file creation, testing vs production dir,
#     level normalisation (INFORMATION->INFO, VERBOSE->DEBUG), no-LogFile guard.
#   - Get-Logger: Info/Warning/Error/Debug methods, level filtering, shared file,
#     and canonical line format "yyyy-MM-dd HH:mm:ss - <Name> - <LEVEL> - <msg>".
#

BeforeAll {
    $Script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\powershell')).Path
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
    Import-Module (Join-Path $Script:ModuleRoot 'Automation\Automation.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Initialize-Logging - file creation and path resolution' {

    BeforeEach {
        $global:__AutomationLogPath   = $null
        $global:__AutomationLogLevel  = $null
    }

    It 'Creates a timestamped log file in the testing directory when run under Pester' {
        Initialize-Logging -LogFile 'test_log_a.log' -Level 'Information'
        $global:__AutomationLogPath | Should -Not -BeNullOrEmpty
        # Initialize-Logging sets the path; a log entry is required to materialise
        # the file on disk.
        $logger = Get-Logger 'Seed'
        $logger.Info('seed entry')
        Test-Path $global:__AutomationLogPath | Should -Be $true
        $global:__AutomationLogPath | Should -Match 'generated[\\/]logs[\\/]testing'
        Split-Path $global:__AutomationLogPath -Leaf | Should -Match '^test_log_a_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z_INFO\.log$'
    }

    It 'Sets the global log level used for Debug filtering' {
        Initialize-Logging -LogFile 'test_log_b.log' -Level 'Debug'
        $global:__AutomationLogLevel | Should -Be 'Debug'
    }

    It 'Normalises Information level to INFO in the file name' {
        Initialize-Logging -LogFile 'test_log_c.log' -Level 'Information'
        Split-Path $global:__AutomationLogPath -Leaf | Should -Match '_INFO\.log$'
    }

    It 'Normalises Verbose level to DEBUG in the file name' {
        Initialize-Logging -LogFile 'test_log_d.log' -Level 'Verbose'
        Split-Path $global:__AutomationLogPath -Leaf | Should -Match '_DEBUG\.log$'
    }

    It 'Does not create a file when LogFile is omitted but still configures logging' {
        Initialize-Logging
        $global:__AutomationLogPath | Should -BeNullOrEmpty
    }
}

Describe 'Get-Logger - methods and level filtering' {

    BeforeEach {
        $global:__AutomationLogPath   = $null
        $global:__AutomationLogLevel  = $null
    }

    It 'Returns a logger exposing Info/Warning/Error/Debug script methods' {
        Initialize-Logging -LogFile 'logger.log' -Level 'Information'
        $logger = Get-Logger 'MyComponent'
        $logger.Name | Should -Be 'MyComponent'
        foreach ($m in @('Info', 'Warning', 'Error', 'Debug')) {
            $logger.PSObject.Methods.Name | Should -Contain $m
        }
    }

    It 'Info appends a correctly formatted INFO line to the log file' {
        Initialize-Logging -LogFile 'info.log' -Level 'Information'
        $logger = Get-Logger 'Comp'
        $logger.Info('hello world')
        $lines = Get-Content $global:__AutomationLogPath
        $lines[-1] | Should -Match ' - Comp - INFO - hello world$'
        $lines[-1] | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} - '
    }

    It 'Warning appends a WARNING line' {
        Initialize-Logging -LogFile 'warn.log' -Level 'Information'
        $logger = Get-Logger 'Comp'
        $logger.Warning('careful')
        (Get-Content $global:__AutomationLogPath)[-1] | Should -Match ' - Comp - WARNING - careful$'
    }

    It 'Error appends an ERROR line' {
        Initialize-Logging -LogFile 'err.log' -Level 'Information'
        $logger = Get-Logger 'Comp'
        $logger.Error('boom')
        (Get-Content $global:__AutomationLogPath)[-1] | Should -Match ' - Comp - ERROR - boom$'
    }

    It 'Debug is suppressed when the level is Information' {
        Initialize-Logging -LogFile 'dbg.log' -Level 'Information'
        $logger = Get-Logger 'Comp'
        $logger.Debug('secret-trace')
        $content = Get-Content $global:__AutomationLogPath
        ($content | Where-Object { $_ -match 'secret-trace' }) | Should -BeNullOrEmpty
    }

    It 'Debug is written when the level is Debug' {
        Initialize-Logging -LogFile 'dbg2.log' -Level 'Debug'
        $logger = Get-Logger 'Comp'
        $logger.Debug('traceme')
        (Get-Content $global:__AutomationLogPath)[-1] | Should -Match ' - Comp - DEBUG - traceme$'
    }

    It 'Debug is written when the level is Verbose' {
        Initialize-Logging -LogFile 'dbg3.log' -Level 'Verbose'
        $logger = Get-Logger 'Comp'
        $logger.Debug('traceme2')
        (Get-Content $global:__AutomationLogPath)[-1] | Should -Match ' - Comp - DEBUG - traceme2$'
    }

    It 'Multiple named loggers append to the same file' {
        Initialize-Logging -LogFile 'multi.log' -Level 'Information'
        $a = Get-Logger 'A'
        $b = Get-Logger 'B'
        $a.Info('from A')
        $b.Info('from B')
        $content = Get-Content $global:__AutomationLogPath
        ($content | Where-Object { $_ -match 'from A' }) | Should -Not -BeNullOrEmpty
        ($content | Where-Object { $_ -match 'from B' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-Logger - graceful behaviour when no log path is configured' {

    It 'Does not throw when no log file is configured' {
        InModuleScope Automation {
            $script:_Configured          = $false
            $global:__AutomationLogPath  = $null
            $global:__AutomationLogLevel = $null
            $logger = Get-Logger 'Safe'
            { $logger.Info('no file yet') } | Should -Not -Throw
            { $logger.Error('still fine') } | Should -Not -Throw
        }
    }
}

Describe 'Log file format validation' {

    It 'Every written line matches the canonical log format' {
        Initialize-Logging -LogFile 'format.log' -Level 'Debug'
        $logger = Get-Logger 'Fmt'
        $logger.Info('one')
        $logger.Warning('two')
        $logger.Error('three')
        $logger.Debug('four')
        $lines = Get-Content $global:__AutomationLogPath
        $lines.Count | Should -BeGreaterThan 0
        foreach ($l in $lines) {
            $l | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} - [^-]+ - (INFO|WARNING|ERROR|DEBUG) - .+$'
        }
    }
}
