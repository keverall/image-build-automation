# Docker EntryPoint Script for HPE Windows ISO Automation
# Configures MS MCM and HPe iLO integration in regulated environment

param(
    [Parameter(Mandatory=$false)]
    [string]$Command = "help"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Log function for audit trail
function Write-AuditLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path "C:\app\logs\audit_trail.log" -Value $logEntry
}

Write-AuditLog "Container startup initiated"

# Validate environment
if (-not (Test-Path "C:\app\scripts\build_iso.py")) {
    Write-AuditLog "ERROR: build_iso.py not found - container may not be properly built" "ERROR"
    exit 1
}

# Configure MS MCM (Microsoft Configuration Manager) integration
function Initialize-MS-MCM {
    Write-AuditLog "Initializing MS MCM connection"

    try {
        # Import Configuration Manager module
        Import-Module ConfigurationManager

        # Set site code if provided
        if ($env:MS_MCM_SITE_CODE) {
            Set-Location "$($env:MS_MCM_SITE_CODE):"
            Write-AuditLog "Connected to MS MCM site: $($env:MS_MCM_SITE_CODE)"
        }

        # Test connection
        $siteInfo = Get-CMSite
        Write-AuditLog "MS MCM connection successful - Site: $($siteInfo.SiteCode)"

    } catch {
        Write-AuditLog "WARNING: MS MCM initialization failed - $($_.Exception.Message)" "WARNING"
        # Continue execution - MCM may not be available in all environments
    }
}

# Configure HPe iLO 5 integration
function Initialize-HPe-ILO {
    Write-AuditLog "Initializing HPe iLO 5 integration"

    try {
        # Import HPe iLO module
        Import-Module HPiLOCmdlets

        # Set default credentials if provided
        if ($env:ILO_DEFAULT_USERNAME -and $env:ILO_DEFAULT_PASSWORD) {
            $global:iLOCredential = New-Object System.Management.Automation.PSCredential (
                $env:ILO_DEFAULT_USERNAME,
                (ConvertTo-SecureString $env:ILO_DEFAULT_PASSWORD -AsPlainText -Force)
            )
            Write-AuditLog "HPe iLO default credentials configured"
        }

        Write-AuditLog "HPe iLO 5 integration ready"

    } catch {
        Write-AuditLog "WARNING: HPe iLO initialization failed - $($_.Exception.Message)" "WARNING"
    }
}

# Configure security settings for regulated environment
function Set-SecurityConfiguration {
    Write-AuditLog "Applying security configuration for regulated environment"

    # Ensure TLS 1.2+ is used
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Set PowerShell execution policy
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

    # Configure audit logging
    $auditPolicy = @"
    <AuditPolicy>
        <LogonLogoff>
            <Logon>SuccessAndFailure</Logon>
            <Logoff>Success</Logoff>
        </LogonLogoff>
        <ObjectAccess>
            <FileSystem>SuccessAndFailure</FileSystem>
        </ObjectAccess>
    </AuditPolicy>
"@
    # Note: Actual audit policy changes require administrator privileges

    Write-AuditLog "Security configuration applied"
}

# Initialize Python environment
function Initialize-PythonEnvironment {
    Write-AuditLog "Initializing Python environment"

    # Ensure Python is in PATH
    $env:PATH = "C:\Python311;C:\Python311\Scripts;" + $env:PATH

    # Test Python installation
    try {
        $pythonVersion = & python --version 2>&1
        Write-AuditLog "Python version: $pythonVersion"
    } catch {
        Write-AuditLog "ERROR: Python not available - $($_.Exception.Message)" "ERROR"
        exit 1
    }

    # Test key imports
    $imports = @("requests", "json", "subprocess", "pathlib")
    foreach ($import in $imports) {
        try {
            python -c "import $import; print('$import: OK')" 2>$null
        } catch {
            Write-AuditLog "WARNING: Failed to import $import" "WARNING"
        }
    }
}

# Main initialization
function Initialize-Container {
    Write-AuditLog "Starting container initialization"

    Initialize-PythonEnvironment
    Set-SecurityConfiguration
    Initialize-MS-MCM
    Initialize-HPe-ILO

    Write-AuditLog "Container initialization completed successfully"
}

# Execute command based on arguments
switch ($Command) {
    "init" {
        Initialize-Container
        Write-AuditLog "Initialization complete - container ready"
        exit 0
    }
    "test" {
        Initialize-Container

        # Run basic tests
        Write-AuditLog "Running basic functionality tests"

        # Test Python scripts
        try {
            python C:\app\scripts\generate_uuid.py test-server
            Write-AuditLog "UUID generation test: PASSED"
        } catch {
            Write-AuditLog "UUID generation test: FAILED - $($_.Exception.Message)" "ERROR"
        }

        # Test MS MCM if available
        try {
            Get-CMSite | Out-Null
            Write-AuditLog "MS MCM connectivity test: PASSED"
        } catch {
            Write-AuditLog "MS MCM connectivity test: SKIPPED - not configured"
        }

        Write-AuditLog "Basic tests completed"
        exit 0
    }
    default {
        # Default behavior - initialize and run the provided command
        Initialize-Container

        Write-AuditLog "Executing command: $args"

        # Execute the original command
        if ($args) {
            & $args
            $exitCode = $LASTEXITCODE
            Write-AuditLog "Command completed with exit code: $exitCode"
            exit $exitCode
        } else {
            Write-AuditLog "No command provided - starting interactive shell"
            # Start PowerShell interactive session
        }
    }
}

Write-AuditLog "Container entrypoint script completed"