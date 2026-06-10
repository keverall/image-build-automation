# scripts/ci-security-check.ps1
# CI pipeline security validation - PSScriptAnalyzer, secrets detection, and JSON validation
# No hardcoded secrets or credentials - all validation commands are safe

# PSScriptAnalyzer security rules
Write-Host "Running PSScriptAnalyzer security scan..." -ForegroundColor Cyan
$results = Invoke-ScriptAnalyzer -Path 'src/powershell' -Recurse -Severity Error |
    Where-Object { $_.RuleName -notin @(
        'PSUseBOMForUnicodeEncodedFile',
        'PSUseToExportFieldsInManifest',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseApprovedVerbs',
        'PSUseSingularNouns',
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingUsernameAndPasswordParams',
        'TypeNotFound'
    ) }
$results | Format-Table -AutoSize
if ($results) { exit 1 }

# Check for hardcoded secrets (basic pattern matching)
Write-Host "Checking for hardcoded secrets..." -ForegroundColor Cyan
Get-ChildItem -Path 'src/powershell' -Recurse -Include *.ps1,*.json |
    Select-String -Pattern 'password|secret|key|token' -List |
    ForEach-Object { Write-Warning "Potential secret found in: $($_.Path)" }

# Validate JSON config files
Write-Host "Validating JSON config files..." -ForegroundColor Cyan
Get-ChildItem -Path 'configs' -Recurse -Include *.json |
    ForEach-Object {
        try {
            $content = Get-Content $_.FullName -Raw
            $content | ConvertFrom-Json | Out-Null
            Write-Host "Valid JSON: $($_.Name)"
        } catch {
            Write-Error "Invalid JSON in $($_.Name): $($_.Exception.Message)"
            exit 1
        }
    }