 make test                                                 0  10s 848ms  10:15:52 
\033[0;36m[prune-logs]\033[0m Pruning old log files...
[prune-logs] Pruning logs to keep maximum 10 per type...
[prune-logs] Pruned 0 excess log files.
\033[0;36m[test]\033[0m Running Pester unit tests...
Add-Type: Cannot bind parameter 'Path' to the target. Exception setting "Path": "Cannot find path
'C:\Users\98253\Documents\PowerShell\Modules\Pester\5.7.1\bin\netstandard2.0\Pester.dll' because it does not exist."
make: *** [test] Error 1

On the Windows test server, run these PowerShell commands:

# Remove the broken installation
Remove-Item -Recurse -Force "$env:USERPROFILE\Documents\PowerShell\Modules\Pester"

# Install from PSGallery (requires internet)
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck

# Verify
Import-Module Pester 5.7.1 -PassThru
Or install from the bundled vendor copy (offline):

# Copy the bundled module to the PowerShell modules folder
$dest = "$env:USERPROFILE\Documents\PowerShell\Modules\Pester\5.7.1"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path "<repo-path>\vendor\modules\Pester\5.7.1\*" -Destination $dest -Recurse -Force

# Verify
Import-Module Pester 5.7.1 -PassThru
Replace <repo-path> with the full path to your cloned repo on the Windows server.s


Switch to GitStash (BMC Bitbucket):

git remote set-url origin https://gitstash.bmc.com/scm/~keverall/image-build-automation.git
Or with SSH:

git remote set-url origin ssh://git@gitstash.bmc.com:7999/~keverall/image-build-automation.git

Sourcetree (Atlassian's official client) - free, Bitbucket-native:

Download: https://www.sourcetreeapp.com/
GitKraken - polished, Bitbucket supported:

https://www.gitkraken.com/
TortoiseGit - Windows shell integration, works with any remote:

https://tortoisegit.org/


1. Generate the PAT in GitStash/Bitbucket:

Go to: https://gitstash.bmc.com/plugins/servlet/access-tokens/users-and-groups (or your instance URL → Avatar → Manage account → HTTP access tokens → Create token)

Give it scopes: REPO_READ, REPO_WRITE, PROJECT_READ

2. Use it in git (Windows):

Option A - Credential Manager (recommended):

git config --global credential.helper manager-core
git fetch origin
# Prompted for username + paste PAT as password
Option B - Embed in remote URL (no prompts):

git remote set-url origin https://<your-username>:<PAT>@gitstash.bmc.com/scm/~keverall/image-build-automation.git
Option C - Git credential store (plain text, cached):

git config --global credential.helper store
git fetch origin
# Enter username + PAT once, saved to ~/.git-credentials


https://monitoringguys.com/2020/07/30/control-scom-maintenance-mode-from-the-agent-with-scomagenthelper-management-pack/

