# ⚠ Superseded — ConfigMgr Bootable Media Automation Plan

<a id="top"></a>

## Table of Contents

> **This plan is superseded.**
>
> The workflow it described has **shipped** and was later **consolidated into the single
> build command `Configure-PhysicalBuild`** (the retired `New-IsoBuild`, `Publish-BootIso`,
> `Invoke-IsoDeploy` and `Start-PhysicalServerBuild` commands were merged into it; firmware is
> applied as part of that build step). The command surface, parameters and safety gates
> (`-GuardRail`, `-Force`, `-DryRun`) described here are no longer current.
>
> **Authoritative references (use these instead):**
> - Current design / runbook authority: [`runbook-requirements.md`](./runbook-requirements.md#top)
> - Current command surface: [`automation_commands.md`](./automation_commands.md#top)
> - Current test authority: [`AUTOMATION_TEST_PLAN.md`](./AUTOMATION_TEST_PLAN.md#top)
>
> **Retained design rationale (audit trail, 2–3 lines):** the implementation chose **Redfish
> (`/redfish/v1/`) over iLO REST** for iLO control and **HTTPS ISO serving** so iLO can mount a
> URL directly; Windows OS patching remained **out of scope (Bladelogic's responsibility)** — this
> code builds new servers only.

*This file is kept intentionally as a short stub so existing inbound links from the documentation
index, API reference and README remain valid. It is not a live plan.*
