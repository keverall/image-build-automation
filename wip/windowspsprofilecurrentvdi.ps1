# =============================================================================
# PowerShell Profile — Windows Terminal (Windows Server)
# =============================================================================
# Optimized for fast load, coding productivity, and stability.
# Loaded automatically when PowerShell starts in Windows Terminal.
# =============================================================================

# ─── Fix VS Code PATH Caching (cross-platform) ──────────────────────────────
# VS Code may inherit a stale environment from its launch process.
# This ensures the terminal gets the current system + user PATH.
if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5 -or $null -eq $IsWindows)
{
    # Windows: read directly from registry (Machine + User)
    $env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') +
    ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
} elseif ($IsLinux -or $IsMacOS)
{
    # Linux/macOS: ensure common user bin directories are in PATH
    $sep = [System.IO.Path]::PathSeparator  # ':' on Unix
    $userBins = @(
        "$HOME/.local/bin",
        "$HOME/bin",
        "$HOME/.cargo/bin",
        "$HOME/.bun/bin",
        "$HOME/.nvm/versions/node/*/bin",
        "$HOME/go/bin"
    )
    foreach ($bin in $userBins)
    {
        # Expand wildcards for paths like nvm
        $resolved = Resolve-Path $bin -ErrorAction SilentlyContinue
        foreach ($r in $resolved)
        {
            if ($r -and ($env:PATH -notlike "*$r*"))
            {
                $env:PATH = "$r$sep$env:PATH"
            }
        }
    }
}

# ─── Module Imports (safe — won't break profile if missing) ──────────────────


$env:HTTP_PROXY  = "http://webcorp.prd.example.com:8082"
$env:HTTPS_PROXY = "http://webcorp.prd.example.com:8082"

# Path to Git SSH tools
$gitSshPath = "$env:USERPROFILE\AppData\Local\Programs\Git\usr\bin"

# Ensure it's in PATH
if ($env:PATH -notlike "*$gitSshPath*") {
    $env:PATH += ";$gitSshPath"
}

# Start ssh-agent and wire env vars if not already set
if (-not $env:SSH_AUTH_SOCK) {
    $agentOutput = & "$gitSshPath\ssh-agent.exe" -s

    foreach ($line in $agentOutput) {
        if ($line -match "^(\w+)=(.+?);") {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Add key if not already loaded
$keyPath = "$env:USERPROFILE\.ssh\id_ed25519"

$keys = ssh-add -l 2>$null
if ($LASTEXITCODE -ne 0 -or $keys -notmatch "id_ed25519") {
    ssh-add $keyPath
}


function Import-ModuleSafe
{
    param([string]$Name)
    if (-not (Get-Module $Name -ListAvailable -ErrorAction SilentlyContinue))
    {
        return
    }
    try
    {
        Import-Module $Name -ErrorAction SilentlyContinue
    } catch
    {
        Write-Warning "Failed to import module: $Name"
    }
}

Import-ModuleSafe z
Import-ModuleSafe posh-git
Import-ModuleSafe Terminal-Icons

# ─── Prompt Theme ────────────────────────────────────────────────────────────

$ohMyPoshConfigs = @(
    (Join-Path (Join-Path $HOME 'products') 'pwsh10k.omp.json'),
    '/usr/share/oh-my-posh/themes/pwsh10k.omp.json',
    (Join-Path $HOME '.local/share/oh-my-posh/themes/pwsh10k.omp.json'),
    '/opt/homebrew/share/oh-my-posh/themes/pwsh10k.omp.json',
    '/usr/local/share/oh-my-posh/themes/pwsh10k.omp.json',
    (Join-Path (Join-Path $HOME '.poshthemes') 'pwsh10k.omp.json')
)

$ohMyPoshConfig = $null
foreach ($path in $ohMyPoshConfigs) {
    if (Test-Path $path) {
        $ohMyPoshConfig = $path
        break
    }
}

$ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ohMyPosh -and $ohMyPoshConfig) {
    & $ohMyPosh.Source init pwsh --config $ohMyPoshConfig | Invoke-Expression
} else {
    # Fallback prompt (Powerline-style) when oh-my-posh is unavailable
    # (e.g. AppLocker blocks on Windows Server)
    function global:prompt {
        $host.UI.RawUI.WindowTitle = "Automation: $(Get-Location)"
        $path = $PWD.Path -replace '\\', '/'
        Write-Host "$path " -NoNewline -ForegroundColor Cyan
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $branch = git branch --show-current 2>$null
            if ($branch) { Write-Host "($branch) " -NoNewline -ForegroundColor Yellow }
        }
        Write-Host "❯ " -NoNewline -ForegroundColor Cyan
        return " "
    }
}

# ─── PSReadLine Configuration ────────────────────────────────────────────────

if ($PSVersionTable.PSVersion.Major -ge 7)
{
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ─── Unix-style Aliases ──────────────────────────────────────────────────────

Set-Alias cat  Get-Content  -Option AllScope -Force
Set-Alias rm   Remove-Item  -Option AllScope -Force
Set-Alias mv   Move-Item    -Option AllScope -Force
Set-Alias ps   Get-Process  -Option AllScope -Force
Set-Alias kill Stop-Process -Option AllScope -Force


# ─── eza (ls replacement) ───────────────────────────────────────────────────
if (Get-Command eza -ErrorAction SilentlyContinue)
{
    $script:EzaCmd = if ($IsWindows) { 'eza.exe' } else { 'eza' }
    function ezals
    { & $script:EzaCmd --icons=auto --color=always $args 
    }
    function ezall
    { & $script:EzaCmd -lhG --icons=auto --color=always $args 
    }
    function ezald
    { & $script:EzaCmd -lD  --icons=auto --color=always $args 
    }
    function ezalf
    { & $script:EzaCmd -lf  --icons=auto --color=always $args 
    }
    function ezala
    { & $script:EzaCmd -lag --icons=auto --color=always $args 
    }
    function ezalA
    { & $script:EzaCmd -lAg --icons=auto --color=always $args 
    }
    function ezalaa
    { & $script:EzaCmd -aalg --icons=auto --color=always $args 
    }
    function ezalt1
    { & $script:EzaCmd -l --tree --level=1 --icons=auto --color=always $args 
    }
    function ezalt2
    { & $script:EzaCmd -l --tree --level=2 --icons=auto --color=always $args 
    }
    function ezalt3
    { & $script:EzaCmd -l --tree --level=3 --icons=auto --color=always $args 
    }

    if (Test-Path alias:ls)
    { Remove-Item alias:ls -Force 
    }
    Set-Alias ls  ezals  -Force -Option AllScope
    Set-Alias ll  ezall  -Force -Option AllScope
    Set-Alias la  ezala  -Force -Option AllScope
    Set-Alias lA  ezalA  -Force -Option AllScope
    Set-Alias laa ezalaa -Force -Option AllScope
    Set-Alias ld  ezald  -Force -Option AllScope
    Set-Alias lt1 ezalt1 -Force -Option AllScope
    Set-Alias lt2 ezalt2 -Force -Option AllScope
    Set-Alias lt3 ezalt3 -Force -Option AllScope
}


# ─── Directory Shortcuts ─────────────────────────────────────────────────────
 
function Open-Docs
{ Set-Location (Join-Path $HOME 'Documents') 
}
function Open-Downloads
{ Set-Location (Join-Path $HOME 'Downloads') 
}
function Open-Desktop
{ Set-Location (Join-Path $HOME 'Desktop') 
}
 
Set-Alias docs    Open-Docs
Set-Alias dl      Open-Downloads
Set-Alias desktop Open-Desktop

# ─── Git Aliases ─────────────────────────────────────────────────────────────

function gst
{ git status @args 
}
function gpl
{ git pull @args 
}
function gps
{ git push @args 
}
function gco
{ param([string]$branch) git checkout $branch @args 
}
function gcm
{ param([string]$message) git commit -m $message @args 
}
function gba
{ git branch -a @args 
}

# ─── Chezmoi Aliases ─────────────────────────────────────────────────────────

if (Get-Command chezmoi -ErrorAction SilentlyContinue)
{
    Set-Alias cz   chezmoi
    function cza
    { chezmoi add @args 
    }
    function czap
    { chezmoi apply @args 
    }
    function czcd
    { Set-Location (chezmoi cd @args) 
    }
    function czd
    { chezmoi diff @args 
    }
    function cze
    { chezmoi edit @args 
    }
    function czs
    { chezmoi status @args 
    }
    function czu
    { chezmoi update @args 
    }
    function czr
    { chezmoi re-add @args 
    }
    function czm
    { chezmoi merge @args 
    }
    function czpu
    { chezmoi git push @args 
    }
    function czpl
    { chezmoi git pull @args 
    }
    function czst
    { chezmoi git status @args 
    }
    function czco
    { chezmoi git commit @args 
    }
    function czga
    { chezmoi git add . 
    }
    function czgca
    { chezmoi git add . ; chezmoi git commit @args 
    }
}

# ─── pyenv-win (if installed) ────────────────────────────────────────────────
 
if ($IsWindows)
{
    $pyenvRoot = Join-Path $env:USERPROFILE '.pyenv\pyenv-win'
    if (Test-Path (Join-Path $pyenvRoot 'bin\pyenv.bat'))
    {
        $env:PATH = "$pyenvRoot\bin;$pyenvRoot\shims;$env:PATH"
        function pyenv
        {
            $bat = Join-Path $env:USERPROFILE '.pyenv\pyenv-win\bin\pyenv.bat'
            & $bat @args
        }
    }
}

# ─── Editor ──────────────────────────────────────────────────────────────────

$notepadPlusPlus = 'C:\Program Files\Notepad++\notepad++.exe'
if (Test-Path $notepadPlusPlus)
{
    try
    {
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $env:EDITOR = '{0} -nosession' -f $fso.GetFile($notepadPlusPlus).ShortPath.Replace('\', '/')
    } catch
    {
        $env:EDITOR = "notepad"
    }
}

# ─── Argument Completers ─────────────────────────────────────────────────────

if (Get-Command winget -ErrorAction SilentlyContinue)
{
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

if (Get-Command dotnet -ErrorAction SilentlyContinue)
{
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# ─── PSDefaultParameterValues (coding productivity) ──────────────────────────

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# ─── Utility Functions ───────────────────────────────────────────────────────

# Reload the current profile without restarting the terminal
function Refresh-Profile
{
    . $PROFILE
}
Set-Alias reload Refresh-Profile

# Quick profile edit — opens this file
function Edit-Profile
{
    if ($env:EDITOR)
    {
        & $env:EDITOR.Split(' ')[0] $PROFILE
    } else
    {
        code $PROFILE
    }
}

# Ensure PATH is fresh from the registry (fixes VS Code PATH caching issue)
function Refresh-Path
{
    if ($IsWindows)
    {
        $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $env:PATH    = "$machinePath;$userPath"
    } else
    {
        # Linux/macOS: just return current PATH, already set in early section
        Write-Verbose "PATH refresh not needed on non-Windows platforms"
    }
}
Set-Alias rpath Refresh-Path

# Image Build Automation module
$automationModulePath = '$env:USERPROFILE\repos\image-build-automation\src\powershell\Automation\Automation.psd1'
if (Test-Path $automationModulePath) {
    Import-Module $automationModulePath -WarningAction SilentlyContinue
}
