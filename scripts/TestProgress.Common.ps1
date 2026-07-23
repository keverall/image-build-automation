#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Pure, testable helper functions for Update-TestProgress.ps1.

.DESCRIPTION
    These functions perform the string transformations used to keep the
    Automation and OneView test-plan Markdown documents up to date. They are
    deliberately free of file IO, interactive prompts, and process side-effects
    so they can be unit tested in isolation (see
    tests/powershell/Update-TestProgress.Unit.Tests.ps1).

    The test-plan documents use marker-delimited "variable blocks", e.g.:

        <!-- BEGIN:run-date -->
        <p class="report-run-date"><strong>Run date:</strong> 23/07/2026 09:17</p>
        <!-- END:run-date -->

    Every function below operates on the text *between* a BEGIN/END marker pair,
    keyed off the fixed marker strings rather than fragile prose/regex matching.
    MD_to_HTML_Converter.py strips the comment markers before rendering HTML.
#>

function Get-Block {
    <#
    .SYNOPSIS
        Return the inner text of a <!-- BEGIN:Key --> / <!-- END:Key --> block.
    .OUTPUTS
        The inner text, or $null when the block is not present.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$Key
    )
    $esc = [regex]::Escape($Key)
    $rx = "(?s)<!-- BEGIN:$esc -->\r?\n(.*?)\r?\n<!-- END:$esc -->"
    if ($Content -match $rx) { return $Matches[1] }
    return $null
}

function Set-Block {
    <#
    .SYNOPSIS
        Replace the inner text of a marker block, preserving the markers.
    .DESCRIPTION
        Uses a MatchEvaluator so that replacement text containing '$', backticks
        or braces from user input is inserted literally (no regex substitution).
        Warns and returns the original content unchanged if the block is missing.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Inner
    )
    $esc = [regex]::Escape($Key)
    $rx = "(?s)(<!-- BEGIN:$esc -->\r?\n)(.*?)(\r?\n<!-- END:$esc -->)"
    if ($Content -notmatch $rx) {
        Write-Warning "Block '$Key' not found"
        return $Content
    }
    $eval = { param($m) $m.Groups[1].Value + $Inner + $m.Groups[3].Value }.GetNewClosure()
    return [regex]::Replace($Content, $rx, $eval)
}

function ConvertTo-TableCell {
    <#
    .SYNOPSIS
        Make arbitrary text safe to place inside a Markdown table cell.
    .DESCRIPTION
        Escapes pipe characters (so they do not create extra columns) and
        collapses any newlines to single spaces (so a row stays on one line).
    #>
    param([AllowEmptyString()][AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $escaped = $Text -replace '\|', '\|'
    $escaped = $escaped -replace '\r?\n', ' '
    return $escaped.Trim()
}

function Get-RowLine {
    <#
    .SYNOPSIS
        Split a block's inner text into non-empty table row lines.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Inner)
    if ([string]::IsNullOrWhiteSpace($Inner)) { return @() }
    return @($Inner -split '\r?\n' | Where-Object { $_.Trim() -ne '' })
}

function Get-NextRunNumber {
    <#
    .SYNOPSIS
        Return (max existing Run # + 1) for a set of table rows, or 1 if none.
    .DESCRIPTION
        The Run # is taken from the first data cell of each row
        (i.e. the value between the first and second pipe delimiters).
    #>
    param([AllowNull()][string[]]$Rows)
    $max = 0
    if ($null -ne $Rows) {
        foreach ($r in $Rows) {
            $cells = $r -split '\|'
            if ($cells.Count -ge 2 -and $cells[1].Trim() -match '^\d+$') {
                $n = [int]$cells[1].Trim()
                if ($n -gt $max) { $max = $n }
            }
        }
    }
    return $max + 1
}

function Set-LastRowDateTime {
    <#
    .SYNOPSIS
        Replace the Date/Time cell (2nd column) of the last row in $Rows.
    .OUTPUTS
        The updated array of row lines (unchanged when $Rows is empty).
    #>
    param(
        [AllowNull()][string[]]$Rows,
        [Parameter(Mandatory)][string]$DateTime
    )
    $list = @($Rows)
    if ($list.Count -eq 0) { return $list }
    $dt = $DateTime
    $eval = { param($m) "$($m.Groups[1].Value) $dt $($m.Groups[3].Value)" }.GetNewClosure()
    $list[-1] = [regex]::Replace($list[-1], '^(\s*\|[^|]*\|)([^|]*)(\|)', $eval)
    return $list
}

function Update-RunDateBlock {
    <#
    .SYNOPSIS
        Overwrite the run-date block with the supplied timestamp.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$RunDate
    )
    $inner = "<p class=""report-run-date""><strong>Run date:</strong> $RunDate</p>"
    return Set-Block -Content $Content -Key 'run-date' -Inner $inner
}

function Add-AutomationEvidenceRow {
    <#
    .SYNOPSIS
        Append a new row to the Automation section-7 evidence block.
    .OUTPUTS
        [pscustomobject] with Content (updated document) and RunNumber (int).
        When the block is missing, Content is returned unchanged and RunNumber 0.
    #>
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$DateTime,
        [AllowEmptyString()][string]$CommandSuite,
        [AllowEmptyString()][string]$Environment,
        [AllowEmptyString()][string]$Result,
        [AllowEmptyString()][string]$LogRef,
        [AllowEmptyString()][string]$Reason
    )
    $inner = Get-Block -Content $Content -Key 'automation-evidence-rows'
    if ($null -eq $inner) {
        Write-Warning "Block 'automation-evidence-rows' not found"
        return [pscustomobject]@{ Content = $Content; RunNumber = 0 }
    }
    $rows = @(Get-RowLine -Inner $inner)
    $next = Get-NextRunNumber -Rows $rows
    $row = "| $next | $DateTime | $(ConvertTo-TableCell $CommandSuite) | $(ConvertTo-TableCell $Environment) | $(ConvertTo-TableCell $Result) | $(ConvertTo-TableCell $LogRef) | $(ConvertTo-TableCell $Reason) |"
    $rows += $row
    $updated = Set-Block -Content $Content -Key 'automation-evidence-rows' -Inner ($rows -join "`n")
    return [pscustomobject]@{ Content = $updated; RunNumber = $next }
}

function Set-OneViewStatusSummary {
    <#
    .SYNOPSIS
        Replace the OneView status/progress summary bullet.
    .DESCRIPTION
        When $SummaryText is null/blank the content is returned unchanged (the
        existing bullet is kept). Otherwise the single bullet is replaced and the
        text is wrapped in '**...**' to preserve the bold style.
    #>
    param(
        [Parameter(Mandatory)][string]$Content,
        [AllowEmptyString()][AllowNull()][string]$SummaryText
    )
    if ([string]::IsNullOrWhiteSpace($SummaryText)) { return $Content }
    $bullet = "- **$($SummaryText.Trim())**"
    return Set-Block -Content $Content -Key 'oneview-status-summary' -Inner $bullet
}

function Update-Phase11Block {
    <#
    .SYNOPSIS
        Refresh the last Phase 11 row's date and optionally append a new row.
    .DESCRIPTION
        Always sets the last existing row's Date/Time cell to $DateTime. When
        -AddRow is supplied a new row is appended using the supplied field values.
    .OUTPUTS
        [pscustomobject] with Content (updated document), RunNumber (int of the
        row added, or 0 when no row was added), and Added (bool).
    #>
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$DateTime,
        [switch]$AddRow,
        [AllowEmptyString()][string]$Phases,
        [AllowEmptyString()][string]$Tester,
        [AllowEmptyString()][string]$Appliance,
        [AllowEmptyString()][string]$Result,
        [AllowEmptyString()][string]$LogRef,
        [AllowEmptyString()][string]$SignedOff
    )
    $inner = Get-Block -Content $Content -Key 'phase11-rows'
    if ($null -eq $inner) {
        Write-Warning "Block 'phase11-rows' not found"
        return [pscustomobject]@{ Content = $Content; RunNumber = 0; Added = $false }
    }
    $rows = @(Get-RowLine -Inner $inner)
    $rows = @(Set-LastRowDateTime -Rows $rows -DateTime $DateTime)

    $runNumber = 0
    $added = $false
    if ($AddRow) {
        $runNumber = Get-NextRunNumber -Rows $rows
        $row = "| $runNumber | $DateTime | $(ConvertTo-TableCell $Phases) | $(ConvertTo-TableCell $Tester) | $(ConvertTo-TableCell $Appliance) | $(ConvertTo-TableCell $Result) | $(ConvertTo-TableCell $LogRef) | $(ConvertTo-TableCell $SignedOff) |"
        $rows += $row
        $added = $true
    }

    $updated = Set-Block -Content $Content -Key 'phase11-rows' -Inner ($rows -join "`n")
    return [pscustomobject]@{ Content = $updated; RunNumber = $runNumber; Added = $added }
}

function Get-TestResultFromLog {
    <#
    .SYNOPSIS
        Parse a TEST SUMMARY BLOCK from log content into a result object.
    .DESCRIPTION
        Falls back to zeroes / 'N/A' duration when the block is not found. The
        Result string is 'Passed (p/t)' only when Failed=0 and Passed=Total,
        otherwise 'Failed (p/t passed, f failed)'.
    #>
    param([AllowEmptyString()][AllowNull()][string]$LogContent)
    $pattern = 'TEST SUMMARY BLOCK[\s\S]*?Total Tests\s*:\s*(\d+)[\s\S]*?Passed\s*:\s*(\d+)[\s\S]*?Failed\s*:\s*(\d+)[\s\S]*?Skipped\s*:\s*(\d+)[\s\S]*?Duration\s*:\s*([\d.]+s)'
    if ($null -ne $LogContent -and $LogContent -match $pattern) {
        $total = $Matches[1]; $passed = $Matches[2]; $failed = $Matches[3]
        $skipped = $Matches[4]; $duration = $Matches[5]
        $parsed = $true
    } else {
        $total = 0; $passed = 0; $failed = 0; $skipped = 0; $duration = 'N/A'
        $parsed = $false
    }
    if ([int]$failed -eq 0 -and [int]$passed -eq [int]$total) {
        $result = "Passed ($passed/$total)"
    } else {
        $result = "Failed ($passed/$total passed, $failed failed)"
    }
    return [pscustomobject]@{
        Total = $total; Passed = $passed; Failed = $failed
        Skipped = $skipped; Duration = $duration; Result = $result; Parsed = $parsed
    }
}
