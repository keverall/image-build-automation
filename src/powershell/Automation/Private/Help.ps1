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

    # ── Command → section anchor in docs/Automation/automation_commands.md ──────────
    # The EXAMPLES section links to the per-command section (via its table-of-contents
    # anchor) in the Automation command reference, which holds the runnable examples.
    $commandDocAnchors = @{
        'Test-ServerConnectivity'      = 'test-oneview-connectivity'
        'Connect-OneView'              = 'connect-to-oneview'
        'Disconnect-OneView'           = 'disconnect-from-oneview'
        'Get-OneViewConnectionStatus'  = 'get-oneview-connection-status'
        'Get-OneViewServerList'        = 'get-oneview-server-list'
        'Test-BuildParams'             = 'validate-build-parameters'
        'Configure-PhysicalBuild'      = 'configure-build-4-eye-review'
        'Start-InstallMonitor'         = 'monitor-installation-progress'
        'Invoke-IloRedfish'            = 'ilo-redfish-operations'
        'Get-OneViewServerTarget'      = 'resolve-server-target-via-oneview'
        'Test-PreBuildValidation'      = 'pre-build-validation'
        'Test-PostBuildValidation'     = 'post-build-validation'
        'Invoke-WindowsSecurityUpdate' = 'patch-windows-iso-with-security-updates'
        'Invoke-OpsRamp'               = 'opsramp-api-client'
        'Set-MaintenanceMode'          = 'maintenance-mode'
        'Enable-OneViewMaintenanceMode'= 'enable-oneview-maintenance-mode'
        'Disable-OneViewMaintenanceMode'= 'disable-oneview-maintenance-mode'
        'Invoke-PowerShellScript'      = 'run-a-local-powershell-script'
        'Invoke-PowerShellWinRM'       = 'run-a-remote-powershell-script-via-winrm'
        'New-Uuid'                     = 'generate-a-deterministic-uuid'
        'Invoke-OpsRampClient'         = 'opsramp-api-client'
        'Start-AutomationOrchestrator' = 'orchestrator-unified-entry-point'
        'Get-RouteMap'                 = 'view-the-route-map'
        'Run-CIPipeline'               = 'control-surface-factories-and-runners'
        'Run-IRequest'                 = 'control-surface-factories-and-runners'
        'Run-Scheduler'                = 'control-surface-factories-and-runners'
        'Run-GitLab'                   = 'control-surface-factories-and-runners'
        'New-CIPipelineCtrl'           = 'control-surface-factories-and-runners'
        'New-IRequestCtrl'             = 'control-surface-factories-and-runners'
        'New-SchedulerCtrl'            = 'control-surface-factories-and-runners'
        'Invoke-GitLabMaintenanceTrigger' = 'gitlab-maintenance-trigger'
    }

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
    $renderSets = [System.Collections.Generic.List[object]]::new()
    foreach ($set in $cmd.ParameterSets) {
        # A -Help-carrying set is an implementation detail of the help switch.
        # Because optional run parameters are not scoped to a named set, they leak
        # into the Help set, so it is NOT Help-only and the naive skip below would
        # render a second, redundant usage line containing [-Help <switch>].
        $setSpecific = @($set.Parameters | Where-Object { $_.Name -notin $commonParams })
        if ($setSpecific.Count -eq 1 -and $setSpecific[0].Name -eq 'Help') { continue }

        $renderSets.Add([PSCustomObject]@{
            Set     = $set
            HasHelp = [bool](@($setSpecific | Where-Object { $_.Name -eq 'Help' }).Count)
        })
    }

    # Drop help-bearing sets when a genuine (non-Help) set exists ...
    if (@($renderSets | Where-Object { -not $_.HasHelp }).Count -gt 0) {
        $renderSets = [System.Collections.Generic.List[object]]::new(@($renderSets | Where-Object { -not $_.HasHelp }))
    }
    # ... otherwise (commands with no dedicated run set) keep exactly one usage line.
    if ($renderSets.Count -gt 1) {
        $renderSets = [System.Collections.Generic.List[object]]::new(@($renderSets[0]))
    }
    # A command that takes nothing but -Help still deserves a usage line.
    if ($renderSets.Count -eq 0) {
        & $add ("    $($cmd.Name) [<CommonParameters>]")
    }

    foreach ($entry in $renderSets) {
        $segments = [System.Collections.Generic.List[string]]::new()
        $segments.Add("$($cmd.Name)")
        foreach ($p in $entry.Set.Parameters) {
            if ($p.Name -in $commonParams) { continue }
            if ($p.Name -eq 'Help') { continue }
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
        # A parameter is "mandatory" for the operator only if it is required in a
        # non-Help parameter set; -Help is mandatory solely to enter its own set.
        $isMandatory = ($p.Attributes | Where-Object {
            $_ -is [System.Management.Automation.ParameterAttribute] -and
            $_.Mandatory -and $_.ParameterSetName -ne 'Help'
        }) -ne $null
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
    # The runnable examples live in the Automation command reference; link to the
    # per-command table-of-contents entry rather than duplicating the examples here.
    # Resolve a full, clickable GitHub blob URL (repo included) when run inside the
    # repo, so the link works straight from a terminal; fall back to a repo-relative
    # path otherwise.
    $docRel  = 'docs/Automation/automation_commands.md'
    # Default to the canonical repo URL so the link is always a full, clickable
    # GitHub blob URL (repo name included), even outside a git checkout. When run
    # inside the repo, the live `git remote` overrides this.
    $docBase = 'https://github.com/keverall/image-build-automation/blob/main/docs/Automation/automation_commands.md'
    try {
        $tl = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
        if ($tl) {
            $remote = & git -C $tl remote get-url origin 2>$null
            if ($remote) {
                $web = $null
                if     ($remote -match '^git@(.+):(.+)$')              { $web = "https://$($Matches[1])/$($Matches[2])" }
                elseif ($remote -match '^ssh://git@(.+):(.+)$')        { $web = "https://$($Matches[1])/$($Matches[2])" }
                elseif ($remote -match '^https?://(.+)$')              { $web = "https://$($Matches[1])" }
                if ($web) { $web = $web -replace '\.git$'; $docBase = "$web/blob/main/$docRel" }
            }
        }
    } catch { }

    $anchor  = $null
    if ($commandDocAnchors.ContainsKey($cmd.Name)) { $anchor = $commandDocAnchors[$cmd.Name] }
    & $add "${cBold}${cCyan}EXAMPLES${cReset}"
    if ($anchor) {
        & $add "    See the Automation command reference for runnable examples:"
        & $add "        ${cCyan}$docBase#$anchor${cReset}"
    } else {
        & $add "    See the Automation command reference (Table of Contents) for runnable examples:"
        & $add "        ${cCyan}$docBase${cReset}"
    }

    # ── NOTES ──────────────────────────────────────────────────────────────────────
    & $add "${cGray}Tip: pass -Help to any main command (e.g. '$($cmd.Name) -Help') to show this reference.${cReset}"

    Write-Output ($out -join "`n")
}
