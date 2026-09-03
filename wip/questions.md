# Questions and clarifications

<a id="top"></a>

## Table of Contents

These are all Microsoft Configuration Manager (ConfigMgr / SCCM / MECM) parameters. Here's what each does in plain terms:

| Parameter | What it is | When it's needed |
| --- | --- | --- |
| -Domain | The Active Directory domain the server should join after build (e.g. corp.example.com) | Only for post-build validation — verifying the server joined the domain correctly |
| -SiteCode | A 3-character ConfigMgr site identifier (e.g. P01) | Only when building a ConfigMgr bootable ISO — tells ConfigMgr which site to associate the media with |
| -ManagementPoint | The FQDN of the ConfigMgr server that hands out task sequences to clients (e.g. mp01.corp.local) | Only when building a ConfigMgr bootable ISO — WinPE contacts this server to get the task sequence |
| -DistributionPoint | The FQDN of the ConfigMgr server that stores OS images, drivers, and packages (e.g. dp01.corp.local) | Only when building a ConfigMgr bootable ISO — WinPE downloads content from here |
| -SiteServer | The FQDN of the ConfigMgr site server, used as a fallback for PowerShell Remoting | Only when building a ConfigMgr bootable ISO — fallback for PSRemoting |

Key point: All of these are only needed in Build mode (when ConfigMgr creates the bootable ISO). If you're using -ExternalIsoPath to deploy a client-supplied ISO directly (which is the current design), none of these parameters are required — the ISO build/publish steps are skipped entirely.

The documentation already notes this:

```pwsh
ConfigMgr parameters (-SiteCode, -ManagementPoint, -DistributionPoint, -BootImageName, -TaskSequenceName, -SiteServer)
```

: only needed in Build mode. When using `-ExternalIsoPath`, these are not required because the ISO build/publish steps are skipped.

Are these parameters something you use in your environment, or should they be removed/deprecated since you're deploying client-supplied ISOs directly?

**Check with JS if these are required**

`-TaskSequenceName`
The name of the ConfigMgr "task sequence" — this is ConfigMgr's automation script that installs the OS, drivers, apps, etc. In the current code it's informational only — it's used to validate that the task sequence exists in ConfigMgr, but doesn't drive the build when using External ISO mode. If you're not building ConfigMgr media, this isn't needed.

`-Skip` parameters (all optional, none required)

These are optional bypass switches for validation checks. They exist so you can skip checks you don't need or that are failing for known reasons:

| Parameter | What it skips | Why you'd use it |
| --- | --- | --- |
| -SkipPreBuild | All pre-build validation | When you've already validated and just want to re-run |
| -SkipOneView | Server resolution via OneView | When you already know the iLO IP and don't need OneView |
| -SkipIlo | iLO credential check | When iLO creds are already verified |
| -SkipDpMp | Management Point / Distribution Point reachability | Not needed for External ISO mode |
| -SkipIsoUrl | ISO URL reachability check | When running offline or ISO is already verified |

None are required — they're all optional conveniences.

`-Force`
Acknowledges the server is powered On. In the actual build command (Invoke-PhysicalServerBuild), this is required to reboot a running server. In Configure-PhysicalBuild it's informational only (that command never reboots anything).

`-Deploy`
Skips the interactive APPROVE prompt and immediately executes the build. Useful for automation/scripts where no human is present to type APPROVE. Alias: -Execute.

`-PassThru`
Returns the structured result object (hashtable) for scripting. By default, the command only prints a human-readable report. With `-PassThru`, you can capture the result:

```pwsh
$result = Configure-PhysicalBuild -ServerIdentifier srv01 ... -PassThru -Deploy
if (-not $result.Success) { Handle-Error }
```

Summary: None of these are required for normal operation. The typical usage is just:

```pwsh
Configure-PhysicalBuild -ServerIdentifier srv01 -OneViewHost oneview.corp.local `
    -ExternalIsoPath '\\fileserver\isos\Win2025.iso' -GuardRail 'srv01'
```

**Then type APPROVE when prompted.**
