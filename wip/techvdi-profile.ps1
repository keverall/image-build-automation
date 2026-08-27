# =============================================================================
# PowerShell Profile — Windows Terminal (Windows Server)
# =============================================================================
# Optimized for fast load, coding productivity, and stability.
# Loaded automatically when PowerShell starts in Windows Terminal.
# =============================================================================

# ─── Refresh PATH from the registry (Windows) ────────────────────────────────
# Launched processes (e.g. VS Code) can inherit a stale PATH; pull the current
# Machine + User PATH so the terminal sees up-to-date tool locations.
$env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') +
    ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

# ─── Module Imports (safe — won't break profile if missing) ──────────────────

$env:HOME = $env:USERPROFILE
$env:HTTP_PROXY  = "http://webcorp.prd.aib.pri:8082"
$env:HTTPS_PROXY = "http://webcorp.prd.aib.pri:8082"

# Path to Git SSH tools
$gitSshPath = "$env:USERPROFILE\AppData\Local\Programs\Git\usr\bin"

# Ensure it's in PATH
if ($env:PATH -notlike "*$gitSshPath*")
{
    $env:PATH += ";$gitSshPath"
}

# Start ssh-agent and wire env vars if not already set
if (-not $env:SSH_AUTH_SOCK)
{
    $agentOutput = & "$gitSshPath\ssh-agent.exe" -s

    foreach ($line in $agentOutput)
    {
        if ($line -match "^(\w+)=(.+?);")
        {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Pin git to Git's bundled ssh (Windows OpenSSH is blocked in this locked-down env).
# GIT_SSH is executed directly by git, so Windows backslash paths are safe here.
$env:GIT_SSH = "$gitSshPath\ssh.exe"

# Add key if not already loaded (qualify ssh-add so it targets Git's agent, not Windows OpenSSH)
$keyPath = "$env:USERPROFILE\.ssh\id_ed25519"

$keys = & "$gitSshPath\ssh-add.exe" -l 2>$null
if ($LASTEXITCODE -ne 0 -or $keys -notmatch "id_ed25519")
{
    & "$gitSshPath\ssh-add.exe" $keyPath
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
foreach ($path in $ohMyPoshConfigs)
{
    if (Test-Path $path)
    {
        $ohMyPoshConfig = $path
        break
    }
}

$ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ohMyPosh -and $ohMyPoshConfig)
{
    & $ohMyPosh.Source init pwsh --config $ohMyPoshConfig | Invoke-Expression
} else
{
    # Fallback prompt (Powerline-style) when oh-my-posh is unavailable
    # (e.g. AppLocker blocks on Windows Server)
    function global:prompt
    {
        $host.UI.RawUI.WindowTitle = "Automation: $(Get-Location)"
        $path = $PWD.Path -replace '\\', '/'
        Write-Host "$path " -NoNewline -ForegroundColor Cyan
        if (Get-Command git -ErrorAction SilentlyContinue)
        {
            $branch = git branch --show-current 2>$null
            if ($branch)
            { Write-Host "($branch) " -NoNewline -ForegroundColor Yellow 
            }
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
$ezaCmd = 'eza.exe'
if (Get-Command $ezaCmd -ErrorAction SilentlyContinue)
{
    $ezaAliases = @(
        @{ Name = 'ezals';  Alias = 'ls';  Args = '--icons=auto --color=always' }
        @{ Name = 'ezall';  Alias = 'll';  Args = '-lhG --icons=auto --color=always' }
        @{ Name = 'ezala';  Alias = 'la';  Args = '-lag --icons=auto --color=always' }
        @{ Name = 'ezalA';  Alias = 'lA';  Args = '-lAg --icons=auto --color=always' }
        @{ Name = 'ezalaa'; Alias = 'laa'; Args = '-aalg --icons=auto --color=always' }
        @{ Name = 'ezald';  Alias = 'ld';  Args = '-lD --icons=auto --color=always' }
        @{ Name = 'ezalt1'; Alias = 'lt1'; Args = '-l --tree --level=1 --icons=auto --color=always' }
        @{ Name = 'ezalt2'; Alias = 'lt2'; Args = '-l --tree --level=2 --icons=auto --color=always' }
        @{ Name = 'ezalt3'; Alias = 'lt3'; Args = '-l --tree --level=3 --icons=auto --color=always' }
    )

    if (Test-Path alias:ls) { Remove-Item alias:ls -Force }
    foreach ($e in $ezaAliases)
    {
        Set-Item -Path "Function:$($e.Name)" -Value ([scriptblock]::Create("& $ezaCmd $($e.Args) `$args")) -Force
        Set-Alias -Name $e.Alias -Value $e.Name -Force -Option AllScope
    }
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
$automationModulePath = 'C:\Users\98253\repos\image-build-automation\src\powershell\Automation\Automation.psd1'
if (Test-Path $automationModulePath)
{
    Import-Module $automationModulePath -WarningAction SilentlyContinue
}

