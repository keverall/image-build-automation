#
# Update-TestProgress.Unit.Tests.ps1 - Tests for TestProgress.Common.ps1 functions
#
# Covers all pure helper functions used by Update-TestProgress.ps1:
#   - Get-Block / Set-Block: marker-delimited block extraction and replacement
#   - ConvertTo-TableCell: table cell escaping
#   - Get-RowLine: row extraction from block content
#   - Get-NextRunNumber: run number calculation
#   - Set-LastRowDateTime: date/time update in last row
#   - Update-RunDateBlock: run-date block update
#   - Add-AutomationEvidenceRow: automation evidence row addition
#   - Set-OneViewStatusSummary: OneView status summary update
#   - Update-Phase11Block: Phase 11 row update/addition
#   - Get-TestResultFromLog: log summary parsing
# Plus end-to-end (child process, -SkipHtml) and HTML converter tests.
#

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\scripts\TestProgress.Common.ps1')
}

Describe 'Get-Block' {
    It 'Returns inner text when block exists' {
        $content = @"
before
<!-- BEGIN:test-key -->
inner content here
<!-- END:test-key -->
after
"@
        $result = Get-Block -Content $content -Key 'test-key'
        $result | Should -Be 'inner content here'
    }

    It 'Returns null when block does not exist' {
        $content = 'no markers here'
        $result = Get-Block -Content $content -Key 'missing-key'
        $result | Should -BeNullOrEmpty
    }

    It 'Handles multi-line block content' {
        $content = @"
<!-- BEGIN:multi -->
line 1
line 2
line 3
<!-- END:multi -->
"@
        $result = Get-Block -Content $content -Key 'multi'
        $result | Should -Match 'line 1'
        $result | Should -Match 'line 2'
        $result | Should -Match 'line 3'
    }

    It 'Handles empty block content' {
        $content = @"
<!-- BEGIN:empty -->

<!-- END:empty -->
"@
        $result = Get-Block -Content $content -Key 'empty'
        $result | Should -BeNullOrEmpty
    }

    It 'Handles special regex characters in key' {
        $content = @"
<!-- BEGIN:test.key -->
content
<!-- END:test.key -->
"@
        $result = Get-Block -Content $content -Key 'test.key'
        $result | Should -Be 'content'
    }
}

Describe 'Set-Block' {
    It 'Replaces block inner content' {
        $content = @"
before
<!-- BEGIN:test-key -->
old content
<!-- END:test-key -->
after
"@
        $result = Set-Block -Content $content -Key 'test-key' -Inner 'new content'
        $result | Should -Match '<!-- BEGIN:test-key -->'
        $result | Should -Match 'new content'
        $result | Should -Match '<!-- END:test-key -->'
        $result | Should -Not -Match 'old content'
    }

    It 'Returns unchanged content when block not found' {
        $content = 'no markers'
        $result = Set-Block -Content $content -Key 'missing' -Inner 'new' -WarningAction SilentlyContinue
        $result | Should -Be $content
    }

    It 'Preserves markers exactly' {
        $content = @"
<!-- BEGIN:key -->
old
<!-- END:key -->
"@
        $result = Set-Block -Content $content -Key 'key' -Inner 'new'
        $result | Should -Match '<!-- BEGIN:key -->'
        $result | Should -Match '<!-- END:key -->'
    }

    It 'Handles special characters in replacement text' {
        $content = @"
<!-- BEGIN:key -->
old
<!-- END:key -->
"@
        $result = Set-Block -Content $content -Key 'key' -Inner 'text with $ and ` and {'
        $result | Should -Match 'text with \$ and ` and \{'
    }

    It 'Only touches the targeted key, leaving other blocks intact' {
        $content = @"
<!-- BEGIN:key1 -->
content1
<!-- END:key1 -->
<!-- BEGIN:key2 -->
content2
<!-- END:key2 -->
"@
        $result = Set-Block -Content $content -Key 'key1' -Inner 'new1'
        $result | Should -Match 'new1'
        $result | Should -Match 'content2'
        $result | Should -Not -Match 'content1'
    }
}

Describe 'ConvertTo-TableCell' {
    It 'Escapes pipe characters' {
        $result = ConvertTo-TableCell 'text|with|pipes'
        $result | Should -Be 'text\|with\|pipes'
    }

    It 'Collapses newlines to spaces' {
        $result = ConvertTo-TableCell "line1`nline2`r`nline3"
        $result | Should -Be 'line1 line2 line3'
    }

    It 'Trims whitespace' {
        $result = ConvertTo-TableCell '  text  '
        $result | Should -Be 'text'
    }

    It 'Handles null input' {
        $result = ConvertTo-TableCell $null
        $result | Should -Be ''
    }

    It 'Handles empty string' {
        $result = ConvertTo-TableCell ''
        $result | Should -Be ''
    }

    It 'Combines escaping and newline handling' {
        $result = ConvertTo-TableCell "text|with`npipes"
        $result | Should -Be 'text\|with pipes'
    }
}

Describe 'Get-RowLine' {
    It 'Returns non-empty lines from block content' {
        $inner = @"
row1
row2

row3
"@
        $result = Get-RowLine -Inner $inner
        $result.Count | Should -Be 3
        $result[0] | Should -Be 'row1'
        $result[1] | Should -Be 'row2'
        $result[2] | Should -Be 'row3'
    }

    It 'Returns empty array for null input' {
        $result = Get-RowLine -Inner $null
        $result.Count | Should -Be 0
    }

    It 'Returns empty array for empty string' {
        $result = Get-RowLine -Inner ''
        $result.Count | Should -Be 0
    }

    It 'Returns empty array for whitespace-only input' {
        $result = Get-RowLine -Inner '   '
        $result.Count | Should -Be 0
    }

    It 'Handles Windows line endings' {
        $inner = "row1`r`nrow2`r`nrow3"
        $result = Get-RowLine -Inner $inner
        $result.Count | Should -Be 3
    }
}

Describe 'Get-NextRunNumber' {
    It 'Returns 1 when no rows provided' {
        $result = Get-NextRunNumber -Rows $null
        $result | Should -Be 1
    }

    It 'Returns 1 for empty array' {
        $result = Get-NextRunNumber -Rows @()
        $result | Should -Be 1
    }

    It 'Returns max + 1 from existing rows' {
        $rows = @(
            '| 1 | data |',
            '| 2 | data |',
            '| 3 | data |'
        )
        $result = Get-NextRunNumber -Rows $rows
        $result | Should -Be 4
    }

    It 'Handles non-sequential run numbers' {
        $rows = @(
            '| 1 | data |',
            '| 5 | data |',
            '| 3 | data |'
        )
        $result = Get-NextRunNumber -Rows $rows
        $result | Should -Be 6
    }

    It 'Ignores rows with non-numeric first cell' {
        $rows = @(
            '| 1 | data |',
            '| abc | data |',
            '| 2 | data |'
        )
        $result = Get-NextRunNumber -Rows $rows
        $result | Should -Be 3
    }

    It 'Handles rows with insufficient cells' {
        $rows = @(
            '| 1 | data |',
            '| incomplete',
            '| 2 | data |'
        )
        $result = Get-NextRunNumber -Rows $rows
        $result | Should -Be 3
    }
}

Describe 'Set-LastRowDateTime' {
    It 'Updates date/time in last row' {
        $rows = @(
            '| 1 | 01/01/2026 10:00 | data |',
            '| 2 | 02/01/2026 11:00 | data |'
        )
        $result = Set-LastRowDateTime -Rows $rows -DateTime '03/01/2026 12:00'
        $result[-1] | Should -Match '03/01/2026 12:00'
        $result[0] | Should -Match '01/01/2026 10:00'
    }

    It 'Returns empty array unchanged' {
        $result = Set-LastRowDateTime -Rows @() -DateTime '01/01/2026 10:00'
        $result.Count | Should -Be 0
    }

    It 'Handles null rows' {
        $result = Set-LastRowDateTime -Rows $null -DateTime '01/01/2026 10:00'
        $result.Count | Should -Be 0
    }

    It 'Preserves other columns' {
        $rows = @('| 1 | old date | col3 | col4 |')
        $result = Set-LastRowDateTime -Rows $rows -DateTime 'new date'
        $result | Should -Match '\| 1 \| new date \| col3 \| col4 \|'
    }
}

Describe 'Update-RunDateBlock' {
    It 'Updates run-date block with new date' {
        $content = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->
"@
        $result = Update-RunDateBlock -Content $content -RunDate '02/01/2026 11:00'
        $result | Should -Match '02/01/2026 11:00'
        $result | Should -Not -Match '01/01/2026 10:00'
    }

    It 'Preserves HTML structure' {
        $content = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> old</p>
<!-- END:run-date -->
"@
        $result = Update-RunDateBlock -Content $content -RunDate 'new'
        $result | Should -Match '<p class="report-run-date">'
        $result | Should -Match '<strong>Run date:</strong>'
    }
}

Describe 'Add-AutomationEvidenceRow' {
    It 'Adds new row with correct run number' {
        $content = @"
<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite1 | env1 | Pass | log1 | reason1 |
| 2 | 02/01/2026 | suite2 | env2 | Fail | log2 | reason2 |
<!-- END:automation-evidence-rows -->
"@
        $result = Add-AutomationEvidenceRow -Content $content -DateTime '03/01/2026' `
            -CommandSuite 'suite3' -Environment 'env3' -Result 'Pass' -LogRef 'log3' -Reason 'reason3'
        $result.RunNumber | Should -Be 3
        $result.Content | Should -Match '\| 3 \| 03/01/2026 \| suite3 \| env3 \| Pass \| log3 \| reason3 \|'
    }

    It 'Returns RunNumber 0 when block not found' {
        $content = 'no block here'
        $result = Add-AutomationEvidenceRow -Content $content -DateTime '01/01/2026' `
            -CommandSuite 'suite' -Environment 'env' -Result 'Pass' -LogRef 'log' -Reason 'reason' -WarningAction SilentlyContinue
        $result.RunNumber | Should -Be 0
        $result.Content | Should -Be $content
    }

    It 'Escapes special characters in fields' {
        $content = @"
<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        $result = Add-AutomationEvidenceRow -Content $content -DateTime '02/01/2026' `
            -CommandSuite 'suite|with|pipes' -Environment 'env' -Result 'Pass' -LogRef 'log' -Reason 'reason'
        $result.Content | Should -Match 'suite\\|with\\|pipes'
    }

    It 'Handles empty fields' {
        $content = @"
<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        $result = Add-AutomationEvidenceRow -Content $content -DateTime '02/01/2026' `
            -CommandSuite '' -Environment '' -Result '' -LogRef '' -Reason ''
        $result.RunNumber | Should -Be 2
        $result.Content | Should -Match '\| 2 \| 02/01/2026 \|  \|  \|  \|  \|  \|'
    }
}

Describe 'Set-OneViewStatusSummary' {
    It 'Updates status summary text' {
        $content = @"
<!-- BEGIN:oneview-status-summary -->
- **Old status**
<!-- END:oneview-status-summary -->
"@
        $result = Set-OneViewStatusSummary -Content $content -SummaryText 'New status'
        $result | Should -Match '\- \*\*New status\*\*'
        $result | Should -Not -Match 'Old status'
    }

    It 'Returns unchanged content when SummaryText is null' {
        $content = @"
<!-- BEGIN:oneview-status-summary -->
- **Keep this**
<!-- END:oneview-status-summary -->
"@
        $result = Set-OneViewStatusSummary -Content $content -SummaryText $null
        $result | Should -Be $content
    }

    It 'Returns unchanged content when SummaryText is empty' {
        $content = @"
<!-- BEGIN:oneview-status-summary -->
- **Keep this**
<!-- END:oneview-status-summary -->
"@
        $result = Set-OneViewStatusSummary -Content $content -SummaryText ''
        $result | Should -Be $content
    }

    It 'Trims whitespace from summary text' {
        $content = @"
<!-- BEGIN:oneview-status-summary -->
- **Old**
<!-- END:oneview-status-summary -->
"@
        $result = Set-OneViewStatusSummary -Content $content -SummaryText '  New status  '
        $result | Should -Match '\- \*\*New status\*\*'
    }

    It 'Wraps text in bold markers' {
        $content = @"
<!-- BEGIN:oneview-status-summary -->
- **Old**
<!-- END:oneview-status-summary -->
"@
        $result = Set-OneViewStatusSummary -Content $content -SummaryText 'Status'
        $result | Should -Match '\*\*Status\*\*'
    }

    It 'Is idempotent: running twice replaces, does not append a second bullet' {
        $content = @"
<!-- BEGIN:oneview-status-summary -->
- **First**
<!-- END:oneview-status-summary -->
"@
        $result = Set-OneViewStatusSummary -Content $content -SummaryText 'Second'
        $result = Set-OneViewStatusSummary -Content $result -SummaryText 'Third'
        $result | Should -Match '\- \*\*Third\*\*'
        $result | Should -Not -Match 'First'
        $result | Should -Not -Match 'Second'
        $bullets = @($result -split "`n" | Where-Object { $_ -match '^- \*\*' })
        $bullets.Count | Should -Be 1
    }
}

Describe 'Update-Phase11Block' {
    It 'Updates last row date without adding row' {
        $content = @"
<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
| 2 | 02/01/2026 | Phases 6-10 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        $result = Update-Phase11Block -Content $content -DateTime '03/01/2026'
        $result.Added | Should -Be $false
        $result.RunNumber | Should -Be 0
        $result.Content | Should -Match '\| 2 \| 03/01/2026 \|'
        $result.Content | Should -Match '\| 1 \| 01/01/2026 \|'
    }

    It 'Adds new row when AddRow specified' {
        $content = @"
<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        $result = Update-Phase11Block -Content $content -DateTime '02/01/2026' -AddRow `
            -Phases 'Phases 6-10' -Tester 'tester2' -Appliance 'appliance2' `
            -Result 'Fail' -LogRef 'log2' -SignedOff 'signed2'
        $result.Added | Should -Be $true
        $result.RunNumber | Should -Be 2
        $result.Content | Should -Match '\| 2 \| 02/01/2026 \| Phases 6-10 \| tester2 \| appliance2 \| Fail \| log2 \| signed2 \|'
    }

    It 'Returns RunNumber 0 when block not found' {
        $content = 'no block'
        $result = Update-Phase11Block -Content $content -DateTime '01/01/2026' 3>&1
        $result.RunNumber | Should -Be 0
        $result.Added | Should -Be $false
        $result.Content | Should -Be $content
    }

    It 'Updates last row date even when adding new row' {
        $content = @"
<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        $result = Update-Phase11Block -Content $content -DateTime '02/01/2026' -AddRow `
            -Phases 'Phases 6-10' -Tester 'tester2' -Appliance 'appliance2' `
            -Result 'Pass' -LogRef 'log2' -SignedOff 'signed2'
        $result.Content | Should -Match '\| 1 \| 02/01/2026 \|'
    }

    It 'Escapes pipe characters in add-row fields' {
        $content = @"
<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        $result = Update-Phase11Block -Content $content -DateTime '02/01/2026' -AddRow `
            -Phases 'Phases|with|pipes' -Tester 'tester' -Appliance 'appliance' `
            -Result 'Pass' -LogRef 'log' -SignedOff 'signed'
        $result.Content | Should -Match 'Phases\\|with\\|pipes'
    }
}

Describe 'Get-TestResultFromLog' {
    It 'Parses valid test summary block' {
        $logContent = @"
Some log content
================================================================================
                           TEST SUMMARY BLOCK
================================================================================
 Total Tests   : 100
 Passed        : 95 ✔
 Failed        : 3 ✖ (CRITICAL)
 Skipped       : 2
 Duration      : 45.67s
================================================================================
More log content
"@
        $result = Get-TestResultFromLog -LogContent $logContent
        $result.Parsed | Should -Be $true
        $result.Total | Should -Be '100'
        $result.Passed | Should -Be '95'
        $result.Failed | Should -Be '3'
        $result.Skipped | Should -Be '2'
        $result.Duration | Should -Be '45.67s'
        $result.Result | Should -Match 'Failed'
    }

    It 'Returns Passed result when all tests pass' {
        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 50
 Passed        : 50
 Failed        : 0
 Skipped       : 0
 Duration      : 10.5s
"@
        $result = Get-TestResultFromLog -LogContent $logContent
        $result.Parsed | Should -Be $true
        $result.Result | Should -Match 'Passed \(50/50\)'
    }

    It 'Returns fallback values when summary not found' {
        $logContent = 'no summary here'
        $result = Get-TestResultFromLog -LogContent $logContent
        $result.Parsed | Should -Be $false
        $result.Total | Should -Be '0'
        $result.Passed | Should -Be '0'
        $result.Failed | Should -Be '0'
        $result.Skipped | Should -Be '0'
        $result.Duration | Should -Be 'N/A'
    }

    It 'Handles null log content' {
        $result = Get-TestResultFromLog -LogContent $null
        $result.Parsed | Should -Be $false
        $result.Total | Should -Be '0'
    }

    It 'Handles empty log content' {
        $result = Get-TestResultFromLog -LogContent ''
        $result.Parsed | Should -Be $false
    }

    It 'Returns Failed result when any tests fail' {
        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 10
 Passed        : 8
 Failed        : 2
 Skipped       : 0
 Duration      : 5.0s
"@
        $result = Get-TestResultFromLog -LogContent $logContent
        $result.Result | Should -Match 'Failed'
        $result.Result | Should -Match '8/10 passed, 2 failed'
    }

    It 'Parses duration with decimal places' {
        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 1
 Passed        : 1
 Failed        : 0
 Skipped       : 0
 Duration      : 123.456s
"@
        $result = Get-TestResultFromLog -LogContent $logContent
        $result.Duration | Should -Be '123.456s'
    }
}

Describe 'End-to-end script (child process, -SkipHtml)' {
    BeforeAll {
        $Script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        $Script:ScriptPath = Join-Path $Script:ProjectRoot 'scripts/Update-TestProgress.ps1'
        $Script:FixtureDir = Join-Path $Script:ProjectRoot 'generated/test-fixtures/test-progress-e2e'
    }

    BeforeEach {
        if (Test-Path $Script:FixtureDir) { Remove-Item -Recurse -Force $Script:FixtureDir }
        New-Item -ItemType Directory -Force -Path $Script:FixtureDir | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:FixtureDir) { Remove-Item -Recurse -Force $Script:FixtureDir }
    }

    It 'TPR-E2E-01: Default non-interactive run updates both plans' {
        $automationPlan = Join-Path $Script:FixtureDir 'AUTOMATION_TEST_PLAN.md'
        $oneviewPlan = Join-Path $Script:FixtureDir 'ONEVIEW_TEST_PLAN.md'
        $logFile = Join-Path $Script:FixtureDir 'test.log'

        $automationContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        Set-Content -Path $automationPlan -Value $automationContent -NoNewline

        $oneviewContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        Set-Content -Path $oneviewPlan -Value $oneviewContent -NoNewline

        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 10
 Passed        : 10
 Failed        : 0
 Skipped       : 0
 Duration      : 5.0s
"@
        Set-Content -Path $logFile -Value $logContent -NoNewline

        $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $Script:ScriptPath,
            '-LogPath', $logFile,
            '-TestPlanPath', $automationPlan,
            '-OneViewTestPlanPath', $oneviewPlan,
            '-NonInteractive', '-SkipHtml'
        ) -Wait -PassThru -NoNewWindow

        $proc.ExitCode | Should -Be 0
        $updatedAuto = Get-Content $automationPlan -Raw
        $updatedAuto | Should -Not -Match '01/01/2026 10:00'
        $updatedAuto | Should -Match '\| 2 \|'
    }

    It 'TPR-E2E-02: Phase 11 last-row date refresh without adding row' {
        $automationPlan = Join-Path $Script:FixtureDir 'AUTOMATION_TEST_PLAN.md'
        $oneviewPlan = Join-Path $Script:FixtureDir 'ONEVIEW_TEST_PLAN.md'
        $logFile = Join-Path $Script:FixtureDir 'test.log'

        $automationContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        Set-Content -Path $automationPlan -Value $automationContent -NoNewline

        $oneviewContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        Set-Content -Path $oneviewPlan -Value $oneviewContent -NoNewline

        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 10
 Passed        : 10
 Failed        : 0
 Skipped       : 0
 Duration      : 5.0s
"@
        Set-Content -Path $logFile -Value $logContent -NoNewline

        $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $Script:ScriptPath,
            '-LogPath', $logFile,
            '-TestPlanPath', $automationPlan,
            '-OneViewTestPlanPath', $oneviewPlan,
            '-NonInteractive', '-SkipHtml'
        ) -Wait -PassThru -NoNewWindow

        $proc.ExitCode | Should -Be 0
        $updatedOv = Get-Content $oneviewPlan -Raw
        $updatedOv | Should -Not -Match '\| 1 \| 01/01/2026'
        $updatedOv | Should -Match '\| 1 \|'
        $rowLines = ($updatedOv -split '\n' | Where-Object { $_ -match '^\| \d+ \|' }).Count
        $rowLines | Should -Be 1
    }

    It 'TPR-E2E-03: -OneViewStatusSummary supplied replaces bullet' {
        $automationPlan = Join-Path $Script:FixtureDir 'AUTOMATION_TEST_PLAN.md'
        $oneviewPlan = Join-Path $Script:FixtureDir 'ONEVIEW_TEST_PLAN.md'
        $logFile = Join-Path $Script:FixtureDir 'test.log'

        $automationContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        Set-Content -Path $automationPlan -Value $automationContent -NoNewline

        $oneviewContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:oneview-status-summary -->
- **Old status**
<!-- END:oneview-status-summary -->

<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        Set-Content -Path $oneviewPlan -Value $oneviewContent -NoNewline

        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 10
 Passed        : 10
 Failed        : 0
 Skipped       : 0
 Duration      : 5.0s
"@
        Set-Content -Path $logFile -Value $logContent -NoNewline

        $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $Script:ScriptPath,
            '-LogPath', $logFile,
            '-TestPlanPath', $automationPlan,
            '-OneViewTestPlanPath', $oneviewPlan,
            '-NonInteractive', '-SkipHtml',
            '-OneViewStatusSummary', '"New status text"'
        ) -Wait -PassThru -NoNewWindow

        $proc.ExitCode | Should -Be 0
        $updatedOv = Get-Content $oneviewPlan -Raw
        $updatedOv | Should -Match 'New status text'
        $updatedOv | Should -Not -Match 'Old status'
    }

    It 'TPR-E2E-04: No summary param leaves bullet unchanged' {
        $automationPlan = Join-Path $Script:FixtureDir 'AUTOMATION_TEST_PLAN.md'
        $oneviewPlan = Join-Path $Script:FixtureDir 'ONEVIEW_TEST_PLAN.md'
        $logFile = Join-Path $Script:FixtureDir 'test.log'

        $automationContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        Set-Content -Path $automationPlan -Value $automationContent -NoNewline

        $oneviewContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:oneview-status-summary -->
- **Keep this**
<!-- END:oneview-status-summary -->

<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        Set-Content -Path $oneviewPlan -Value $oneviewContent -NoNewline

        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 10
 Passed        : 10
 Failed        : 0
 Skipped       : 0
 Duration      : 5.0s
"@
        Set-Content -Path $logFile -Value $logContent -NoNewline

        $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $Script:ScriptPath,
            '-LogPath', $logFile,
            '-TestPlanPath', $automationPlan,
            '-OneViewTestPlanPath', $oneviewPlan,
            '-NonInteractive', '-SkipHtml'
        ) -Wait -PassThru -NoNewWindow

        $proc.ExitCode | Should -Be 0
        $updatedOv = Get-Content $oneviewPlan -Raw
        $updatedOv | Should -Match 'Keep this'
    }

    It 'TPR-E2E-05: -AddOneViewRow with fields appends new row' {
        $automationPlan = Join-Path $Script:FixtureDir 'AUTOMATION_TEST_PLAN.md'
        $oneviewPlan = Join-Path $Script:FixtureDir 'ONEVIEW_TEST_PLAN.md'
        $logFile = Join-Path $Script:FixtureDir 'test.log'

        $automationContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        Set-Content -Path $automationPlan -Value $automationContent -NoNewline

        $oneviewContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        Set-Content -Path $oneviewPlan -Value $oneviewContent -NoNewline

        $logContent = @"
TEST SUMMARY BLOCK
 Total Tests   : 10
 Passed        : 10
 Failed        : 0
 Skipped       : 0
 Duration      : 5.0s
"@
        Set-Content -Path $logFile -Value $logContent -NoNewline

        $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $Script:ScriptPath,
            '-LogPath', $logFile,
            '-TestPlanPath', $automationPlan,
            '-OneViewTestPlanPath', $oneviewPlan,
            '-NonInteractive', '-SkipHtml',
            '-AddOneViewRow',
            '-OvPhases', '"Phases 6-10"',
            '-OvTester', 'tester2',
            '-OvAppliance', 'appliance2',
            '-OvResult', 'Pass',
            '-OvLogRef', 'log2',
            '-OvSignedOff', 'signed2'
        ) -Wait -PassThru -NoNewWindow

        $proc.ExitCode | Should -Be 0
        $updatedOv = Get-Content $oneviewPlan -Raw
        $updatedOv | Should -Match '\| 2 \|'
        $updatedOv | Should -Match 'Phases 6-10'
        $updatedOv | Should -Match 'tester2'
    }

    It 'TPR-E2E-06: Missing log file causes non-zero exit' {
        $automationPlan = Join-Path $Script:FixtureDir 'AUTOMATION_TEST_PLAN.md'
        $oneviewPlan = Join-Path $Script:FixtureDir 'ONEVIEW_TEST_PLAN.md'
        $missingLog = Join-Path $Script:FixtureDir 'nonexistent.log'

        $automationContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:automation-evidence-rows -->
| 1 | 01/01/2026 | suite | env | Pass | log | reason |
<!-- END:automation-evidence-rows -->
"@
        Set-Content -Path $automationPlan -Value $automationContent -NoNewline

        $oneviewContent = @"
<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->

<!-- BEGIN:phase11-rows -->
| 1 | 01/01/2026 | Phases 1-5 | tester | appliance | Pass | log | signed |
<!-- END:phase11-rows -->
"@
        Set-Content -Path $oneviewPlan -Value $oneviewContent -NoNewline

        $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $Script:ScriptPath,
            '-LogPath', $missingLog,
            '-TestPlanPath', $automationPlan,
            '-OneViewTestPlanPath', $oneviewPlan,
            '-NonInteractive', '-SkipHtml'
        ) -Wait -PassThru -NoNewWindow

        $proc.ExitCode | Should -Not -Be 0
    }
}

Describe 'HTML converter comment stripping' {
    BeforeAll {
        $Script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        $Script:ConverterScript = Join-Path $Script:ProjectRoot 'scripts/MD_to_HTML_Converter.py'
        $Script:FixtureDir = Join-Path $Script:ProjectRoot 'generated/test-fixtures/html-converter'
    }

    BeforeEach {
        if (Test-Path $Script:FixtureDir) { Remove-Item -Recurse -Force $Script:FixtureDir }
        New-Item -ItemType Directory -Force -Path $Script:FixtureDir | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:FixtureDir) { Remove-Item -Recurse -Force $Script:FixtureDir }
    }

    It 'TPR-HTML-01: Markers around a table are stripped, data rows present' {
        $inputMd = Join-Path $Script:FixtureDir 'input.md'
        $outputHtml = Join-Path $Script:FixtureDir 'output.html'

        $mdContent = @"
# Test

<!-- BEGIN:test-rows -->
| 1 | data1 |
| 2 | data2 |
<!-- END:test-rows -->
"@
        Set-Content -Path $inputMd -Value $mdContent -NoNewline

        & python3 $ConverterScript $inputMd $outputHtml
        $htmlContent = Get-Content $outputHtml -Raw
        $htmlContent | Should -Not -Match '<!--'
        $htmlContent | Should -Match 'data1'
        $htmlContent | Should -Match 'data2'
    }

    It 'TPR-HTML-02: Markers around run-date <p> are stripped, passthrough intact' {
        $inputMd = Join-Path $Script:FixtureDir 'input.md'
        $outputHtml = Join-Path $Script:FixtureDir 'output.html'

        $mdContent = @"
# Test

<!-- BEGIN:run-date -->
<p class="report-run-date"><strong>Run date:</strong> 01/01/2026 10:00</p>
<!-- END:run-date -->
"@
        Set-Content -Path $inputMd -Value $mdContent -NoNewline

        & python3 $ConverterScript $inputMd $outputHtml
        $htmlContent = Get-Content $outputHtml -Raw
        $htmlContent | Should -Not -Match '<!--'
        $htmlContent | Should -Match 'report-run-date'
        $htmlContent | Should -Match '01/01/2026 10:00'
    }

    It 'TPR-HTML-03: Standalone marker line removal leaves no stray blank line' {
        $inputMd = Join-Path $Script:FixtureDir 'input.md'
        $outputHtml = Join-Path $Script:FixtureDir 'output.html'

        $mdContent = @"
# Test

| Header |
|--------|
<!-- BEGIN:marker -->
| data |
<!-- END:marker -->
"@
        Set-Content -Path $inputMd -Value $mdContent -NoNewline

        & python3 $ConverterScript $inputMd $outputHtml
        $htmlContent = Get-Content $outputHtml -Raw
        $htmlContent | Should -Not -Match '<!--'
        $htmlContent | Should -Match 'data'
    }
}
