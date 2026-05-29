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