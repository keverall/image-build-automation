# =============================================================================
# PowerShell Profile — Windows Terminal (Windows Server)
# =============================================================================
# Fast load, coding productivity, stability. Loaded automatically by pwsh.
# eis19profile.ps1 and techvdi-profile.ps1 must stay IDENTICAL apart from the
# proxy block below — keep both in sync; only techvdi carries proxy settings.
# =============================================================================
# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

$env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') +
    ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

$env:HOME = $env:USERPROFILE

# ---------------------------------------------------------------------------
# Corporate Proxy (VDI only)
# ---------------------------------------------------------------------------

$env:HTTP_PROXY  = "http://webcorp.prd.aib.pri:8082"
$env:HTTPS_PROXY = "http://webcorp.prd.aib.pri:8082"

# $env:NO_PROXY = "localhost,127.0.0.1,*.ad.aib.pri,*.aib.pri,10.*"

# ---------------------------------------------------------------------------
# Git SSH Configuration (Agent-Based Authentication)
# ---------------------------------------------------------------------------

$gitSshPath = "$env:USERPROFILE/AppData/Local/Programs/Git/usr/bin"

if ($env:PATH -notlike "*$gitSshPath*")
{
    $env:PATH += ";$gitSshPath"
}

# Ensure Git uses Git-for-Windows SSH, not Windows OpenSSH
$env:GIT_SSH = "$gitSshPath/ssh.exe"

$agentOK = $false

if ($env:SSH_AUTH_SOCK)
{
    & "$gitSshPath/ssh-add.exe" -l *> $null
    $agentOK = ($LASTEXITCODE -eq 0)
}

if (-not $agentOK)
{
    $agentOutput = & "$gitSshPath/ssh-agent.exe" -s

    foreach ($line in $agentOutput)
    {
        if ($line -match '^(\w+)=(.+?);')
        {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
        }
    }

}


# Ensure key exists
$keyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"

if (Test-Path $keyPath)
{
    $keyLoaded = $false

    $loadedKeys = & "$gitSshPath/ssh-add.exe" -l 2>$null

    if ($LASTEXITCODE -eq 0)
    {
        $keyLoaded = $loadedKeys -match "ED25519"
    }

    if (-not $keyLoaded)
    {
        & "$gitSshPath/ssh-add.exe" $keyPath
    }
}

# Explicitly remove any direct-key overrides
Remove-Item Env:GIT_SSH_COMMAND -ErrorAction SilentlyContinue

# ─── Modules ─────────────────────────────────────────────────────────────────
# posh-git is intentionally not imported: it recomputes git status on every
# prompt, duplicating what oh-my-posh's prompt segment already does.
function Import-ModuleSafe
{
    param([string]$Name)
    if (Get-Module $Name -ListAvailable -ErrorAction SilentlyContinue)
    {
        Import-Module $Name -ErrorAction SilentlyContinue
    }
}
Import-ModuleSafe z 
Import-ModuleSafe Terminal-Icons

# ─── Prompt ──────────────────────────────────────────────────────────────────
$ohMyPoshConfigs = @(
    (Join-Path $HOME 'products/pwsh10k.omp.json'),
    '/usr/share/oh-my-posh/themes/pwsh10k.omp.json',
    (Join-Path $HOME '.local/share/oh-my-posh/themes/pwsh10k.omp.json'),
    '/opt/homebrew/share/oh-my-posh/themes/pwsh10k.omp.json',
    '/usr/local/share/oh-my-posh/themes/pwsh10k.omp.json',
    (Join-Path $HOME '.poshthemes/pwsh10k.omp.json')
)
$ohMyPoshConfig = $ohMyPoshConfigs | Where-Object { Test-Path $_ } | Select-Object -First 1
$ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue

if ($ohMyPosh -and $ohMyPoshConfig)
{
    & $ohMyPosh.Source init pwsh --config $ohMyPoshConfig | Invoke-Expression
}
else
{
    # Fallback prompt when oh-my-posh is unavailable (e.g. AppLocker-blocked).
    function global:prompt
    {
        $host.UI.RawUI.WindowTitle = "Automation: $(Get-Location)"
        Write-Host ($PWD.Path -replace '\\', '/') -NoNewline -ForegroundColor Cyan
        $branch = if (Get-Command git -ErrorAction SilentlyContinue) { git branch --show-current 2>$null }
        if ($branch) { Write-Host " ($branch)" -NoNewline -ForegroundColor Yellow }
        Write-Host " ❯ " -NoNewline -ForegroundColor Cyan
        return " "
    }
}

# ─── PSReadLine ──────────────────────────────────────────────────────────────
# Inline history prediction is off: it polls the history file on every
# keystroke and stalls input on a slow VDI. Arrow-key recall is kept — it's
# cheap and only runs on demand.
if ($PSVersionTable.PSVersion.Major -ge 7) { Set-PSReadLineOption -PredictionSource None }
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -MaximumHistoryCount 1000 -HistoryNoDuplicates
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ─── Aliases ─────────────────────────────────────────────────────────────────
Set-Alias cat  Get-Content  -Option AllScope -Force
Set-Alias rm   Remove-Item  -Option AllScope -Force
Set-Alias mv   Move-Item    -Option AllScope -Force
Set-Alias ps   Get-Process  -Option AllScope -Force
Set-Alias kill Stop-Process -Option AllScope -Force

if (Get-Command eza -ErrorAction SilentlyContinue)
{
    $ezaCmd = if ($IsWindows) { 'eza.exe' } else { 'eza' }
    # PowerShell hashtable keys are case-insensitive (la/lA would collide), so
    # this is a plain list of (alias, args) pairs instead.
    $ezaAliases = @(
        @('ls',  '--icons=auto --color=always'),
        @('ll',  '-lhG --icons=auto --color=always'),
        @('la',  '-lag --icons=auto --color=always'),
        @('lA',  '-lAg --icons=auto --color=always'),
        @('laa', '-aalg --icons=auto --color=always'),
        @('ld',  '-lD --icons=auto --color=always'),
        @('lt1', '-l --tree --level=1 --icons=auto --color=always'),
        @('lt2', '-l --tree --level=2 --icons=auto --color=always'),
        @('lt3', '-l --tree --level=3 --icons=auto --color=always')
    )
    if (Test-Path alias:ls) { Remove-Item alias:ls -Force }
    foreach ($pair in $ezaAliases)
    {
        $name, $argStr = $pair
        $fn = "eza_$name"
        Set-Item -Path "Function:global:$fn" -Value ([scriptblock]::Create("& $ezaCmd $argStr `$args"))
        Set-Alias -Name $name -Value $fn -Force -Option AllScope
    }
}

function Open-Docs      { Set-Location (Join-Path $HOME 'Documents') }
function Open-Downloads { Set-Location (Join-Path $HOME 'Downloads') }
function Open-Desktop   { Set-Location (Join-Path $HOME 'Desktop') }
Set-Alias docs    Open-Docs
Set-Alias dl      Open-Downloads
Set-Alias desktop Open-Desktop

function gst { git status @args }
function gpl { git pull @args }
function gps { git push @args }
function gco { param([string]$branch) git checkout $branch @args }
function gcm { param([string]$message) git commit -m $message @args }
function gba { git branch -a @args }

# ─── Editor ──────────────────────────────────────────────────────────────────
$notepadPlusPlus = 'C:\Program Files\Notepad++\notepad++.exe'
if (Test-Path $notepadPlusPlus)
{
    try
    {
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $env:EDITOR = '{0} -nosession' -f $fso.GetFile($notepadPlusPlus).ShortPath.Replace('\', '/')
    }
    catch { $env:EDITOR = 'notepad' }
}

# ─── Argument Completers ─────────────────────────────────────────────────────
if (Get-Command winget -ErrorAction SilentlyContinue)
{
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $word = $wordToComplete.Replace('"', '""')
        $ast  = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$word" --commandline "$ast" --position $cursorPosition |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
if (Get-Command dotnet -ErrorAction SilentlyContinue)
{
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

# ─── Defaults & Utilities ────────────────────────────────────────────────────
$PSDefaultParameterValues['Out-File:Encoding']    = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

function Refresh-Profile { . $PROFILE }
Set-Alias reload Refresh-Profile

function Edit-Profile
{
    if ($env:EDITOR) { & $env:EDITOR.Split(' ')[0] $PROFILE } else { code $PROFILE }
}

function Refresh-Path
{
    if ($IsWindows)
    {
        $env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') +
            ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    }
}
Set-Alias rpath Refresh-Path

# ─── Image Build Automation / HPE OneView ───────────────────────────────────
# Repo root differs per host (eis19: products/repos, VDI: repos) — try both
# so this line is identical on every machine.
$ibaRepo = @(
    (Join-Path $env:USERPROFILE 'products/repos/image-build-automation'),
    (Join-Path $env:USERPROFILE 'repos/image-build-automation')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ibaRepo)
{
    $automationModulePath = Join-Path $ibaRepo 'src/powershell/Automation/Automation.psd1'
    if (Test-Path $automationModulePath) { Import-Module $automationModulePath -WarningAction SilentlyContinue }
}

# HPEOneView.1000 only — stray versions (.820/.860) are rejected by
# Connect-OneViewSession's module guard. No-op where the module isn't installed.
if ($IsWindows) { Import-Module HPEOneView.1000 -ErrorAction SilentlyContinue }
