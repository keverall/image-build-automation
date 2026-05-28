 make test                                                    0  7s 499ms  17:21:14 
\033[0;36m[prune-logs]\033[0m Pruning old log files...
[prune-logs] Pruning logs to keep maximum 10 per type...
[prune-logs] Pruned 0 excess log files.
\033[0;36m[test]\033[0m Running Pester unit tests...
Add-Type: Cannot bind parameter 'Path' to the target. Exception setting "Path": "Cannot find path
'C:\Users\98253\Documents\PowerShell\Modules\Pester\5.7.1\bin\netstandard2.0\Pester.dll' because it does not exist."
make: *** [test] Error 1

from code error powershell pwsh -  make
make : The term 'make' is not recognized as the name of a cmdlet, function, script file, or operable 
program. Check the spelling of the name, or if a path was included, verify that the path is correct 
and try again.
At line:1 char:1
+ make
+ ~~~~
    + CategoryInfo          : ObjectNotFound: (make:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException

    

o make it permanent, add this to your VS Code settings (Ctrl+, → search "terminal env"):

"terminal.integrated.env.windows": {
    "PATH": "${env:PATH}"
}
Or check if terminal.integrated.inheritEnv is set to false somewhere - it should be true (the default).