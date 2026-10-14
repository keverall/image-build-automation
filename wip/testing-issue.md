## Table of Contents

Run this on the Windows client after:

```powershell
make setup
```

Open a **new PowerShell 7 session** first so the user module path is refreshed, then run:

```powershell
$ErrorActionPreference = 'Stop'

$required = @(
    @{ Name = 'HPEOneView.1000'; Version = '10.0.4265.2221' },
    @{ Name = 'HPRESTCmdlets';   Version = '1.2.0.0' }
)

foreach ($item in $required) {
    $module = Get-Module -ListAvailable -Name $item.Name |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $module) {
        throw "Missing module: $($item.Name)"
    }

    if ([version]$module.Version -lt [version]$item.Version) {
        throw "Module $($item.Name) is too old: $($module.Version)"
    }

    Import-Module $module.Path -Force -ErrorAction Stop

    [pscustomobject]@{
        Name       = $module.Name
        Version    = $module.Version
        Path       = $module.Path
        Imported   = [bool](Get-Module -Name $module.Name)
    }
}

$commands = @(
    'Get-OVServer',
    'Get-OVIloSso',
    'Get-HPRESTDataRaw',
    'Set-HPRESTData',
    'Invoke-HPRESTAction',
    'Get-HPRESTError'
)

foreach ($command in $commands) {
    $found = Get-Command $command -ErrorAction SilentlyContinue
    if (-not $found) {
        throw "Missing required command: $command"
    }

    [pscustomobject]@{
        Command = $command
        Module  = $found.Source
        Status  = 'Available'
    }
}

'MODULE CHECK PASSED'
```

A shorter inspection command is:

```powershell
Get-Module -ListAvailable HPEOneView.1000, HPRESTCmdlets |
    Sort-Object Name, Version -Descending |
    Format-Table Name, Version, Path -AutoSize
```

The expected result must include:

```text
HPEOneView.1000   10.0.4265.2221
HPRESTCmdlets     1.2.0.0
```

The vendored HPREST package is now located at:

```text
scripts/modules/HPRESTCmdlets/1.2.0.0/
```

`make setup` requires that offline package and will fail clearly if it is missing; it no longer depends on PSGallery for `HPRESTCmdlets`.
