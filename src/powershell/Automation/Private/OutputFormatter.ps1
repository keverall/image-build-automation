#
# OutputFormatter.ps1 - Shared, DRY output formatting for the Automation module.
#
# Many commands build a structured result (hashtable / PSCustomObject / array of
# objects) and `return` it. When that result reaches a terminal or a log, PowerShell
# renders a *hashtable* as a truncated 2-column `Name / Value` table, which dumps
# nested structures as unreadable `{[Port, 443], [Error, ], ...}` fragments.
#
# This module provides ONE place that turns any structured result into a clean,
# human-readable form (indented labelled lists + tables) for screen / transcript /
# log output, while still letting callers opt into raw data:
#
#   _Publish-Result -Result $r            # human-readable report only (default)
#   _Publish-Result -Result $r -PassThru  # also return $r on the success stream
#   _Publish-Result -Result $r -Json      # emit a JSON string on the success stream
#   _Publish-Result -Result $r -CustomView { ... }  # rich, command-specific view
#
# The generic renderer (_Format-HumanReadable) handles hashtables, PSCustomObjects,
# scalar lists and object arrays ("any JSON") so individual commands no longer need
# bespoke formatting just to avoid the truncated dump.
#

function _ConvertTo-FriendlyLabel {
    <#
    .SYNOPSIS
        Turns a code key (e.g. DnsResolved, OneViewHost) into a friendly
        label ("DNS Resolved", "One View Host") for human-readable output.
    #>
    [CmdletBinding()]
    param([string] $Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }

    # Insert spaces between word boundaries.
    $s = [regex]::Replace($Name, '([a-z0-9])([A-Z])', '$1 $2')
    $s = [regex]::Replace($s, '([A-Z]+)([A-Z][a-z])', '$1 $2')

    # Normalise well-known acronyms (case-insensitive) back to their canonical case.
    $map = @{
        'dns'   = 'DNS';     'tcp'   = 'TCP';    'udp'   = 'UDP';    'ip'    = 'IP'
        'ipmi'  = 'IPMI';    'ilo'   = 'iLO';    'url'   = 'URL';    'api'   = 'API'
        'scom'  = 'SCOM';    'json'  = 'JSON';   'csv'   = 'CSV';    'http'  = 'HTTP'
        'https' = 'HTTPS';   'utc'   = 'UTC';    'ov'    = 'OV';     'id'    = 'ID'
        'vm'    = 'VM';      'uuid'  = 'UUID';   'os'    = 'OS';     'ram'   = 'RAM'
        'cpu'   = 'CPU';     'nic'   = 'NIC';    'ipv4'  = 'IPv4';   'ipv6'  = 'IPv6'
    }
    foreach ($k in $map.Keys) {
        $s = [regex]::Replace($s, "\b$([regex]::Escape($k))\b", $map[$k],
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    # Title-case words that are not already all-caps acronyms.
    $words = $s -split ' ' | ForEach-Object {
        if ($_ -cmatch '^[A-Z0-9]+$') { $_ }
        else { (Get-Culture).TextInfo.ToTitleCase($_) }
    }
    return ($words -join ' ').Trim()
}

function _Test-IsScalar {
    <#
    .SYNOPSIS
        Returns $true for values that should be rendered inline (not recursed into).
    #>
    param($Value)
    if ($null -eq $Value) { return $true }
    if ($Value -is [string]) { return $true }
    if ($Value.GetType().IsPrimitive) { return $true }
    if ($Value -is [decimal] -or $Value -is [datetime] -or $Value -is [DateTimeOffset] -or
        $Value -is [TimeSpan] -or $Value -is [enum] -or $Value -is [guid] -or $Value -is [Uri]) {
        return $true
    }
    return $false
}

function _Stringify-Cell {
    <#
    .SYNOPSIS
        Renders a single table cell value as a short, log-friendly string.
    #>
    param($Value)
    if ($null -eq $Value) { return '' }
    if (_Test-IsScalar -Value $Value) { return "$Value" }
    # Nested container -> compact JSON, truncated, so tables stay readable.
    try {
        $j = $Value | ConvertTo-Json -Depth 2 -Compress
        if ($j.Length -gt 80) { $j = $j.Substring(0, 77) + '...' }
        return $j
    } catch {
        return "$Value"
    }
}

function _Render-KeyValue {
    <#
    .SYNOPSIS
        Renders one labelled key/value pair, recursing for nested structures.
    #>
    param([string] $Label, $Value, [int] $Indent)
    $pad = '  ' * $Indent

    if ($null -eq $Value) { Write-Host "$pad$Label`: (none)"; return }
    if (_Test-IsScalar -Value $Value) {
        $display = if ("$Value" -eq '') { '(empty)' } else { "$Value" }
        Write-Host "$pad$Label`: $display"
        return
    }

    # Nested object: print the label as a header, then recurse indented.
    Write-Host "$pad$Label`:"
    _Format-HumanReadable -InputObject $Value -Indent ($Indent + 1)
}

function _Format-TableFromObjects {
    <#
    .SYNOPSIS
        Renders an array of flat objects as a plain-text, log-friendly table.
    #>
    param([object[]] $Rows, [int] $Indent = 0)

    $pad = '  ' * $Indent

    $cols = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Rows) {
        $keys = if ($r -is [System.Collections.IDictionary]) { @($r.Keys) } else { @($r.PSObject.Properties.Name) }
        foreach ($k in $keys) { if ($cols -notcontains $k) { $cols.Add($k) } }
        if ($cols.Count -ge 8) { break }
    }
    if ($cols.Count -eq 0) { Write-Host "$pad(empty)"; return }

    $widths = @{}
    foreach ($c in $cols) { $widths[$c] = [Math]::Max($c.Length, 8) }

    $maxRows = [Math]::Min($Rows.Count, 50)
    for ($i = 0; $i -lt $maxRows; $i++) {
        $r = $Rows[$i]
        foreach ($c in $cols) {
            $v = if ($r -is [System.Collections.IDictionary]) { $r[$c] } else { $r.$c }
            $s = _Stringify-Cell $v
            if ($s.Length -gt 38) { $s = $s.Substring(0, 35) + '...' }
            if ($s.Length -gt $widths[$c]) { $widths[$c] = $s.Length }
        }
    }

    $header = ($cols | ForEach-Object { $_.PadRight($widths[$_]) }) -join '  '
    Write-Host "$pad$header"
    Write-Host "$pad$(($cols | ForEach-Object { '-' * $widths[$_] }) -join '  ')"

    for ($i = 0; $i -lt $maxRows; $i++) {
        $r = $Rows[$i]
        $line = ($cols | ForEach-Object {
            $v = if ($r -is [System.Collections.IDictionary]) { $r[$c] } else { $r.$c }
            $s = _Stringify-Cell $v
            if ($s.Length -gt 38) { $s = $s.Substring(0, 35) + '...' }
            $s.PadRight($widths[$_])
        }) -join '  '
        Write-Host "$pad$line"
    }
    if ($Rows.Count -gt $maxRows) {
        Write-Host "$pad... ($($Rows.Count - $maxRows) more rows)"
    }
}

function _Format-HumanReadable {
    <#
    .SYNOPSIS
        Recursively renders any structured object as indented, labelled
        lists and tables - the human-readable form for screen / log output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object] $InputObject,
        [string] $Title,
        [int] $Indent = 0
    )
    process {
        $pad = '  ' * $Indent
        if ($Title) { Write-Host "$pad$Title" }

        $value = $InputObject
        if ($null -eq $value) { Write-Host "$pad(none)"; return }

        # Dictionary / hashtable  -> labelled list (recursing into nested values)
        if ($value -is [System.Collections.IDictionary]) {
            foreach ($key in $value.Keys) {
                _Render-KeyValue -Label (_ConvertTo-FriendlyLabel $key) -Value $value[$key] -Indent $Indent
            }
            return
        }

        # PSCustomObject / PSObject -> labelled list of its note properties
        if ($value -is [PSCustomObject] -or $value -is [PSObject]) {
            foreach ($prop in $value.PSObject.Properties) {
                _Render-KeyValue -Label (_ConvertTo-FriendlyLabel $prop.Name) -Value $prop.Value -Indent $Indent
            }
            return
        }

        # Collection (array / list) that is not a string -> table or bullet list
        if (($value -is [System.Collections.ICollection]) -and -not ($value -is [string])) {
            if ($value.Count -eq 0) { Write-Host "$pad(empty)"; return }
            $first = $value | Select-Object -First 1
            $isObjectRow = ($first -is [System.Collections.IDictionary]) -or
                           ($first -is [PSObject]) -or ($first -is [PSCustomObject])
            if ($isObjectRow) {
                _Format-TableFromObjects -Rows $value -Indent $Indent
            } else {
                foreach ($item in $value) { Write-Host "$pad  - $item" }
            }
            return
        }

        # Plain scalar
        Write-Host "$pad$value"
    }
}

function _Publish-Result {
    <#
    .SYNOPSIS
        Single DRY entry point every command calls to emit its result.

    .DESCRIPTION
        By default it writes a human-readable report (via _Format-HumanReadable,
        or a command-supplied -CustomView) and returns NOTHING on the success
        stream, so the operator never sees a truncated raw hashtable dump in the
        terminal or logs.

          * -Json     -> emit the result as a JSON string on the success stream
          * -PassThru -> also return the raw object on the success stream
          * -Quiet    -> suppress the human-readable report (caller handles display)
          * -CustomView { param($r) ... } -> use a rich, command-specific renderer

        Use -PassThru (or capture into a variable) for scripting; use -Json for
        API / redirection consumers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Result,
        [string] $Title,
        [switch] $Json,
        [switch] $PassThru,
        [switch] $Quiet,
        [scriptblock] $CustomView,
        [int] $Depth = 6
    )

    if ($Json) {
        $Result | ConvertTo-Json -Depth $Depth -Compress
        return
    }

    if (-not $Quiet) {
        if ($CustomView) {
            & $CustomView $Result
        } else {
            _Format-HumanReadable -InputObject $Result -Title $Title
        }
    }

    if ($PassThru) { return $Result }
}

function _ConvertTo-IloIpAddressList {
    <#
    .SYNOPSIS
        Extracts every iLO / management IP address from a OneView server-hardware
        object (or directly from its mpIpAddresses value), tolerating the different
        shapes OneView returns across versions:
          - a string[]                                      (e.g. @('10.0.0.1'))
          - an array of @{ ipAddress = …; type = … } / @{ address = … } objects
          - an mpHostInfo sub-object holding mpIpAddresses
          - a top-level iloIpAddress / managementIP property
        Every candidate value is scanned for an IPv4/IPv6-looking string, so the
        column is never blank just because OneView renamed the property.
    #>
    [CmdletBinding()]
    param($ServerOrMpIpAddresses)

    $ipPattern = '\b(?:\d{1,3}\.){3}\d{1,3}\b|\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}\b'
    $out = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $ServerOrMpIpAddresses) { return $out }

    $sets = [System.Collections.Generic.List[object]]::new()
    if ($ServerOrMpIpAddresses.PSObject -and $ServerOrMpIpAddresses.PSObject.Properties.Name -contains 'mpIpAddresses') {
        $s = $ServerOrMpIpAddresses
        if ($s.mpIpAddresses)                               { $sets.Add($s.mpIpAddresses) }
        if ($s.mpHostInfo -and $s.mpHostInfo.mpIpAddresses) { $sets.Add($s.mpHostInfo.mpIpAddresses) }
        if ($s.iloIpAddress)                               { $sets.Add($s.iloIpAddress) }
        if ($s.managementIP)                               { $sets.Add($s.managementIP) }
    } else {
        $sets.Add($ServerOrMpIpAddresses)
    }

    foreach ($set in $sets) {
        if ($null -eq $set) { continue }
        if ($set -isnot [System.Collections.ICollection]) { $set = @($set) }
        foreach ($entry in $set) {
            if ($null -eq $entry) { continue }
            if ($entry -is [string]) {
                if ($entry -match $ipPattern) { $out.Add($entry) }
                continue
            }
            $values = if ($entry -is [System.Collections.IDictionary]) { $entry.Values } else { $entry.PSObject.Properties.Value }
            foreach ($val in $values) {
                if ($val -is [string] -and $val -match $ipPattern) { $out.Add($val) }
            }
        }
    }
    return $out
}
