#
# FileIO.psm1 — File I/O utilities: directory creation, JSON persistence, timestamped results.
#

function Ensure-DirectoryExists {
    <#
    .SYNOPSIS
        Create a directory (and parents) if it does not exist. Returns the path.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string] $Path)
    if (-not (Test-Path $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    return $Path
}

function Save-Json {
    <#
    .SYNOPSIS
        Save a hashtable / object as a UTF-8 JSON file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)] $Data,
        [Parameter(Mandatory, Position = 1)][string] $Path,
        [int] $Depth = 64
    )
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { Ensure-DirectoryExists $dir }
    $Data | ConvertTo-Json -Depth $Depth | Set-Content -Path $Path -Encoding UTF8 -Force
    return $Path
}

function Load-Json {
    <#
    .SYNOPSIS
        Load JSON from a file and return a hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Path,
        [bool] $Required = $true
    )
    if (-not (Test-Path $Path -PathType Leaf)) {
        if ($Required) { throw "Required JSON file not found: $Path" }
        return @{}
    }
    $raw = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 64
    return _FileIO_DeepHashtable $raw
}

function Save-JsonResult {
    <#
    .SYNOPSIS
        Save result JSON with a timestamped filename in an optional category sub-directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)] $Data,
        [Parameter(Mandatory, Position = 1)][string] $BaseName,
        [string] $OutputDir = 'logs',
        [string] $Category  = $null
    )
    $ts  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $dir = if ($Category) { [System.IO.Path]::Combine($OutputDir, $Category) } else { $OutputDir }
    Ensure-DirectoryExists $dir
    $fp  = [System.IO.Path]::Combine($dir, "$BaseName`_$ts.json")
    return Save-Json -Data $Data -Path $fp
}

function Test-PathEx {
    <#
    .SYNOPSIS
        Boolean path existence test (avoids pipeline noise).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Path,
        [ValidateSet('Any','Leaf','Container')][string] $PathType = 'Leaf'
    )
    switch ($PathType) {
        'Leaf'      { return [bool](Test-Path $Path -PathType Leaf) }
        'Container' { return [bool](Test-Path $Path -PathType Container) }
        default     { return [bool](Test-Path $Path) }
    }
}

# Private deep-convert PSCustomObject → hashtable
function _FileIO_DeepHashtable {
    param([Parameter(ValueFromPipeline)] $Obj)
    process {
        if ($null -eq $Obj) { return $null }
        if ($Obj -is [System.Collections.IDictionary]) {
            $ht = @{}
            foreach ($k in $Obj.Keys) { $ht[$k] = _FileIO_DeepHashtable $Obj[$k] }
            return $ht
        }
        if ($Obj -is [System.Collections.IEnumerable] -and $Obj -isnot [string]) {
            return ,@($Obj | ForEach-Object { _FileIO_DeepHashtable $_ })
        }
        return $Obj
    }
}

# vim: ts=4 sw=4 et
