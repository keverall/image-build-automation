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
# The old block trusted whatever SSH_AUTH_SOCK was lying around from a
# previous session / VDI reconnect and parsed ssh-agent's output with a regex
# that swallowed the surrounding single quotes, so the socket path came out
# malformed ('C:\...\agent.sock) and ssh could never open it. The key was
# therefore never offered and every push failed with
#   git@gitstash.aib.pri: permission denied (publickey)
# until the key was re-registered on the server.
#
# This spawns a *fresh* agent every profile load, strips quotes correctly,
# and re-adds the key, so the working socket + loaded key are guaranteed at
# startup. A dead socket can no longer masquerade as a live agent.
# ---------------------------------------------------------------------------

$gitSshPath = "$env:USERPROFILE/AppData/Local/Programs/Git/usr/bin"

if ($env:PATH -notlike "*$gitSshPath*")
{
    $env:PATH += ";$gitSshPath"
}

# Ensure Git uses Git-for-Windows SSH, not Windows OpenSSH
$env:GIT_SSH = "$gitSshPath/ssh.exe"

# Spawn a fresh agent. ssh-agent -s prints lines like
#   export SSH_AUTH_SOCK='C:\Users\...\.ssh\agent.sock';
#   export SSH_PID=1234;
# We parse and strip the surrounding quotes so the socket path is exact.
$agentOutput = & "$gitSshPath/ssh-agent.exe" -s 2>$null

foreach ($line in $agentOutput)
{
    if ($line -match '^\s*(?:export\s+)?(\w+)=(.+)$')
    {
        $val = $matches[2].Trim().TrimEnd(';').Trim("'").Trim('"')
        if ($val)
        {
            Set-Item -Path "Env:$($matches[1])" -Value $val -ErrorAction SilentlyContinue
        }
    }
}

# Never let a per-command GIT_SSH_COMMAND override bypass the agent above.
Remove-Item Env:GIT_SSH_COMMAND -ErrorAction SilentlyContinue

# Guarantee the key is loaded into the *current* agent, every profile load.
# A lingering agent from a previous session is not trusted: it may have
# dropped the key, so we verify and re-add if absent. This is what stops the
# daily "agent outlived its key -> permission denied (publickey)" drift.
$keyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"

if (Test-Path $keyPath)
{
    $present = & "$gitSshPath/ssh-add.exe" -l 2>$null |
        Where-Object { $_ -match 'ED25519' } |
        Select-Object -First 1

    if (-not $present)
    {
        & "$gitSshPath/ssh-add.exe" $keyPath 2>$null
    }
}

# Diagnostics: distinguishes client (agent/socket/key) from server-side
# key invalidation. Run `sshdiag` after a failed push.
function global:sshdiag
{
    $sock = $env:SSH_AUTH_SOCK
    "SSH_AUTH_SOCK = $sock"
    if (-not $sock) { "  -> no agent socket set (agent did not start)" ; return }

    if (-not (Test-Path $sock)) { "  -> socket file missing (stale pointer)" ; return }

    $keys = & "$gitSshPath/ssh-add.exe" -l 2>$null
    if ($LASTEXITCODE -ne 0) { "  -> agent reachable but ssh-add -l failed (exit $LASTEXITCODE)" ; return }

    if ($keys -match 'ED25519') { "  -> key LOADED: $($keys -join ' | ')" }
    else { "  -> agent alive but NO key loaded (re-add needed)" }
}

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
