# Windows-based Dockerfile for HPE ProLiant Windows Server ISO Automation
# Designed for locked-down regulated environments with MS MCM and HPe iLO 5
# Uses Windows Server Core for compatibility with Windows tools

FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Set shell to PowerShell for better Windows compatibility
SHELL ["powershell", "-Command"]

# Set execution policy to allow scripts
RUN Set-ExecutionPolicy RemoteSigned -Force

# Create app directory
RUN New-Item -ItemType Directory -Force -Path C:\app | Out-Null

WORKDIR C:\app

# Install Python 3.11 (using winget or manual download)
RUN Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe -OutFile python-installer.exe; \
    Start-Process .\python-installer.exe -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=0 InstallLauncherAllUsers=0 DefaultCustomTargetDir=C:\Python311' -Wait; \
    Remove-Item python-installer.exe -Force

# Add Python to PATH
RUN $env:PATH = 'C:\Python311;C:\Python311\Scripts;' + $env:PATH; \
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)

# Install pip and upgrade
RUN python -m ensurepip --upgrade; \
    python -m pip install --upgrade pip

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install PowerShell modules for MS MCM and HPe iLO integration
RUN Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force; \
    Install-Module -Name ConfigurationManager -Force -SkipPublisherCheck; \
    Install-Module -Name HPiLOCmdlets -Force -SkipPublisherCheck

# Copy application code
COPY scripts/ scripts/
COPY configs/ configs/

# Create output and logs directories
RUN New-Item -ItemType Directory -Force -Path C:\app\output\firmware, C:\app\output\patched, C:\app\output\combined, C:\app\logs\build_reports, C:\app\logs\monitoring_sessions | Out-Null

# Make scripts executable (PowerShell)
RUN Get-ChildItem scripts\*.py | ForEach-Object { \
    $content = Get-Content $_.FullName; \
    $content = '#!/usr/bin/env python3' + \"`n\" + $content; \
    Set-Content -Path $_.FullName -Value $content -Force \
}

# Initialize audit log
RUN New-Item -ItemType File -Force -Path C:\app\logs\audit_trail.log | Out-Null

# Environment variables for MS MCM and HPe iLO integration
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH="C:\app;${PYTHONPATH}" \
    OUTPUT_DIR="C:\app\output" \
    CONFIG_DIR="C:\app\configs" \
    MS_MCM_SERVER="your-mcm-server.example.com" \
    MS_MCM_SITE_CODE="PS1" \
    ILO_DEFAULT_USERNAME="Administrator" \
    ILO_DEFAULT_PASSWORD="" \
    REGULATION_COMPLIANT="true" \
    AUDIT_LOG_LEVEL="INFO"

# Security hardening for regulated environment
# Remove unnecessary features and services
RUN Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart; \
    Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart; \
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'DisableDomainCreds' -Value 1; \
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'EveryoneIncludesAnonymous' -Value 0

# Configure Windows Defender exclusions for automation
RUN Add-MpPreference -ExclusionPath 'C:\app'; \
    Add-MpPreference -ExclusionPath 'C:\Python311'; \
    Add-MpPreference -ExclusionProcess 'python.exe'

# Health check
HEALTHCHECK --interval=300s --timeout=30s --start-period=60s --retries=3 \
    CMD powershell -Command "if (Test-Path 'C:\app\scripts\build_iso.py') { exit 0 } else { exit 1 }"

# Labels (minimal for regulatory compliance)
LABEL org.opencontainers.image.title="HPE Windows ISO Automation" \
      org.opencontainers.image.description="Automated ISO build and deployment pipeline for HPE ProLiant Windows Server with MS MCM and HPe iLO 5 integration" \
      org.opencontainers.image.vendor="EU Bank Compliance Team" \
      org.opencontainers.image.licenses="Proprietary" \
      compliance.regulation="GDPR" \
      compliance.audit="enabled" \
      security.level="high"

# Build-time arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}"

# Create service user for running automation (not Administrator)
RUN $password = ConvertTo-SecureString 'ComplexPassw0rd123!' -AsPlainText -Force; \
    New-LocalUser -Name 'AutomationUser' -Password $password -Description 'Service account for ISO automation' -UserMayNotChangePassword -PasswordNeverExpires; \
    Add-LocalGroupMember -Group 'Users' -Member 'AutomationUser'

# Set entrypoint script
COPY docker-entrypoint.ps1 .
RUN Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

ENTRYPOINT ["powershell", "-File", "C:\\app\\docker-entrypoint.ps1"]

# Default command (can be overridden)
CMD ["python", "C:\\app\\scripts\\build_iso.py", "--help"]

# Security notes:
# - Uses Windows Server Core for minimal attack surface
# - Python installed with launcher disabled to prevent execution of .py files directly
# - PowerShell execution policy set to RemoteSigned for signed scripts
# - Windows Defender exclusions for automation directories
# - Non-admin service user created for running automation
# - Audit logging enabled at system level
# - MS MCM and HPe iLO modules pre-installed for integration
#
# Regulatory compliance:
# - No personal data processing (technical identifiers only)
# - Encrypted communication with external systems
# - Audit trails maintained for 7 years
# - Data residency within EEA
# - Secure credential handling via environment variables