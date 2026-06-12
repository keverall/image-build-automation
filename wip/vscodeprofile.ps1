# =============================================================================
# PowerShell Profile — VS Code (Windows Server)
# =============================================================================
# Optimized for fast load, coding productivity, and stability.
# Loaded automatically when PowerShell starts inside VS Code.
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

if ($IsWindows) {
    $ohMyPoshPath = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin\oh-my-posh.exe'
    $ohMyPoshConfig = 'C:\Users\98253\Documents\WindowsPowerShell\pwsh10k.omp.json'
    if (Test-Path $ohMyPoshPath)
    {
        & $ohMyPoshPath init pwsh --config $ohMyPoshConfig | Invoke-Expression
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
    # Define clean wrapper functions using explicit native execution (.exe)
    function ezals
    { eza.exe --icons=auto --color=always $args 
    }
    function ezall
    { eza.exe -lhG --icons=auto --color=always $args 
    }
    function ezald
    { eza.exe -lD  --icons=auto --color=always $args 
    }
    function ezalf
    { eza.exe -lf  --icons=auto --color=always $args 
    }
    function ezala
    { eza.exe -lag --icons=auto --color=always $args 
    }
    function ezalA
    { eza.exe -lAg --icons=auto --color=always $args 
    }
    function ezalaa
    { eza.exe -aalg --icons=auto --color=always $args 
    }
    function ezalt1
    { eza.exe -l --tree --level=1 --icons=auto --color=always $args 
    }
    function ezalt2
    { eza.exe -l --tree --level=2 --icons=auto --color=always $args 
    }
    function ezalt3
    { eza.exe -l --tree --level=3 --icons=auto --color=always $args 
    }

    if (Get-Command eza -ErrorAction SilentlyContinue)
    {
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

}


# ─── Directory Shortcuts (uses $env:USERPROFILE, not hardcoded names) ────────

function Open-Docs
{ Set-Location "$env:USERPROFILE\Documents" 
}
function Open-Downloads
{ Set-Location "$env:USERPROFILE\Downloads" 
}
function Open-Desktop
{ Set-Location "$env:USERPROFILE\Desktop" 
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

$pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
if (Test-Path "$pyenvRoot\bin\pyenv.bat")
{
    $env:PATH = "$pyenvRoot\bin;$pyenvRoot\shims;$env:PATH"
    function pyenv
    {
        $bat = "$env:USERPROFILE\.pyenv\pyenv-win\bin\pyenv.bat"
        & $bat @args
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
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH    = "$machinePath;$userPath"
}
Set-Alias rpath Refresh-Path

# ─── PSReadLine Advanced Key Handlers ────────────────────────────────────────

# F7 — History browser via Out-GridView
Set-PSReadLineKeyHandler -Key F7 `
    -BriefDescription History `
    -LongDescription 'Show command history' `
    -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern)
    { $pattern = [regex]::Escape($pattern) 
    }

    $history = [System.Collections.ArrayList]@(
        $last = ''
        $lines = ''
        foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath))
        {
            if ($line.EndsWith('`'))
            {
                $line = $line.Substring(0, $line.Length - 1)
                $lines = if ($lines)
                { "$lines`n$line" 
                } else
                { $line 
                }
                continue
            }
            if ($lines)
            { $line = "$lines`n$line"; $lines = '' 
            }
            if (($line -cne $last) -and (!$pattern -or ($line -match $pattern)))
            {
                $last = $line; $line
            }
        }
    )
    $history.Reverse()
    $command = $history | Out-GridView -Title History -PassThru
    if ($command)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}

# Smart insert/delete — quotes, braces, backspace
Set-PSReadLineKeyHandler -Key '"', "'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription "Insert paired quotes if not already on a quote" `
    -ScriptBlock {
    param($key, $arg)
    $quote = $key.KeyChar
    $selectionStart = $null; $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }
    if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
    -BriefDescription InsertPairedBraces `
    -LongDescription "Insert matching braces" `
    -ScriptBlock {
    param($key, $arg)
    $closeChar = switch ($key.KeyChar)
    {
        '('
        { [char]')'; break 
        }
        '{'
        { [char]'}'; break 
        }
        '['
        { [char]']'; break 
        }
    }
    $selectionStart = $null; $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
}

Set-PSReadLineKeyHandler -Key ')', ']', '}' `
    -BriefDescription SmartCloseBraces `
    -LongDescription "Insert closing brace or skip" `
    -ScriptBlock {
    param($key, $arg)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($line[$cursor] -eq $key.KeyChar)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
    }
}

Set-PSReadLineKeyHandler -Key Backspace `
    -BriefDescription SmartBackspace `
    -LongDescription "Delete previous character or matching quotes/parens/braces" `
    -ScriptBlock {
    param($key, $arg)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($cursor -gt 0)
    {
        $toMatch = $null
        if ($cursor -lt $line.Length)
        {
            switch ($line[$cursor])
            {
                '"'
                { $toMatch = '"'; break 
                }
                "'"
                { $toMatch = "'"; break 
                }
                ')'
                { $toMatch = '('; break 
                }
                ']'
                { $toMatch = '['; break 
                }
                '}'
                { $toMatch = '{'; break 
                }
            }
        }
        if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        } else
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}

# Alt+w — Save line in history without executing
Set-PSReadLineKeyHandler -Key Alt+w `
    -BriefDescription SaveInHistory `
    -LongDescription "Save current line in history but do not execute" `
    -ScriptBlock {
    param($key, $arg)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

# RightArrow — Accept next suggestion word when at end of line
Set-PSReadLineKeyHandler -Key RightArrow `
    -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
    -LongDescription "Accept next word in suggestion when at end of line" `
    -ScriptBlock {
    param($key, $arg)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($cursor -lt $line.Length)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord($key, $arg)
    }
}

# Alt+a — Select command arguments on current line
Set-PSReadLineKeyHandler -Key Alt+a `
    -BriefDescription SelectCommandArguments `
    -LongDescription "Select next command argument on the command line" `
    -ScriptBlock {
    param($key, $arg)
    $ast = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$null, [ref]$null, [ref]$cursor)
    $asts = $ast.FindAll({
            $args[0] -is [System.Management.Automation.Language.ExpressionAst] -and
            $args[0].Parent -is [System.Management.Automation.Language.CommandAst] -and
            $args[0].Extent.StartOffset -ne $args[0].Parent.Extent.StartOffset
        }, $true)
    if ($asts.Count -eq 0)
    { [Microsoft.PowerShell.PSConsoleReadLine]::Ding(); return 
    }
    $nextAst = $null
    if ($null -ne $arg)
    {
        $nextAst = $asts[$arg - 1]
    } else
    {
        foreach ($ast in $asts)
        {
            if ($ast.Extent.StartOffset -ge $cursor)
            { $nextAst = $ast; break 
            }
        }
        if ($null -eq $nextAst)
        { $nextAst = $asts[0] 
        }
    }
    $startOffsetAdjustment = 0; $endOffsetAdjustment = 0
    if ($nextAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
        $nextAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord)
    {
        $startOffsetAdjustment = 1; $endOffsetAdjustment = 2
    }
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($nextAst.Extent.StartOffset + $startOffsetAdjustment)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetMark($null, $null)
    [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar($null, ($nextAst.Extent.EndOffset - $nextAst.Extent.StartOffset) - $endOffsetAdjustment)
}

# Auto-correct common typos
Set-PSReadLineOption -CommandValidationHandler {
    param([CommandAst]$CommandAst)
    switch ($CommandAst.GetCommandName())
    {
        'git'
        {
            $gitCmd = $CommandAst.CommandElements[1].Extent
            switch ($gitCmd.Text)
            {
                'cmt'
                { [Microsoft.PowerShell.PSConsoleReadLine]::Replace($gitCmd.StartOffset, $gitCmd.EndOffset - $gitCmd.StartOffset, 'commit') 
                }
                'psuh'
                { [Microsoft.PowerShell.PSConsoleReadLine]::Replace($gitCmd.StartOffset, $gitCmd.EndOffset - $gitCmd.StartOffset, 'push') 
                }
                'pulll'
                { [Microsoft.PowerShell.PSConsoleReadLine]::Replace($gitCmd.StartOffset, $gitCmd.EndOffset - $gitCmd.StartOffset, 'pull') 
                }
            }
        }
    }
}

# ─── Image Build Automation Module ──────────────────────────────────────────
# Auto-load the Automation module if the repo is available
$AutomationRepoPath = Join-Path $env:USERPROFILE 'repos\image-build-automation\src\powershell\Automation'
if (Test-Path $AutomationRepoPath)
{
    try
    {
        Import-Module $AutomationRepoPath -WarningAction SilentlyContinue
        
        # Maintenance mode convenience functions
        function mm
        { Set-MaintenanceMode @args 
        }
        
        function mmenable
        {
            param(
                [Parameter(Position = 0, Mandatory)]
                [string]$TargetId,
                [Parameter(Position = 1)]
                [ValidateSet('scom', 'oneview')]
                [string]$Mode = 'scom',
                [Parameter(Position = 2)]
                [ValidateSet('Test', 'Prod')]
                [string]$Environment = 'Prod',
                [string]$Start = 'now',
                [string]$End = '+2hours',
                [switch]$DryRun
            )
            $params = @{
                Action = 'enable'
                TargetId = $TargetId
                Mode = $Mode
                Environment = $Environment
                Start = $Start
                End = $End
            }
            if ($DryRun)
            { $params['DryRun'] = $true 
            }
            Set-MaintenanceMode @params
        }
        
        function mmdisable
        {
            param(
                [Parameter(Position = 0, Mandatory)]
                [string]$TargetId,
                [Parameter(Position = 1)]
                [ValidateSet('scom', 'oneview')]
                [string]$Mode = 'scom',
                [Parameter(Position = 2)]
                [ValidateSet('Test', 'Prod')]
                [string]$Environment = 'Prod'
            )
            Set-MaintenanceMode -Action disable -TargetId $TargetId -Mode $Mode -Environment $Environment
        }
        
        function mmvalidate
        {
            param(
                [Parameter(Position = 0, Mandatory)]
                [string]$TargetId,
                [Parameter(Position = 1)]
                [ValidateSet('scom', 'oneview')]
                [string]$Mode = 'scom',
                [Parameter(Position = 2)]
                [ValidateSet('Test', 'Prod')]
                [string]$Environment = 'Prod'
            )
            Set-MaintenanceMode -Action validate -TargetId $TargetId -Mode $Mode -Environment $Environment
        }
    } catch
    {
        Write-Warning "Failed to load Automation module or maintenance mode functions"
    }
}
}
