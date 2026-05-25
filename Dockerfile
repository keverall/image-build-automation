# Windows-based Dockerfile for HPE ProLiant Windows Server ISO Automation
# Designed for locked-down regulated environments

FROM mcr.microsoft.com/powershell:7.4

SHELL ["pwsh", "-Command"]

# Set execution policy to allow scripts
RUN Set-ExecutionPolicy RemoteSigned -Force

# Create app directory
RUN New-Item -ItemType Directory -Force -Path C:\app | Out-Null

WORKDIR C:\app

# Install PowerShell modules
RUN Set-PSRepository PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck

# Copy application code
COPY src/ src/
COPY configs/ configs/

# Create output and logs directories
RUN New-Item -ItemType Directory -Force -Path C:\app\output\firmware, C:\app\output\patched, C:\app\output\combined, C:\app\logs\build_reports, C:\app\logs\monitoring_sessions | Out-Null

# Environment variables
ENV OUTPUT_DIR="C:\app\output" \
    CONFIG_DIR="C:\app\configs" \
    REGULATION_COMPLIANT="true" \
    AUDIT_LOG_LEVEL="INFO"

# Health check
HEALTHCHECK --interval=300s --timeout=30s --start-period=60s --retries=3 \
    CMD pwsh -Command "if (Test-Path 'C:\app\src\powershell\Automation\Public\*.ps1') { exit 0 } else { exit 1 }"

# Labels
LABEL org.opencontainers.image.title="HPE Windows ISO Automation" \
      org.opencontainers.image.description="PowerShell automation for HPE ProLiant Windows Server ISO builds" \
      org.opencontainers.image.vendor="HPE" \
      org.opencontainers.image.licenses="MIT"

# Entrypoint
COPY docker-entrypoint.ps1 .
RUN Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

ENTRYPOINT ["pwsh", "-File", "C:\\app\\docker-entrypoint.ps1"]

CMD ["-Command", "Get-Help *"]