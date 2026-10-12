# Testing Issues
The latest failure is still isolated to the iLO authentication guard. OneView is working:

```text
Oneview_Maintenance_Enable:
  Success: True
  Skipped: True
  Reason: Server already in maintenance mode
```

I enhanced the diagnostics.

## Logs to send back

After the next run, send all of these audit files from the Windows client (the
serial-specific files are required to correlate OneView, build, and iLO steps):

```text
generated/logs/audit/*_prebuild_CZ22420JCM.json
generated/logs/audit/*_enable_CZ22420JCM.json
generated/logs/audit/*_build_CZ22420JCM.json
generated/logs/audit/*_disable_CZ22420JCM.json
```

The most important one will be the audit file containing:

```text
Ilo_Maintenance_Guard
```

You can list the newest audit files with:

```powershell
Get-ChildItem .\generated\logs\audit -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name, Length, LastWriteTime
```

Also send the relevant `test.log` section from:

```text
[OneView] Server ...
```

through:

```text
Ilo_Maintenance_Guard
```

Do **not** send passwords, full SSO tokens, credential objects, or complete unredacted SSO objects.

## New safe diagnostics

The audit result now records only metadata:

```text
AuthMode
TokenSource
TokenPresent
TokenLength
RawTokenPresent
RawTokenLength
RawTokenHasSessionKey
SkipCertificateCheck
BaseUrl
AuthAttempts
AttemptModes
LastRequestUri
LastError
```

The actual token values are never logged.

Example diagnostic output will look like:

```text
auth_mode: oneview_sso
token_source: SecurityToken
token_present: True
token_length: 64
raw_token_present: True
raw_token_has_sessionKey: True
skip_certificate_check: True
attempt_modes:
  - normalized_xauth+redfish_session
  - raw_xauth+redfish_session_retry
last_request_uri: https://10.30.14.15/redfish/v1/Systems/1
last_error: ...
```

## Additional behavior

If OneView SSO still returns 401 during an interactive run, the build now prompts once for direct iLO credentials and retries the status check. If that succeeds, the same credential is retained for the later ISO mount/reboot. Automated runs still fail closed.

Validation after the diagnostic changes:

```text
590 tests passed
0 failed
153 PowerShell files linted successfully
```

The diagnostic changes are currently uncommitted in:

```text
src/powershell/Automation/Automation.psm1
src/powershell/Automation/Public/Invoke-IloRedfish.ps1
src/powershell/Automation/Public/Start-PhysicalServerBuild.ps1
```


PowerShell, using the file’s modified date:

```powershell
Get-ChildItem .\generated\logs\audit -File |
    Where-Object { $_.LastWriteTime -ge (Get-Date).Date } |
    Sort-Object LastWriteTime -Descending |
    Select-Object Name, Length, LastWriteTime
```

Short form:

```powershell
ls .\generated\logs\audit -File |
    ? LastWriteTime -ge (Get-Date).Date |
    sort LastWriteTime -Descending
```

Because the new filenames begin with a UTC timestamp, you can also filter by today’s UTC prefix:

```powershell
$today = [DateTime]::UtcNow.ToString('yyyy-MM-dd')

Get-ChildItem .\generated\logs\audit -File |
    Where-Object Name -like "${today}*" |
    Sort-Object Name -Descending
```

The `LastWriteTime` version is safer because it also finds files created with the older filename format.