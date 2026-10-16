Already up to date.
   image-build-automation  main  git log -1 --oneline                                                                                                                                             0  971ms  11:20:54 38045b3e (HEAD -> main, origin/main, origin/HEAD) Remove unnecessary text from test.md and ensure linting passes
   image-build-automation  main  make setup                                                                                                                                                              0  11:21:03 [setup] Setting up PowerShell environment...

╔══════════════════════════════════════════════════════╗
║  HPE ProLiant ISO Automation - PowerShell Setup     ║
╚══════════════════════════════════════════════════════╝

[OK] PowerShell 7.6.6
[OK] Added offline module path for this session: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules
[INFO] Verifying local PowerShell modules (offline; files are preserved)…
[OK] Pester 6.0.1 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\Pester\6.0.1\Pester.psd1
[OK] PSScriptAnalyzer 1.21.0 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\PSScriptAnalyzer\1.21.0\PSScriptAnalyzer.psd1
[OK] PlatyPS 0.14.0 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\platyPS\0.14.0\platyPS.psd1
[OK] HPEOneView.1000 10.0.4265.2221 verified from local manifest: C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1
Exception: C:\Users\adm_98253\products\repos\image-build-automation\scripts\setup-runner.ps1:277:9 
Line | 
 277 |          throw "Local import failed for $Name $Version from '$Manifest …
     |          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Local import failed for HPRESTCmdlets 1.2.0.0 from 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1'. Files were preserved. Import error:       
     | Exception: C:\Users\adm_98253\products\repos\image-build-automation\scripts\Import-OfflineHpeModules.ps1:56:13 Line |   56 | 
     | throw "Unable to import local $ModuleName from '$Manifest …      | 
     | ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~      | Unable to import local HPRESTCmdlets from
     | 'C:\Users\adm_98253\products\repos\image-build-automation\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1'. Files were preserved. After a previous failed HPE
     |      | import, start a fresh 'pwsh -NoProfile' shell rather than forcing a reload. Original error: Cannot add type. The
     | type name 'AsyncPipeline' already exists.
make: *** [Makefile:57: setup] Error 1 
   image-build-automation  main                                                                                  

No — and it should **not** be imported. Here's the definitive breakdown from the manifest itself.

<a id="what-hprestcmdletspsd1-actually-loads"></a>

## What `HPRESTCmdlets.psd1` actually loads

The manifest declares only three relevant keys (no `NestedModules`, no `RequiredAssemblies`, no `FormatsToProcess`, no `TypesToProcess`):

| Manifest key | File | Role |
|---|---|---|
| `RootModule = 'HPRESTCmdlets.psm1'` | HPRESTCmdlets.psm1 | The cmdlets |
| `ScriptsToProcess = @('ShowLicense.ps1')` | ShowLicense.ps1 | Runs **before** RootModule — HPE license acceptance + the `AsyncPipeline` type |
| `FileList = @(...,'HPRESTExamples.ps1',...)` | — | **Packaging metadata only** |

**PowerShell never executes `FileList` entries.** `HPRESTExamples.ps1` is only listed there (and mentioned in the `Description`) as shipped documentation. Its own content confirms it: 2,510 lines of comment blocks listing cmdlets, plus sample scripts that call `Connect-HPREST` against live devices. It is never loaded, and dot-sourcing it would execute example code that tries to connect to hardware.

<a id="import-the-psd1-never-the-psm1"></a>

## Import the `.psd1`, never the `.psm1`

```powershell
Import-Module '.\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1' -ErrorAction Stop
```

Importing the `.psm1` directly would:
- **Bypass HPE's license acceptance** (`ShowLicense.ps1`) — the license file states the module must not be used until accepted;
- Export *every* function in the file, including internal helpers like `Get-Message` and `Create-ThreadPool`, risking name collisions;
- Lose version/GUID identity that `make setup` and `Get-CommandHelp` rely on.

`Import-Module HPRESTCmdlets` by name works too once `scripts/modules` is on `$env:PSModulePath` (which `make setup` now does).

<a id="verify-all-four-layers-are-resident-and-usable"></a>

## Verify all four layers are resident and usable

```powershell
Get-Module HPRESTCmdlets, HPEOneView.1000 | Format-Table Name,Version,Path

Get-Command Get-OVServer, Get-OVIloSso `            # auth source (from HPEOneView.1000)
  | Format-Table Name,Module,Version
Get-Command Connect-HPREST, Get-HPRESTDataRaw `      # confirms the psd1 loaded fully
  | Format-Table Name,Module,Version

$null -ne ('AsyncPipeline' -as [type])               # True = ShowLicense.ps1 actually ran
```

If `AsyncPipeline` is `False` while `HPRESTCmdlets` is loaded, the module was imported by `.psm1` rather than `.psd1` — that's the failure mode to avoid.

One accurate detail for your auth work: `Configure-PhysicalServer`'s SSO path needs **`Get-OVServer` + `Get-OVIloSso`** (`HPEOneView.1000`) and passes the token to `[IloRedfishSession]` which sends `X-Auth-Token`. `HPRESTCmdlets` is the vendor-declared iLO REST dependency that `make setup` requires. Run `Invoke-IloRedfish -Action Status -IloIp <ip> -OneViewHost <host> -OneViewServerName <name>` and read its `Auth_Diagnostics` to see `Token_Source`, `Token_Length`, and `Last_Error`.

I confirmed the guard is in HEAD and your working tree is clean — so your server just needs git pull to get it. The run you pasted was against 38045b3e, which predates that fix.

What to do on eiswmgt-19
git pull
make setup

# make setup verifies in a child process; do this in YOUR shell:

<a id="top"></a>

## Table of Contents

- [What `HPRESTCmdlets.psd1` actually loads](#what-hprestcmdletspsd1-actually-loads)
- [Import the `.psd1`, never the `.psm1`](#import-the-psd1-never-the-psm1)
- [Verify all four layers are resident and usable](#verify-all-four-layers-are-resident-and-usable)

Import-Module '.\scripts\modules\HPEOneView.1000\10.0.4265.2221\HPEOneView.1000.psd1' -ErrorAction Stop
Import-Module '.\scripts\modules\HPRESTCmdlets\1.2.0.0\HPRESTCmdlets.psd1' -ErrorAction Stop

Get-Command Get-OVServer, Get-OVIloSso, Connect-HPREST | Format-Table Name,Module,Version
$null -ne ('AsyncPipeline' -as [type])    # must be True
If it breaks again, capture the exact error line — the three above are distinguishable by their first line alone, and that determines which fix applies.

127.2 t/s
