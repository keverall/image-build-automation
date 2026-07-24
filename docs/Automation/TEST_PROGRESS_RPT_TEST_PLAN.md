# Test Progress Report Generator — Test Plan

<a id="top"></a>
## Table of Contents

- [Column legend](#column-legend)
- [1. Marker block helpers (`Get-Block` / `Set-Block`)](#1-marker-block-helpers-get-block-set-block)
- [2. Cell / row utilities](#2-cell-row-utilities)
- [3. Run-date block](#3-run-date-block)
- [4. Automation section-7 evidence](#4-automation-section-7-evidence)
- [5. OneView status summary bullet](#5-oneview-status-summary-bullet)
- [6. OneView Phase 11 table](#6-oneview-phase-11-table)
- [7. Log summary parsing](#7-log-summary-parsing)
- [8. End-to-end script (child process, `-SkipHtml`)](#8-end-to-end-script-child-process--skiphtml)
- [9. HTML converter comment stripping](#9-html-converter-comment-stripping)
This plan documents the automated test coverage for the test-plan progress
generator, i.e. the pipeline behind `make test-progress-update`:

- `scripts/TestProgress.Common.ps1` — pure string-transformation helpers.
- `scripts/Update-TestProgress.ps1` — CLI orchestration (IO, prompts, HTML).
- `scripts/MD_to_HTML_Converter.py` — Markdown → HTML (marker-comment stripping).

Run the suite with:

```
make test-progress-rpt-tests
```

The tests live in `tests/powershell/Update-TestProgress.Unit.Tests.ps1` and are
Pester v5 tests. Integration cases invoke `Update-TestProgress.ps1` in a child
`pwsh` process (with `-SkipHtml`) against disposable fixture copies so that no
repository files are modified and the script's `exit` calls cannot abort Pester.

<a name="column-legend"></a>
## Column legend
- **Area** — component under test.
- **Case** — the specific branch/variant exercised.
- **Expected** — the asserted outcome.

<a name="1-marker-block-helpers-get-block-set-block"></a>
## 1. Marker block helpers (`Get-Block` / `Set-Block`)

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-BLK-01 | `Get-Block` on an existing key | Returns the inner text between markers |
| TPR-BLK-02 | `Get-Block` on a missing key | Returns `$null` |
| TPR-BLK-03 | `Set-Block` replaces inner text | Markers preserved, inner replaced |
| TPR-BLK-04 | `Set-Block` on a missing key | Warns and returns content unchanged |
| TPR-BLK-05 | `Set-Block` with `$`, backtick, brace in text | Inserted literally (no regex/var substitution) |
| TPR-BLK-06 | `Set-Block` only touches the targeted key | Other blocks left intact |

<a name="2-cell-row-utilities"></a>
## 2. Cell / row utilities

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-UTL-01 | `ConvertTo-TableCell` with a pipe | `\|` escaped |
| TPR-UTL-02 | `ConvertTo-TableCell` with newlines | Collapsed to spaces, trimmed |
| TPR-UTL-03 | `ConvertTo-TableCell` with null/empty | Returns empty string |
| TPR-UTL-04 | `Get-RowLine` on multi-line block | Returns only non-empty row lines |
| TPR-UTL-05 | `Get-RowLine` on empty/whitespace | Returns empty array |
| TPR-UTL-06 | `Get-NextRunNumber` with rows 1,2 | Returns 3 |
| TPR-UTL-07 | `Get-NextRunNumber` with no numeric rows | Returns 1 |
| TPR-UTL-08 | `Set-LastRowDateTime` updates 2nd cell of last row | Only last row date changes |
| TPR-UTL-09 | `Set-LastRowDateTime` on empty rows | No error, returns empty |

<a name="3-run-date-block"></a>
## 3. Run-date block

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-RD-01 | `Update-RunDateBlock` | `<p class="report-run-date">` line carries new date |
| TPR-RD-02 | Idempotent format | Output matches `dd/MM/yyyy HH:mm` value supplied |

<a name="4-automation-section-7-evidence"></a>
## 4. Automation section-7 evidence

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-AUT-01 | `Add-AutomationEvidenceRow` appends a row | New row present, `RunNumber` incremented |
| TPR-AUT-02 | Reason/Command with a pipe | Pipe escaped in the emitted row |
| TPR-AUT-03 | Block missing | Warns, content unchanged, `RunNumber=0` |

<a name="5-oneview-status-summary-bullet"></a>
## 5. OneView status summary bullet

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-SUM-01 | Replacement text supplied | Bullet replaced, wrapped in `**...**` |
| TPR-SUM-02 | Blank/null text | Content unchanged (existing bullet kept) |
| TPR-SUM-03 | Replacement run twice | Replaces, does not append a second bullet |

<a name="6-oneview-phase-11-table"></a>
## 6. OneView Phase 11 table

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-P11-01 | No add-row | Last row's Date/Time refreshed only, no new row |
| TPR-P11-02 | Add-row | New row appended, `RunNumber` incremented, `Added=$true` |
| TPR-P11-03 | Add-row field with a pipe | Pipe escaped in the emitted row |
| TPR-P11-04 | Block missing | Warns, content unchanged |

<a name="7-log-summary-parsing"></a>
## 7. Log summary parsing

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-LOG-01 | Valid TEST SUMMARY BLOCK (all pass) | Result `Passed (n/n)`, `Parsed=$true` |
| TPR-LOG-02 | Failures present | Result `Failed (p/t passed, f failed)` |
| TPR-LOG-03 | No summary block | Fallback zeroes, duration `N/A`, `Parsed=$false` |

<a name="8-end-to-end-script-child-process--skiphtml"></a>
## 8. End-to-end script (child process, `-SkipHtml`)

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-E2E-01 | Default non-interactive run | Run-date updated in BOTH plans; section-7 row appended |
| TPR-E2E-02 | Phase 11 last-row date refresh | Existing row date set to run date, no new row |
| TPR-E2E-03 | `-OneViewStatusSummary` supplied | Summary bullet replaced |
| TPR-E2E-04 | No summary param | Summary bullet unchanged |
| TPR-E2E-05 | `-AddOneViewRow` with fields | New Phase 11 row appended |
| TPR-E2E-06 | Missing log file | Non-zero exit, clear error |

<a name="9-html-converter-comment-stripping"></a>
## 9. HTML converter comment stripping

| Test ID | Case | Expected |
|---------|------|----------|
| TPR-HTML-01 | Markers around a table | No `<!--` in output; all data rows present |
| TPR-HTML-02 | Markers around run-date `<p>` | `report-run-date` passthrough intact |
| TPR-HTML-03 | Standalone marker line removal | No stray blank line splits the table |
