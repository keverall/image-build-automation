# =============================================================================
# PowerShell Profile — Windows Terminal (Windows Server)
$env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') +
    ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

$env:HOME = $env:USERPROFILE
$env:HTTP_PROXY  = "http://webcorp.prd.aib.pri:8082"
$env:HTTPS_PROXY = "http://webcorp.prd.aib.pri:8082"

$gitSshPath = "$env:USERPROFILE/AppData/Local/Programs/Git/usr/bin"

if ($env:PATH -notlike "*$gitSshPath*")
{
    $env:PATH += ";$gitSshPath"
}

$env:GIT_SSH = "$gitSshPath/ssh.exe"

# Use a FIXED socket path so the pointer can't be orphaned by a
# random-per-session socket that dies when the terminal/VDI recycles.
$agentSockDir = Join-Path $env:USERPROFILE ".ssh\agent"
$agentSockPath = Join-Path $agentSockDir "ssh-agent.sock"

# Reuse an existing, reachable agent instead of spawning a new one every
# profile load (that is what left stale SSH_AUTH_SOCK pointers behind).
$agentAlive = $false
if ($env:SSH_AUTH_SOCK -and (Test-Path $env:SSH_AUTH_SOCK))
{
    & "$gitSshPath/ssh-add.exe" -l 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $agentAlive = $true }
}

if (-not $agentAlive)
{
    # Kill any orphaned agents and clear the socket so it can be rebound.
    Get-Process ssh-agent -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $agentSockPath) { Remove-Item $agentSockPath -Force }
    if (-not (Test-Path $agentSockDir)) { New-Item -ItemType Directory -Path $agentSockDir -Force | Out-Null }

    # -D = daemonize (survive the profile/terminal exiting)
    # -a = bind the fixed socket path
    & "$gitSshPath/ssh-agent.exe" -D -a $agentSockPath 2>$null

    $env:SSH_AUTH_SOCK = $agentSockPath
    Remove-Item Env:SSH_AGENT_PID -ErrorAction SilentlyContinue

    # Confirm the agent actually came up; if not, fall back to -s shell mode.
    if (-not (Test-Path $agentSockPath))
    {
        $agentOutput = & "$gitSshPath/ssh-agent.exe" -s 2>$null
        foreach ($line in $agentOutput)
        {
            if ($line -match '^\s*(?:export\s+)?(\w+)=(.+)$')
            {
                $val = $matches[2].Trim().TrimEnd(';').Trim("'").Trim('"')
                if ($val) { Set-Item -Path "Env:$($matches[1])" -Value $val -ErrorAction SilentlyContinue }
            }
        }
    }
}

# Never let a per-command GIT_SSH_COMMAND override bypass the agent above.
Remove-Item Env:GIT_SSH_COMMAND -ErrorAction SilentlyContinue

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

$ibaRepo = @(
    (Join-Path $env:USERPROFILE 'products/repos/image-build-automation'),
    (Join-Path $env:USERPROFILE 'repos/image-build-automation')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ibaRepo)
{
    $automationModulePath = Join-Path $ibaRepo 'src/powershell/Automation/Automation.psd1'
    if (Test-Path $automationModulePath) { Import-Module $automationModulePath -WarningAction SilentlyContinue }
}

if ($IsWindows) { Import-Module HPEOneView.1000 -ErrorAction SilentlyContinue }
