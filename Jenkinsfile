pipeline {
    agent {
        label 'windows'
    }

    options {
        timeout(time: 4, unit: 'HOURS')
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        ansiColor('xterm')
    }

    parameters {
        choice(
            name: 'BUILD_STAGE',
            choices: ['firmware', 'windows', 'deploy', 'scan', 'all'],
            description: 'Which pipeline stage to execute'
        )
        string(
            name: 'SERVER_FILTER',
            defaultValue: '',
            description: 'Comma-separated list of servers (empty = all)'
        )
        string(
            name: 'BASE_ISO_PATH',
            defaultValue: 'C:\\ISOs\\Windows_Server_2022.iso',
            description: 'Path to base Windows Server ISO'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Run in dry-run mode (no actual changes)'
        )
        choice(
            name: 'DEPLOY_METHOD',
            choices: ['ilo', 'redfish'],
            description: 'Deployment method (for deploy stage)'
        )
        booleanParam(
            name: 'SKIP_DOWNLOAD',
            defaultValue: false,
            description: 'Skip firmware/driver download (use existing)'
        )
        booleanParam(
            name: 'SKIP_CODE_SCAN',
            defaultValue: false,
            description: 'Skip code quality and security scanning stages'
        )
        booleanParam(
            name: 'FAIL_ON_CODE_ISSUES',
            defaultValue: false,
            description: 'Fail build on code quality issues (strict mode)'
        )
    }

    environment {
        // CyberArk is the single source of truth for all secrets.
        // Secrets are fetched by the 'CyberArk - Bootstrap Secrets' stage at the
        // start of every build and injected here as env vars for all downstream
        // Python / PowerShell stages.  No Jenkins 'credentials()' store entries
        // are needed.
        //
        // AppID used for all CCP look-ups
        CYBERARK_APP_ID = 'jenkins'

        // Override the CCP URL if your vault does not resolve via DNS
        // AIM_WEBSERVICE_URL = 'https://cyberark-vault.example.com/AIMWebService/API/Accounts'

        // Python/paths
        PYTHONUNBUFFERED = '1'
        OUTPUT_DIR = 'output'
        CONFIG_DIR = 'configs'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    currentBuild.displayName = "#${BUILD_NUMBER} - ${params.BUILD_STAGE}"
                }

                bat '''
                echo [INFO] Setting up workspace
                if not exist "output" mkdir output
                if not exist "output\\firmware" mkdir output\\firmware
                if not exist "output\\patched" mkdir output\\patched
                if not exist "output\\combined" mkdir output\\combined
                if not exist "logs" mkdir logs
                if not exist "logs\\build_reports" mkdir logs\\build_reports
                if not exist "logs\\monitoring_sessions" mkdir logs\\monitoring_sessions
                if not exist "logs\\scan_reports" mkdir logs\\scan_reports
                '''

                powershell '''
                # Install Python dependencies
                python -m pip install --upgrade pip
                pip install -r requirements.txt

                # Install code quality & security scanning tools
                pip install ruff radon bandit safety
                
                # Install automation package in editable mode
                pip install -e .

                # Verify Python syntax for all modules
                echo [INFO] Verifying Python syntax...
                # Verify package structure and imports (ruff handles syntax + import checks)
                pip install ruff
                ruff check src\\automation --output-format=text
                Write-Host "[INFO] Package imports validated"

                # Validate JSON configs
                echo [INFO] Validating JSON configs...
                python -c "import json; json.load(open('configs/hpe_firmware_drivers_nov2025.json'))"
                python -c "import json; json.load(open('configs/windows_patches.json'))"
                python -c "import json; json.load(open('configs/opsramp_config.json'))"
                python -c "import json; json.load(open('configs/clusters_catalogue.json'))"
                python -c "import json; json.load(open('configs/scom_config.json'))"
                python -c "import json; json.load(open('configs/openview_config.json'))"
                python -c "import json; json.load(open('configs/email_distribution_lists.json'))"
                '''
            }
        }

        // =====================================================================
        // CYBERARK BOOTSTRAP
        // Fetches all secrets before any build stage runs.  Uses CCP CLI when
        // available, falls back to the AIM REST API.  Secrets are injected as
        // Process-scope env vars (and cached to Machine scope) so every downstream
        // PowerShell / Python step can read them transparently.
        // =====================================================================
        stage('CyberArk - Bootstrap Secrets') {
            steps {
                powershell '''
                $ccCli = Get-Command ark_ccl -ErrorAction SilentlyContinue
                if (-not $ccCli) { $ccCli = Get-Command ark_cc -ErrorAction SilentlyContinue }

                if ($ccCli) {
                    Write-Host "[CyberArk] CCP CLI found: $($ccCli.Source)"
                    $script:fetched = @()
                    $secretMap = @(
                        @{ Safe='HPE-iLO';    Obj='ILO_USER';              Var='ILO_USER' },
                        @{ Safe='HPE-iLO';    Obj='ILO_PASSWORD';           Var='ILO_PASSWORD' },
                        @{ Safe='SCOM-2015';  Obj='SCOM_ADMIN_USER';        Var='SCOM_ADMIN_USER' },
                        @{ Safe='SCOM-2015';  Obj='SCOM_ADMIN_PASSWORD';    Var='SCOM_ADMIN_PASSWORD' },
                        @{ Safe='OpsRamp';    Obj='OPSRAMP_CLIENT_ID';      Var='OPSRAMP_CLIENT_ID' },
                        @{ Safe='OpsRamp';    Obj='OPSRAMP_CLIENT_SECRET';  Var='OPSRAMP_CLIENT_SECRET' },
                        @{ Safe='OpsRamp';    Obj='OPSRAMP_TENANT_ID';      Var='OPSRAMP_TENANT_ID' },
                        @{ Safe='SMTP-Mail';  Obj='SMTP_USER';              Var='SMTP_USER' },
                        @{ Safe='SMTP-Mail';  Obj='SMTP_PASSWORD';          Var='SMTP_PASSWORD' },
                        @{ Safe='OpenView';   Obj='OPENVIEW_USER';          Var='OPENVIEW_USER' },
                        @{ Safe='OpenView';   Obj='OPENVIEW_PASSWORD';      Var='OPENVIEW_PASSWORD' },
                        @{ Safe='HPE-Download'; Obj='hpe-download-user';    Var='HPE_DOWNLOAD_USER' },
                        @{ Safe='HPE-Download'; Obj='hpe-download-pass';    Var='HPE_DOWNLOAD_PASS' }
                    )
                    foreach ($s in $secretMap) {
                        $out = & $ccCli.Source getpassword -pAppID=jenkins -pSafe=$s.Safe -pObject=$s.Obj 2>&1 | Out-String
                        if ($LASTEXITCODE -eq 0 -and $out.Trim()) {
                            $lines = $out.Trim() -split "`n"
                            $secret = ($lines | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
                            if ($secret) {
                                [System.Environment]::SetEnvironmentVariable($s.Var, $secret, 'Process')
                                Write-Host "[CyberArk:CLI]  $($s.Var)  <-  safe=$($s.Safe)  object=$($s.Obj)"
                                $script:fetched += $s.Var
                            }
                        }
                    }
                    Write-Host "[CyberArk] CLI fetched: $($script:fetched -join ', ')"
                }

                # REST fallback for anything CLI did not provide
                $aimUrl = $env:AIM_WEBSERVICE_URL
                if (-not $aimUrl) { $aimUrl = $env:CYBERARK_CCP_URL }
                if (-not $aimUrl) { $aimUrl = 'https://cyberark-ccp:443/AIMWebService/API/Accounts' }
                $script:restFetched = @()
                $restMap = @(
                    @{ Safe='HPE-iLO';      Obj='ILO_USER';              Var='ILO_USER' },
                    @{ Safe='HPE-iLO';      Obj='ILO_PASSWORD';           Var='ILO_PASSWORD' },
                    @{ Safe='SCOM-2015';    Obj='SCOM_ADMIN_USER';        Var='SCOM_ADMIN_USER' },
                    @{ Safe='SCOM-2015';    Obj='SCOM_ADMIN_PASSWORD';    Var='SCOM_ADMIN_PASSWORD' },
                    @{ Safe='OpsRamp';      Obj='OPSRAMP_CLIENT_ID';      Var='OPSRAMP_CLIENT_ID' },
                    @{ Safe='OpsRamp';      Obj='OPSRAMP_CLIENT_SECRET';  Var='OPSRAMP_CLIENT_SECRET' },
                    @{ Safe='OpsRamp';      Obj='OPSRAMP_TENANT_ID';      Var='OPSRAMP_TENANT_ID' },
                    @{ Safe='SMTP-Mail';    Obj='SMTP_USER';              Var='SMTP_USER' },
                    @{ Safe='SMTP-Mail';    Obj='SMTP_PASSWORD';          Var='SMTP_PASSWORD' },
                    @{ Safe='OpenView';     Obj='OPENVIEW_USER';          Var='OPENVIEW_USER' },
                    @{ Safe='OpenView';     Obj='OPENVIEW_PASSWORD';      Var='OPENVIEW_PASSWORD' },
                    @{ Safe='HPE-Download'; Obj='hpe-download-user';      Var='HPE_DOWNLOAD_USER' },
                    @{ Safe='HPE-Download'; Obj='hpe-download-pass';      Var='HPE_DOWNLOAD_PASS' }
                )
                foreach ($s in $restMap) {
                    if ([System.Environment]::GetEnvironmentVariable($s.Var)) { continue }
                    try {
                        $q    = [System.Uri]::EscapeDataString("Safe=$($s.Safe);Object=$($s.Obj)")
                        $url  = "$aimUrl`?AppID=jenkins&Query=$q"
                        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
                        $item  = if ($resp -is [System.Array]) { $resp[0] } else { $resp }
                        $secret = $item.Content
                        if ($secret) {
                            [System.Environment]::SetEnvironmentVariable($s.Var, $secret, 'Process')
                            Write-Host "[CyberArk:REST]  $($s.Var)  <-  safe=$($s.Safe)  object=$($s.Obj)"
                            $script:restFetched += $s.Var
                        }
                    } catch {
                        Write-Warning "[CyberArk:REST] Failed safe=$($s.Safe) obj=$($s.Obj): $($_.Exception.Message)"
                    }
                }
                Write-Host "[CyberArk] REST fetched: $($script:restFetched -join ', ')"
                Write-Host "[CyberArk] Bootstrap complete."
                '''
            }
        }
        stage('Code Quality & Security Scan') {
            when {
                expression { !params.SKIP_CODE_SCAN }
            }
            steps {
                powershell '''
                echo [STAGE] Code Quality & Security Scanning
                $scanDir = "code_scan_results"
                if (Test-Path $scanDir) { Remove-Item -Recurse -Force $scanDir }
                New-Item -ItemType Directory -Force -Path $scanDir | Out-Null

                # Strict mode flag
                $strict = $env.FAIL_ON_CODE_ISSUES -eq 'true'

                # ============================================
                # 1. RUFF — Fast linting + auto-fix check
                # ============================================
                echo [INFO] [1/6] Running ruff lint check...
                ruff check src\automation\\ --output-format=json --output=code_scan_results\\ruff_issues.json
                if ($LASTEXITCODE -ne 0) {
                    echo "ruff found style issues"
                    if ($strict) { exit 1 }
                }
                # Ensure auto-fixes applied
                ruff check src\automation\\ --fix
                # Check formatting
                ruff format --check src\automation\ > code_scan_results\ruff_format.txt 2>&1
                if ($LASTEXITCODE -ne 0) {
                    echo "ruff format check failed"
                    if ($strict) { exit 1 }
                }

                # ============================================
                # 2. PYLINT — Traditional comprehensive lint
                # ============================================
                echo [INFO] [2/6] Running pylint...
                pip install pylint 2>$null | Out-Null
                if (Get-Command pylint -ErrorAction SilentlyContinue) {
                    pylint --output-format=json src\automation\\ > code_scan_results\\pylint_report.json 2>&1
                    $pylintExit = $LASTEXITCODE
                    pylint src\automation\\ > code_scan_results\\pylint_report.txt 2>&1
                    if ($pylintExit -ne 0 -and $strict) { exit 1 }
                } else {
                    "pylint not available" | Out-File code_scan_results\\pylint_report.txt -Encoding utf8
                }

                # ============================================
                # 3. RADON — Maintainability & Complexity
                # ============================================
                echo [INFO] [3/6] Running radon complexity analysis...
                radon mi src\automation\\ -s -j > code_scan_results\\radon_maintainability.json
                radon cc src\automation\\ -s -j > code_scan_results\\radon_cyclomatic.json
                # Warn on complex functions (CC > 10)
                $ccWarnings = radon cc src\automation\\ -nc
                $ccWarnings | Out-File code_scan_results\\radon_complexity_warnings.txt -Encoding utf8
                if ($ccWarnings -match "C") {
                    echo "WARNING: High cyclomatic complexity detected (C grade)"
                    if ($strict) { exit 1 }
                }

                # ============================================
                # 4. BANDIT — Security vulnerabilities (Python)
                # ============================================
                echo [INFO] [4/6] Running bandit security scan...
                bandit -r src\automation\\ -f json -o code_scan_results\\bandit_report.json
                $banditExit = $LASTEXITCODE
                bandit -r src\automation\\ -f txt -o code_scan_results\\bandit_report.txt
                if ($banditExit -ne 0) {
                    echo "bandit found potential security issues"
                    # Parse JSON for HIGH/CRITICAL
                    try {
                        $banditData = Get-Content code_scan_results\\bandit_report.json | ConvertFrom-Json
                        $highIssues = $banditData.results | Where-Object { $_.issue_severity -in 'HIGH', 'CRITICAL' }
                        if ($highIssues) {
                            echo "FOUND HIGH/CRITICAL bandit issues: $($highIssues.Count)"
                            if ($strict) { exit 1 }
                        }
                    } catch {
                        echo "Could not parse bandit JSON; check report manually"
                    }
                }

                # ============================================
                # 5. SAFETY — Dependency vulnerability check
                # ============================================
                echo [INFO] [5/6] Checking dependencies with safety...
                safety check --json --output code_scan_results\\safety_report.json
                $safetyExit = $LASTEXITCODE
                safety check --output code_scan_results\\safety_report.txt
                if ($safetyExit -ne 0) {
                    echo "safety found vulnerable dependencies"
                    try {
                        $safetyData = Get-Content code_scan_results\\safety_report.json | ConvertFrom-Json
                        $highVulns = $safetyData.vulnerabilities | Where-Object { $_.vulnerability_id -match 'CVE-' }
                        if ($highVulns) {
                            echo "FOUND HIGH/CRITICAL vulnerabilities: $($highVulns.Count)"
                            if ($strict) { exit 1 }
                        }
                    } catch {
                        echo "Could not parse safety JSON; check report manually"
                    }
                }

                # ============================================
                # 6. GITLEAKS — Detect committed secrets
                # ============================================
                echo [INFO] [6/6] Scanning for secrets with gitleaks...
                if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
                    echo "gitleaks not installed; attempting local download..."
                    try {
                        if (-not (Test-Path "tools")) { New-Item -ItemType Directory -Force -Path "tools" | Out-Null }
                        if (-not (Test-Path "tools\\gitleaks.exe")) {
                            Invoke-WebRequest -Uri "https://github.com/gitleaks/gitleaks/releases/download/v8.18.1/gitleaks_8.18.1_windows_x64.zip" -OutFile "tools\\gitleaks.zip" -TimeoutSec 30
                            Expand-Archive -Path "tools\\gitleaks.zip" -DestinationPath "tools" -Force
                            Remove-Item "tools\\gitleaks.zip" -Force
                        }
                        $gitleaksPath = ".\\tools\\gitleaks.exe"
                    } catch {
                        echo "WARNING: Could not download gitleaks: $_"
                        echo "Skipping gitleaks scan (non-fatal)"
                        $gitleaksPath = $null
                    }
                } else {
                    $gitleaksPath = "gitleaks"
                }

                if ($gitleaksPath) {
                    & $gitleaksPath detect --source=. --report-path=code_scan_results\\gitleaks_report.json --report-format json --no-banner
                    $gitleaksExit = $LASTEXITCODE
                    if ($gitleaksExit -ne 0) {
                        echo "gitleaks found potential secrets!"
                        try {
                            $glData = Get-Content code_scan_results\\gitleaks_report.json | ConvertFrom-Json
                            if ($glData.Findings) {
                                echo "Found $($glData.Findings.Count) potential secret(s)"
                                if ($strict) { exit 1 }
                            }
                        } catch {
                            echo "Gitleaks reported issues; check report"
                            if ($strict) { exit 1 }
                        }
                    }
                }

                # ============================================
                # Summary
                # ============================================
                echo ''
                echo [SUMMARY] Code scan complete. Reports in code_scan_results/
                echo Files generated:
                Get-ChildItem code_scan_results\\ | ForEach-Object { "  - $($_.Name)" }
                echo ''
                echo "To fail build on issues, enable 'FAIL_ON_CODE_ISSUES' parameter."
                '''
            }
            post {
                always {
                    // Archive all scan reports
                    archiveArtifacts artifacts: 'code_scan_results/**', allowEmptyArchive: false
                }
                failure {
                    mail to: 'security-alerts@yourcompany.com',
                         subject: "⚠️ Code Quality/Scan FAILED: Build #${BUILD_NUMBER}",
                         body: "One or more code quality or security scans failed. Review artifacts in build #${BUILD_NUMBER}.\n\nReports: code_scan_results/"
                }
            }
        }

        stage('Unit Tests & Coverage') {
            steps {
                powershell '''
                # Install pytest if not already installed
                pip install pytest pytest-cov

                $isPR = $env:CHANGE_ID -ne $null -and $env:CHANGE_ID -ne ''
                if ($isPR) {
                    Write-Host "PR build: Determining affected tests..."
                    $target = $env:CHANGE_TARGET
                    if ([string]::IsNullOrWhiteSpace($target)) {
                        $target = "main"
                    }
                    # Fetch target branch to ensure it's available
                    git fetch origin $target 2>$null
                    # Get list of changed files
                    $changed = git diff --name-only origin/$target...HEAD
                    $testFiles = @()
                    foreach ($file in $changed) {
                        if ($file.StartsWith('tests/') -and $file.EndsWith('.py')) {
                            $testFiles += $file
                        } elseif ($file.StartsWith('src/automation/') -and $file.EndsWith('.py')) {
                            $relative = $file.Substring(15)  # remove 'src/automation/'
                            $dir = [System.IO.Path]::GetDirectoryName($relative)
                            $base = [System.IO.Path]::GetFileNameWithoutExtension($relative)
                            $testFile = if ($dir) { Join-Path $dir "test_${base}.py" } else { "test_${base}.py" }
                            $testPath = Join-Path "tests" $testFile
                            if (Test-Path $testPath) {
                                $testFiles += $testPath
                            } else {
                                Write-Host "Note: No test file for $file (expected $testPath)"
                            }
                        }
                    }
                    if ($testFiles.Count -eq 0) {
                        Write-Host "No affected tests detected. Writing empty test results."
                        # Create minimal JUnit XML with zero tests
                        $emptyJUnit = '<?xml version="1.0" encoding="UTF-8"?><testsuite name="Empty" tests="0" failures="0" errors="0" skipped="0" time="0.000"></testsuite>'
                        $emptyJUnit | Out-File -FilePath $junitXml -Encoding utf8
                        # No coverage file will be generated; archive will be allowed to be empty
                        exit 0
                    }
                    Write-Host "Running affected tests: $($testFiles -join ', ')"
                    $pytestTarget = $testFiles
                } else {
                    Write-Host "Full build: running all unit tests..."
                    $pytestTarget = "tests"
                }

                $junitXml = "test-results.xml"
                $pytestArgs = @('--junitxml', $junitXml)
                if ($isPR) {
                    $pytestArgs += '--cov-fail-under=0'
                }
                if ($pytestTarget -is [array]) {
                    python -m pytest @$pytestTarget @pytestArgs
                } else {
                    python -m pytest $pytestTarget @pytestArgs
                }
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                    archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
                }
                failure {
                    mail to: 'dev-team@yourcompany.com',
                         subject: "Unit Tests FAILED: Build #${BUILD_NUMBER}",
                         body: "One or more unit tests failed. See Jenkins test report."
                }
            }
        }

        stage('Generate UUIDs') {
            when {
                expression { params.BUILD_STAGE in ['firmware', 'windows', 'deploy', 'all'] }
            }
            steps {
                powershell '''
                $servers = Get-Content configs\\server_list.txt | Where-Object { $_ -and -not $_.StartsWith('#') }

                if (params.SERVER_FILTER) {
                    $filterList = params.SERVER_FILTER -split ','
                    $servers = $servers | Where-Object { $filterList -contains $_ }
                }

                foreach ($server in $servers) {
                    $uuid = python -m automation.cli.generate_uuid $server
                    Write-Host "[INFO] UUID for $server`: $uuid"
                    $uuid | Out-File -FilePath "output\\${server}.uuid" -Encoding ascii
                }
                '''
            }
        }

        stage('Build Firmware ISOs') {
            when {
                expression { params.BUILD_STAGE in ['firmware', 'all'] }
            }
            steps {
                powershell '''
                python -m automation.cli.update_firmware_drivers ^
                  --server-list configs\\server_list.txt ^
                  --output-dir output\\firmware ^
                  --skip-download:${{ params.SKIP_DOWNLOAD }} ^
                  --dry-run:${{ params.DRY_RUN }}
                '''

                archiveArtifacts artifacts: 'output/firmware/**/*.json', allowEmptyArchive: true
                archiveArtifacts artifacts: 'output/firmware/**/*.iso', allowEmptyArchive: true
            }
            post {
                always {
                    powershell '''
                    if (Test-Path "output\\firmware\\results") {
                        Get-ChildItem "output\\firmware\\results\\*.json" | ForEach-Object {
                            $content = Get-Content $_.FullName | ConvertFrom-Json
                            Write-Host "Server: $($content.server) - Success: $($content.success)"
                        }
                    }
                    '''
                }
            }
        }

        stage('Build Windows ISOs') {
            when {
                expression { params.BUILD_STAGE in ['windows', 'all'] }
            }
            steps {
                powershell '''
                $baseIso = "${params.BASE_ISO_PATH}"
                if (-not (Test-Path $baseIso)) {
                    Write-Error "Base ISO not found: $baseIso"
                    exit 1
                }

                $servers = Get-Content configs\\server_list.txt | Where-Object { $_ -and -not $_.StartsWith('#') }

                if (params.SERVER_FILTER) {
                    $filterList = params.SERVER_FILTER -split ','
                    $servers = $servers | Where-Object { $filterList -contains $_ }
                }

                foreach ($server in $servers) {
                    Write-Host "\\n[INFO] Patching Windows ISO for: $server"
                    python -m automation.cli.patch_windows_security ^
                      --base-iso $baseIso ^
                      --server $server ^
                      --output-dir output\\patched ^
                      --dry-run:${{ params.DRY_RUN }}
                }
                '''

                archiveArtifacts artifacts: 'output/patched/**/*.json', allowEmptyArchive: true
                archiveArtifacts artifacts: 'output/patched/**/*.iso', allowEmptyArchive: true
            }
        }

        stage('Combine Deployment Packages') {
            when {
                expression { params.BUILD_STAGE in ['windows', 'all'] }
            }
            steps {
                powershell '''
                python -m automation.cli.build_iso ^
                  --config-dir configs ^
                  --output-dir output\\combined ^
                  --dry-run:${{ params.DRY_RUN }}
                '''

                powershell '''
                $date = Get-Date -Format "yyyyMMdd_HHmmss"
                $bundleName = "deployment_bundle_$date"
                Compress-Archive -Path "output\\combined\\**" -DestinationPath "output\\${bundleName}.zip" -Force
                Write-Host "Created deployment bundle: ${bundleName}.zip"
                '''
                archiveArtifacts artifacts: 'output/*.zip', allowEmptyArchive: true
            }
        }

        stage('Deploy') {
            when {
                expression { params.BUILD_STAGE in ['deploy', 'all'] }
            }
            steps {
                powershell '''
                python -m automation.cli.deploy_to_server ^
                  --method ${params.DEPLOY_METHOD} ^
                  --dry-run:${{ params.DRY_RUN }}
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'logs/deploy_*.json', allowEmptyArchive: true
                }
            }
        }

        stage('Vulnerability Scan') {
            when {
                expression { params.BUILD_STAGE in ['scan', 'all'] }
            }
            steps {
                powershell '''
                python -c "
import sys
from pathlib import Path
import json

reports_dir = Path('logs/scan_reports')
reports_dir.mkdir(parents=True, exist_ok=True)

print('[INFO] Vulnerability scanning placeholder')
print('[INFO] Configure Nessus or OpenVAS in Jenkins environment')
"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'logs/scan_reports/**', allowEmptyArchive: true
                }
            }
        }

        stage('OpsRamp Reporting') {
            when {
                expression { env.OPSRAMP_ENABLED == 'true' }
            }
            steps {
                powershell '''
                python -c "
from pathlib import Path
import json

results_dir = Path('output/results')
if results_dir.exists():
    for rf in results_dir.glob('*.json'):
        with open(rf) as f:
            r = json.load(f)
        print(f'Would report to OpsRamp: {r[\"server\"]} -> {r[\"success\"]}')
"
                '''
            }
        }

        stage('Audit & Reporting') {
            steps {
                powershell '''
                $date = Get-Date -Format "yyyy-MM-dd"
                $reportDir = "logs\\build_reports\\$date"
                if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Force -Path $reportDir }

                Copy-Item -Path "output\\results\\*.json" -Destination $reportDir -ErrorAction SilentlyContinue
                Copy-Item -Path "logs\\monitoring_sessions\\*.json" -Destination $reportDir -ErrorAction SilentlyContinue

                Write-Host "Audit report generated at: $reportDir"

                $summary = @{
                    build_date = $date
                    total_servers = 0
                    successful = 0
                    failed = 0
                    stages_completed = params.BUILD_STAGE
                }

                $resultFiles = Get-ChildItem "output\\results\\*.json" -ErrorAction SilentlyContinue
                if ($resultFiles) {
                    $summary.total_servers = $resultFiles.Count
                    foreach ($rf in $resultFiles) {
                        $data = Get-Content $rf.FullName | ConvertFrom-Json
                        if ($data.success) { $summary.successful++ } else { $summary.failed++ }
                    }
                }

                $summary | ConvertTo-Json -Depth 3 | Out-File "$reportDir\\summary.json"
                Write-Host "Summary: $($summary.successful)/$($summary.total_servers) successful"
                '''
                archiveArtifacts artifacts: 'logs/build_reports/**', allowEmptyArchive: true
            }
        }
    }

    post {
        success {
            mail to: 'automation-alerts@yourcompany.com',
                 subject: "✅ Build #${BUILD_NUMBER} SUCCEEDED: ${params.BUILD_STAGE}",
                 body: "Build ${BUILD_NUMBER} completed successfully.\nParameters: ${params}"
        }
        failure {
            mail to: 'automation-alerts@yourcompany.com',
                 subject: "❌ Build #${BUILD_NUMBER} FAILED: ${params.BUILD_STAGE}",
                 body: "Build ${BUILD_NUMBER} failed. Check Jenkins console output for details.\nParameters: ${params}"
        }
        always {
            cleanWs()
        }
    }
}
