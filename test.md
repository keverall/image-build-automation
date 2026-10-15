
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