#
# Private/Help.ps1 - Man-page style help for module commands
#
# Provides Get-CommandHelp (exported) which renders a `man`-like reference for any
# command in the module: synopsis, syntax per parameter set, and a parameter table
# showing mandatory/optional status, type, default value, aliases, pipeline input,
# and the allowed values (ValidateSet / enum / ValidateRange / ValidatePattern).
#
# Internal helper _ShouldShowHelp is used at the top of every main command body so
# that `Get-OneViewServerList -Help` (and the module command's own -Help switch)
# short-circuits to the renderer instead of running the command.
#

function Get-CommandHelp {
    <#
    .SYNOPSIS
        Display man-page style help for an Automation module command.

    .DESCRIPTION
        Renders a `man`-like reference for any command exported by (or loaded in)
        the Automation module. It shows the synopsis, one syntax line per parameter
        set, and a parameter table with mandatory/optional status, parameter type,
        default value, aliases, pipeline input, and the values allowed by
        validation attributes (ValidateSet, enum, ValidateRange, ValidatePattern).

        This is the engine behind the `-Help` switch on every main command, so
        `Get-OneViewServerList -Help` and `Get-CommandHelp Get-OneViewServerList`
        produce the same output.

    .PARAMETER Name
        The name of the command to document (e.g. Get-OneViewServerList).

    .EXAMPLE
        Get-CommandHelp Get-OneViewServerList

    .EXAMPLE
        Get-OneViewServerList -Help
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Name
    )

    # ── ANSI palette (Write-Output, not Write-Host, to satisfy PSAvoidUsingWriteHost) ──
    $cReset  = "$([char]27)[0m"
    $cBold   = "$([char]27)[1m"
    $cCyan   = "$([char]27)[36m"
    $cGreen  = "$([char]27)[32m"
    $cYellow = "$([char]27)[33m"
    $cGray   = "$([char]27)[90m"
    $cRed    = "$([char]27)[31m"

    $cmd = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Output "${cRed}No command named '$Name' was found.${cReset}"
        return
    }

    $help = Get-Help -Name $Name -ErrorAction SilentlyContinue
    if (-not $help) { $help = [PSCustomObject]@{} }

    $out = [System.Collections.Generic.List[string]]::new()
    $add = { param([string]$s) $out.Add($s) }.GetNewClosure()

    # ── NAME ────────────────────────────────────────────────────────────────────
    & $add "${cBold}${cCyan}NAME${cReset}"
    & $add "    $($cmd.Name)"
    & $add ""

    # ── SYNOPSIS ──────────────────────────────────────────────────────────────────
    $synopsis = if ($help.PSObject.Properties['Synopsis']) { "$($help.Synopsis)".Trim() } else { '' }
    if ($synopsis) {
        & $add "${cBold}${cCyan}SYNOPSIS${cReset}"
        foreach ($line in ($synopsis -split "`n")) { & $add "    $line" }
        & $add ""
    }

    # ── SYNTAX (one usage line per parameter set) ──────────────────────────────────
    & $add "${cBold}${cCyan}SYNTAX${cReset}"
    $commonParams = @(
        'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
        'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable',
        'OutBuffer', 'PipelineVariable', 'ProgressAction', 'Confirm', 'WhatIf'
    )
    foreach ($set in $cmd.ParameterSets) {
        $segments = [System.Collections.Generic.List[string]]::new()
        $segments.Add("$($cmd.Name)")
        foreach ($p in $set.Parameters) {
            if ($p.Name -in $commonParams) { continue }
            $typeName = if ($p.ParameterType.Name -eq 'SwitchParameter') { 'switch' } else { $p.ParameterType.Name }
            $seg = if ($p.IsMandatory) {
                "-$($p.Name) <$typeName>"
            } else {
                "[-$($p.Name) <$typeName>]"
            }
            $segments.Add($seg)
        }
        $segments.Add('[<CommonParameters>]')
        & $add ("    " + ($segments -join ' '))
    }
    & $add ""

    # ── DESCRIPTION ────────────────────────────────────────────────────────────────
    $desc = $help.PSObject.Properties['Description']
    if ($desc -and $desc.Value) {
        & $add "${cBold}${cCyan}DESCRIPTION${cReset}"
        foreach ($block in $desc.Value) {
            $text = if ($block.PSObject.Properties['Text']) { "$($block.Text)".Trim() } else { "$block".Trim() }
            if ($text) { foreach ($line in ($text -split "`n")) { & $add "    $line" } }
        }
        & $add ""
    }

    # ── PARAMETERS ──────────────────────────────────────────────────────────────────
    & $add "${cBold}${cCyan}PARAMETERS${cReset}"

    # Map of help descriptions keyed by parameter name (from comment-based help).
    $helpDesc = @{}
    if ($help.PSObject.Properties['Parameters'] -and $help.Parameters) {
        foreach ($hp in $help.Parameters) {
            $txt = ''
            if ($hp.Description) {
                foreach ($b in $hp.Description) {
                    $txt += if ($b.PSObject.Properties['Text']) { "$($b.Text) " } else { "$b " }
                }
            }
            if ($hp.Name) {
                $helpDesc[$hp.Name] = $txt.Trim()
            }
        }
    }

    $docParams = $cmd.Parameters.Values | Where-Object { $_.Name -notin $commonParams }
    # Preserve declaration order from the command's metadata where possible.
    foreach ($p in $docParams) {
        $typeName = if ($p.ParameterType.Name -eq 'SwitchParameter') { 'switch' } else { $p.ParameterType.Name }
        $isMandatory = ($p.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }) -ne $null
        $status = if ($isMandatory) { "${cRed}mandatory${cReset}" } else { "${cGreen}optional${cReset}" }

        & $add "    ${cYellow}-$($p.Name)${cReset} <$typeName>  [$status]"

        # Description from comment-based help.
        $descText = $helpDesc[$p.Name]
        if ($descText) {
            foreach ($line in ($descText -split "`n")) { & $add "        $line" }
        }

        # Type
        & $add "        ${cGray}Type     : $typeName$(if ($p.ParameterType.IsEnum) { ' (enum)' })${cReset}"

        # Default value
        $def = $p.DefaultValue
        $defStr = if ($null -eq $def) { '(none)' } elseif ($def -is [bool]) { '$' + $def } else { "$def" }
        & $add "        ${cGray}Default  : $defStr${cReset}"

        # Position
        $posAttr = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Position -ge 0 } | Select-Object -First 1
        $posStr = if ($posAttr) { "named ($($posAttr.Position))" } else { 'named' }
        & $add "        ${cGray}Position : $posStr${cReset}"

        # Aliases
        $aliases = @($p.Aliases | Where-Object { $_ -and $_ -ne $p.Name })
        if ($aliases.Count -gt 0) {
            & $add "        ${cGray}Aliases  : $($aliases -join ', ')${cReset}"
        }

        # Pipeline input
        $vb = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and ($_.ValueFromPipeline -or $_.ValueFromPipelineByPropertyName) } | Select-Object -First 1
        if ($vb) {
            $pipe = @()
            if ($vb.ValueFromPipeline) { $pipe += 'by Value' }
            if ($vb.ValueFromPipelineByPropertyName) { $pipe += 'by PropertyName' }
            & $add "        ${cGray}Pipeline : $($pipe -join ', ')${cReset}"
        }

        # Allowed values: ValidateSet / enum / ValidateRange / ValidatePattern
        $allowed = [System.Collections.Generic.List[string]]::new()
        $vs = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        foreach ($a in $vs) {
            if ($a.ValidValues -and $a.ValidValues.Count -gt 0) {
                $allowed.Add(($a.ValidValues -join ' | '))
            }
        }
        if ($p.ParameterType.IsEnum) {
            $allowed.Add(([enum]::GetNames($p.ParameterType) -join ' | '))
        }
        $vr = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] } | Select-Object -First 1
        if ($vr) {
            $min = if ($vr.PSObject.Properties['MinRange']) { $vr.MinRange } else { $null }
            $max = if ($vr.PSObject.Properties['MaxRange']) { $vr.MaxRange } else { $null }
            $allowed.Add("range: $min .. $max")
        }
        $vp = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] } | Select-Object -First 1
        if ($vp) {
            $allowed.Add("pattern: $($vp.Pattern)")
        }
        if ($allowed.Count -gt 0) {
            & $add "        ${cCyan}Allowed  : $($allowed -join '; ')${cReset}"
        }

        & $add ""
    }

    # ── EXAMPLES ────────────────────────────────────────────────────────────────────
    if ($help.PSObject.Properties['Examples'] -and $help.Examples) {
        & $add "${cBold}${cCyan}EXAMPLES${cReset}"
        foreach ($ex in $help.Examples) {
            $title = if ($ex.PSObject.Properties['Title']) { "$($ex.Title)".Trim() } else { '' }
            $code  = if ($ex.PSObject.Properties['Code'])  { "$($ex.Code)".Trim() }  else { '' }
            $remarks = if ($ex.PSObject.Properties['Remarks']) { "$($ex.Remarks)".Trim() } else { '' }
            if ($title) { & $add "    ${cBold}$title${cReset}" }
            if ($code)  { & $add "        $code" }
            if ($remarks) { & $add "        ${cGray}$remarks${cReset}" }
            & $add ""
        }
    }

    # ── NOTES ──────────────────────────────────────────────────────────────────────
    & $add "${cGray}Tip: pass -Help to any main command (e.g. '$($cmd.Name) -Help') to show this reference.${cReset}"

    Write-Output ($out -join "`n")
}
