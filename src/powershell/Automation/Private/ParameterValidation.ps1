#
# ParameterValidation.ps1 - shared, single-source parameter-usage guard.
#
# DevOPS KISS: one location, consistent, maintainable, reliable. Every command
# that can receive a free-form string value (host, serial, path, name) calls
# Assert-ParameterNotFlag so a malformed call fails fast with a clear message
# instead of silently misbehaving.
#
# Why this exists: in PowerShell, '--name' means "end of parameters", so a typo
# like '--DryRun' is swallowed and bound as a LITERAL value to a string
# parameter (e.g. -ManagementHost) instead of being rejected. For destructive
# OneView / MCM commands that must never act on a bogus value, this is unsafe.
# This guard rejects any string parameter value that looks like a flag.

function Assert-ParameterNotFlag {
    <#
    .SYNOPSIS
        Reject parameter values that look like PowerShell parameter flags.

    .DESCRIPTION
        Iterates the command's bound parameters and throws a clear, actionable
        error if any string value starts with '-' (e.g. '--DryRun' or '-DryRun'
        passed where a real value was expected). This catches the
        "end-of-parameters" swallowing trap and prevents a destructive command
        from proceeding with a bogus host/serial/name.

    .PARAMETER Parameters
        The command's $PSBoundParameters hashtable.
    #>
    [CmdletBinding()]
    param(
        [hashtable] $Parameters
    )

    if (-not $Parameters -or $Parameters.Count -eq 0) { return }

    foreach ($key in @($Parameters.Keys)) {
        $values = $Parameters[$key]
        if ($null -eq $values) { continue }

        # Normalise scalars and collections to an enumerable of values.
        if (($values -isnot [System.Collections.IEnumerable]) -or ($values -is [string])) {
            $values = @($values)
        }

        foreach ($v in $values) {
            if ($v -is [string] -and $v.StartsWith('-')) {
                throw "Invalid value for parameter -$key : '$v'. It looks like a parameter flag (e.g. '--DryRun'). PowerShell parameters use a single dash - use '-$key' correctly; supply a real value that does not start with '-'."
            }
        }
    }
}
