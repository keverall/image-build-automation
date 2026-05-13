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
            choices: ['ilo', 'pxe', 'redfish'],
            description: 'Deployment method (for deploy stage)'
        )
        booleanParam(
            name: 'SKIP_DOWNLOAD',
            defaultValue: false,
            description: 'Skip firmware/driver download (use existing)'
        )
    }

    environment {
        // HPE credentials (from Jenkins credentials store)
        HPE_DOWNLOAD_USER = credentials('hpe-download-user')
        HPE_DOWNLOAD_PASS = credentials('hpe-download-pass')

        // iLO credentials
        ILO_USER = credentials('ilo-user')
        ILO_PASSWORD = credentials('ilo-password')

        // OpsRamp integration (optional)
        OPSRAMP_ENABLED = 'true'
        OPSRAMP_CLIENT_ID = credentials('opsramp-client-id')
        OPSRAMP_CLIENT_SECRET = credentials('opsramp-client-secret')
        OPSRAMP_TENANT_ID = credentials('opsramp-tenant-id')

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

                # Verify Python syntax
                python -m py_compile scripts\\generate_uuid.py
                python -m py_compile scripts\\build_iso.py
                python -m py_compile scripts\\update_firmware_drivers.py
                python -m py_compile scripts\\patch_windows_security.py
                python -m py_compile scripts\\deploy_to_server.py
                python -m py_compile scripts\\monitor_install.py
                python -m py_compile scripts\\opsramp_integration.py

                # Validate JSON configs
                python -c "import json; json.load(open('configs/hpe_firmware_drivers_nov2025.json'))"
                python -c "import json; json.load(open('configs/windows_patches.json'))"
                python -c "import json; json.load(open('configs/opsramp_config.json'))"
                '''
            }
        }

        stage('Generate UUIDs') {
            when {
                expression { params.BUILD_STAGE in ['firmware', 'windows', 'deploy', 'all'] }
            }
            steps {
                powershell '''
                # Generate UUIDs for filtered servers
                $servers = Get-Content configs\\server_list.txt | Where-Object { $_ -and -not $_.StartsWith('#') }

                if (params.SERVER_FILTER) {
                    $filterList = params.SERVER_FILTER -split ','
                    $servers = $servers | Where-Object { $filterList -contains $_ }
                }

                foreach ($server in $servers) {
                    $uuid = python scripts\\generate_uuid.py $server
                    Write-Host "[INFO] UUID for $server`: $uuid"
                    # Store UUID for later stages
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
                python scripts\\update_firmware_drivers.py ^
                  --server-list configs\\server_list.txt ^
                  --output-dir output\\firmware ^
                  --skip-download:${{ params.SKIP_DOWNLOAD }} ^
                  --dry-run:${{ params.DRY_RUN }}
                '''

                // Archive results
                archiveArtifacts artifacts: 'output/firmware/**/*.json', allowEmptyArchive: true
                archiveArtifacts artifacts: 'output/firmware/**/*.iso', allowEmptyArchive: true
            }
            post {
                always {
                    powershell '''
                    # Collect build results
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
                # Validate base ISO
                $baseIso = "${params.BASE_ISO_PATH}"
                if (-not (Test-Path $baseIso)) {
                    Write-Error "Base ISO not found: $baseIso"
                    exit 1
                }

                # Build for each server
                $servers = Get-Content configs\\server_list.txt | Where-Object { $_ -and -not $_.StartsWith('#') }

                if (params.SERVER_FILTER) {
                    $filterList = params.SERVER_FILTER -split ','
                    $servers = $servers | Where-Object { $filterList -contains $_ }
                }

                foreach ($server in $servers) {
                    Write-Host "\\n[INFO] Patching Windows ISO for: $server"
                    python scripts\\patch_windows_security.py ^
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
                python scripts\\build_iso.py ^
                  --config-dir configs ^
                  --output-dir output\\combined ^
                  --dry-run:${{ params.DRY_RUN }}
                '''

                // Create deployment bundle
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
                python scripts\\deploy_to_server.py ^
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
                # Scan patched ISOs
                python -c "
import sys
from pathlib import Path
import json

reports_dir = Path('logs/scan_reports')
reports_dir.mkdir(parents=True, exist_ok=True)

# Placeholder scan - integrate Nessus/OpenVAS CLI here
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
                # Send build metrics to OpsRamp
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
                # Generate daily audit report
                $date = Get-Date -Format "yyyy-MM-dd"
                $reportDir = "logs\\build_reports\\$date"
                if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Force -Path $reportDir }

                # Copy all JSON results to report directory
                Copy-Item -Path "output\\results\\*.json" -Destination $reportDir -ErrorAction SilentlyContinue
                Copy-Item -Path "logs\\monitoring_sessions\\*.json" -Destination $reportDir -ErrorAction SilentlyContinue

                Write-Host "Audit report generated at: $reportDir"

                # Generate summary
                $summary = @{
                    build_date = $date
                    total_servers = 0
                    successful = 0
                    failed = 0
                    stages_completed = params.BUILD_STAGE
                }

                # Count results
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
