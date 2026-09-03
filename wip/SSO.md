# Single Sign-On (SSO) Architecture

<a id="top"></a>

## Table of Contents

- [Executive Summary (for Leadership)](#executive-summary-for-leadership)
- [Technical Summary (for Engineering Management)](#technical-summary-for-engineering-management)
- [Overview  ](#overview)
- [1. Identity Infrastructure Layer (Windows Networks & Active Directory)](#1-identity-infrastructure-layer-windows-networks-active-directory)
  - [1.1 Hybrid AD DS ↔ Entra ID Topology (the sync bridge)](#11-hybrid-ad-ds-entra-id-topology-the-sync-bridge)
- [2. Bare-Metal Management Layer (iLO & Redfish)](#2-bare-metal-management-layer-ilo-redfish)
- [3. Out-of-Band Network Access (ZPE Nodegrid)](#3-out-of-band-network-access-zpe-nodegrid)
- [4. Management & Orchestration Layer (HPE OneView & MCM)](#4-management-orchestration-layer-hpe-oneview-mcm)
- [5. Monitoring & Alerting Layer (Microsoft SCOM)](#5-monitoring-alerting-layer-microsoft-scom)
- [6. iLO Trust-by-Certificate — Configuration Steps](#6-ilo-trust-by-certificate-configuration-steps)
  - [6.1 Prerequisites](#61-prerequisites)
  - [6.2 Step 1 — Generate a Certificate Signing Request (CSR) from iLO](#62-step-1-generate-a-certificate-signing-request-csr-from-ilo)
  - [6.3 Step 2 — Issue the Certificate from the Enterprise CA](#63-step-2-issue-the-certificate-from-the-enterprise-ca)
  - [6.4 Step 3 — Install the Certificate on iLO (Trust by Certificate)](#64-step-3-install-the-certificate-on-ilo-trust-by-certificate)
  - [6.5 Step 4 — Configure the LDAP/AD Directory Integration](#65-step-4-configure-the-ldapad-directory-integration)
  - [6.6 Step 5 — Map AD Groups to iLO Roles (Trust-by-Certificate Group Mapping)](#66-step-5-map-ad-groups-to-ilo-roles-trust-by-certificate-group-mapping)
  - [6.7 Step 6 — OneView Brokered SSO (optional, for Gen10+/Synergy)](#67-step-6-oneview-brokered-sso-optional-for-gen10synergy)
  - [6.8 Verification](#68-verification)
- [7. ZPE Nodegrid — Azure AD SAML Claim Mapping (Step-by-Step)](#7-zpe-nodegrid-azure-ad-saml-claim-mapping-step-by-step)
  - [7.1 Part A — Define Azure AD Side (Enterprise Application + Claims)](#71-part-a-define-azure-ad-side-enterprise-application-claims)
  - [7.2 Part B — Define Nodegrid Side (Service Provider)](#72-part-b-define-nodegrid-side-service-provider)
  - [7.3 Verification](#73-verification)
- [8. Windows Interactive & RDP SSO — Preventing Account Lockouts](#8-windows-interactive-rdp-sso-preventing-account-lockouts)
  - [8.1 Core principle: one credential, no per-server prompts](#81-core-principle-one-credential-no-per-server-prompts)
  - [8.2 Domain Controller / AD-side controls (prevent lockout at source)](#82-domain-controller-ad-side-controls-prevent-lockout-at-source)
  - [8.3 Step-by-step: Configure Windows workstation and servers](#83-step-by-step-configure-windows-workstation-and-servers)
  - [8.4 RDP launch pattern the engineers should use](#84-rdp-launch-pattern-the-engineers-should-use)
  - [8.5 MFA scoping (prevent MFA loops / re-authentication storms)](#85-mfa-scoping-prevent-mfa-loops-re-authentication-storms)
- [Core Security Architecture Matrix](#core-security-architecture-matrix)
- [References](#references)

<a id="executive-summary-for-leadership"></a>

## Executive Summary (for Leadership)

- **The problem today**: engineers authenticate interactively to 50+ servers per day, causing frequent AD account lockouts and slow, ticket-bound (BMC iRequest) unlock cycles that cost engineering hours and delay incident response.
- **The fix**: a single identity per engineer, issued once per session, reused silently across every system — Windows servers, iLO, consoles, and monitoring — eliminating per-server passwords and the lockouts they cause.
- **Compliance strengthened, not weakened**: MFA and Conditional Access are enforced once at the entry point, satisfying DORA, GDPR, and PSD2/3 Strong Customer Authentication, with every access centrally attributable for audit.
- **Reuses existing investment**: built on the bank's current AD DS / Microsoft Entra ID estate, enterprise PKI, and existing HPE/ZPE/Microsoft tooling — no new identity platform required.
- **Outcome**: one sign-on per day instead of 50+, near-zero lockout tickets, faster outage response, and a defensible audit trail.

<a id="technical-summary-for-engineering-management"></a>

## Technical Summary (for Engineering Management)

- **Identity plane**: on-prem AD DS is bridged to Microsoft Entra ID via Entra Connect (PHS + PTA); hybrid-joined workstations issue a Kerberos TGT and Entra PRT from a single logon (Section 1.1).
- **Per-layer SSO**: RDP/WinRM reuse the TGT via Restricted Admin + constrained delegation (Section 8); web/console access uses SAML 2.0 from Entra ID with claim-to-group mapping on ZPE Nodegrid (Section 7); bare-metal access uses iLO Trust-by-Certificate with AD group-to-role mapping over LDAPS (Section 6).
- **MFA placement**: enforced exactly once (workstation logon / Nodegrid SAML); never re-prompted mid-session — this is what removes the lockout trigger while preserving SCA.
- **Access model**: Tier-0/1/2 AD security groups map to iLO roles, Nodegrid groups, OneView roles, and local Remote Desktop Users — one group change grants/revokes estate-wide.
- **Sections 6–8 contain the actionable step-by-step configurations** (iLO cert enrolment, Nodegrid SAML claims, RDP GPOs); Sections 1–5 describe the architecture they implement.

<a id="overview"></a>

## Overview  

- Implementing Single Sign-On (SSO) in a highly regulated EU banking environment
- subject to strict compliance frameworks - DORA, GDPR, and PSD2/3 Strong Customer Authentication
- involves unifying modern web-based identity management with legacy datacentre infrastructure.
- In a Windows network hosting HPE ProLiant infrastructure, 
- this is achieved by mapping Active Directory (AD) / Azure AD (Entra ID) identities to different
  - hardware, management, and monitoring tiers
  - using explicit trust boundaries. [1](#ref-1)
  - A complete architecture overview of how these distinct elements are bridged into a single identity control plane follows below.

------------------------------

<a id="1-identity-infrastructure-layer-windows-networks-active-directory"></a>

## 1. Identity Infrastructure Layer (Windows Networks & Active Directory)

Central source of truth is Active Directory Domain Services (AD DS) combined with an identity provider (IdP) like Microsoft Entra ID / ADFS to enforce multi-factor authentication (MFA) and conditional access policies before granting an SSO token.

- All administrative identities belong to tiered AD security groups (e.g., Tier-0 for Domain Admins/Hardware controllers).
- Open standards are heavily enforced: SAML 2.0 / OIDC are used for web portals, while secure Kerberos or LDAP over TLS (LDAPS, Port 636) handles legacy backend authentications. [2](#ref-2, [3](#ref-3

<a id="11-hybrid-ad-ds-entra-id-topology-the-sync-bridge"></a>

### 1.1 Hybrid AD DS ↔ Entra ID Topology (the sync bridge)

The whole SSO model rests on a single identity control plane: on-prem AD DS is bridged to Microsoft Entra ID so each engineer has **one identity** that exists in both worlds.

- **Entra Connect sync**: Microsoft Entra Connect (formerly Azure AD Connect) runs on-prem and synchronises users, groups, and password hashes to Entra ID.
  - **PHS (Password Hash Sync)** — enabled as baseline; permits cloud sign-in and acts as the fallback if on-prem auth is unavailable.
  - **PTA (Pass-through Authentication)** — validates passwords against the on-prem DC in real time (no password material stored in the cloud).
  - **ADFS** — legacy federation path, still present in large banking estates; being phased out toward PHS+PTA.
- **Hybrid join**: engineer workstations are hybrid-joined so a single logon issues **both** a Kerberos TGT (on-prem world: RDP, WinRM, iLO LDAPS) and an Entra ID Primary Refresh Token (cloud world: SAML/OIDC web apps, Nodegrid, Conditional Access).
- **Result**: AD group membership (Tier-0/1/2) flows everywhere — iLO roles, Nodegrid local groups, OneView roles, RDP Users — so one group change grants or revokes access across the entire estate.

| Layer | Protocol | How SSO happens |
| --- | --- | --- |
| Workstation / jump box | Kerberos + hybrid Entra join | One logon → Kerberos TGT + Entra PRT issued together |
| RDP / WinRM / SMB to 50+ servers | Kerberos | TGT silently reused (Section 8 — Restricted Admin + delegation) |
| Web apps / Nodegrid | SAML 2.0 / OIDC | Entra ID checks the PRT → SAML assertion, no re-prompt; MFA/CA enforced here (Section 7) |
| iLO / Redfish | LDAPS + Trust-by-Cert | iLO binds LDAPS to AD DS, consumes group membership (Section 6) |
| OneView / SCOM / MECM | Kerberos / AD login domain | Native Windows auth, group-to-role mapping |

<a id="2-bare-metal-management-layer-ilo-redfish"></a>

## 2. Bare-Metal Management Layer (iLO & Redfish)

To prevent engineers from using shared local administrator accounts on HPE ProLiant servers, individual bare-metal access is tied back to AD. [4](#ref-4) 

- HPE iLO (Integrated Lights-Out): iLO is configured using Trust by Certificate mode. The bank installs enterprise CA-signed certificates onto the iLO chips. In the HPE SSO settings, iLO is configured to trust assertions from the parent manager software (HPE OneView). Additionally, iLO directories map AD Security Groups natively to specific iLO roles (e.g., Admin, Remote Console, Read-Only) using LDAPS. [3](#ref-3), [5](#ref-5), [6](#ref-6), [7](#ref-7)

- Redfish API: Redfish is the modern RESTful replacement for IPMI/SNMP. For automated scripts or infrastructure-as-code, SSO is achieved via Session Tokens. A user authenticates securely via the /redfish/v1/SessionService/Sessions endpoint using their AD credentials, receives a temporary X-Auth-Token, and passes it in subsequent REST API headers. For server-to-server operations (like automated agents), HPE ProLiant Gen12+ utilizes Application Accounts / Tokens, minimizing human credential leakage. [8](#ref-8), [9](#ref-9), [10](#ref-10), [11](#ref-11)
  

<a id="3-out-of-band-network-access-zpe-nodegrid"></a>

## 3. Out-of-Band Network Access (ZPE Nodegrid)

Nodegrid serves as the critical console server infrastructure, providing access to hardware when the production network is down.

- SAML 2.0 Web SSO: Nodegrid devices are configured as Service Providers (SP) 
- linked to the bank's central identity provider (e.g., Azure AD/Entra ID) using XML Metadata exchange. 
- An engineer logging into the Nodegrid UI is redirected to the bank's portal to fulfill MFA requirements. [12](#ref-12), [13](#ref-13), [14](#ref-14), [15](#ref-15)
- Console/CLI SSO & Authorization: Once authenticated via SAML, the user's group claims (e.g., memberOf) are evaluated. 
- Nodegrid maps these claims to internal device access groups, 
- giving the user instant pass-through access (via serial/SSH) to specific ProLiant iLO ports without needing to log into the target servers a second time. [2](#ref-2), [13](#ref-13), [16](#ref-16), [17](#ref-17)

<a id="4-management-orchestration-layer-hpe-oneview-mcm"></a>

## 4. Management & Orchestration Layer (HPE OneView & MCM)

- **HPE OneView** (formerly HPE OpenView): OneView acts as the core controller for the entire ProLiant server pool.
- It integrates natively with Active Directory login domains. Role-Based Access Control (RBAC)
- maps AD groups directly to OneView roles (e.g., Infrastructure Administrator).
- Because OneView acts as a certificate authority/broker for the underlying hardware,
- logging into OneView via AD automatically generates an implicit SSO token to launch the iLO Remote Console for any managed server seamlessly.
- **MCM**(Microsoft Endpoint Configuration Manager / MECM): Formerly SCCM, MCM natively integrates into the Windows Domain infrastructure. 
- SSO is handled implicitly through Windows Kerberos Authentication. 
- Because the engineer logs into their Windows jump box with AD credentials, 
- MCM honours their token, granting them RBAC rights to manage ProLiant OS deployment and configuration tasks without prompting for a login. [18](#ref-18), [19](#ref-19), [20](#ref-20), [21](#ref-21), [22](#ref-22)

<a id="5-monitoring-alerting-layer-microsoft-scom"></a>

## 5. Monitoring & Alerting Layer (Microsoft SCOM)

- SCOM (System Center Operations Manager): Much like MCM, SCOM relies fully on Windows Kerberos authentication and Active Directory architecture. 
- SCOM management groups are secured via AD global security groups.
- HPE OneView Management Pack for SCOM: To achieve seamless visibility, 
- the HPE SCOM Management Pack is deployed. It utilizes a secure service account or an OAuth/Token connection back to HPE OneView. 
- The engineer looking at the SCOM console can drill down into a ProLiant hardware alert 
- and click a contextual link that passes their SSO token straight into OneView or iLO to inspect the hardware health, 
- eliminating credential friction during high-severity banking outages.

------------------------------

<a id="6-ilo-trust-by-certificate-configuration-steps"></a>

## 6. iLO Trust-by-Certificate — Configuration Steps

To eliminate local iLO accounts and lockouts, each HPE ProLiant iLO chip is issued an enterprise CA-signed certificate and configured to trust AD groups via LDAPS. The procedure below implements *Trust by Certificate* mode so iLO authenticates the user's identity without prompting for iLO-local credentials.

<a id="61-prerequisites"></a>

### 6.1 Prerequisites

- **Enterprise CA** reachable over HTTP/HTTPS (AD CS, Microsoft NDES/PKI, or Venafi).
- **iLO firmware** ≥ iLO5 2.5x (Gen10+) for full Trust-by-Certificate + OneView integration.
- **DNS**: A-record for the iLO FQDN resolvable from the management VLAN.
- **AD groups** pre-created in a Security OU (Tier-0 for admins, Tier-1 for read-only operators).

<a id="62-step-1-generate-a-certificate-signing-request-csr-from-ilo"></a>

### 6.2 Step 1 — Generate a Certificate Signing Request (CSR) from iLO

1. In the iLO web UI, navigate to **Administration → Certificate Management → SSL Certificate**.
2. Click **Create CSR** (or via `ilorest` CLI: `ilorest createsr --output cert.csr`).
3. Specify:
   - **Common Name**: `<ilo-fqdn>` (must match an A-record).
   - **Subject Alternative Name (SAN)**: both the FQDN and the iLO IP address.
   - **Key Size**: 2048 or 4096-bit RSA (4096 recommended for PCI-DORA).
   - **Hash Algorithm**: SHA-256 (not SHA-1).
4. Copy the generated CSR text.

<a id="63-step-2-issue-the-certificate-from-the-enterprise-ca"></a>

### 6.3 Step 2 — Issue the Certificate from the Enterprise CA

- **Microsoft AD CS**:
  1. Open `certsrv` → **Request New Certificate** → **Advanced** policy.
  2. Template: select **Web Server** (or a custom iLO EKU template with `1.3.6.1.4.1.231.2.1.1.1` if present).
  3. Paste the CSR contents; ensure the **Subject** and **SAN** fields are preserved.
  4. Download the issued certificate **+** the CA's root + intermediate chain as a `.p7b` bundle.
- **Venafi/NDES**: submit the CSR to the NDES endpoint and retrieve the full chain.

<a id="64-step-3-install-the-certificate-on-ilo-trust-by-certificate"></a>

### 6.4 Step 3 — Install the Certificate on iLO (Trust by Certificate)

1. In iLO: **Administration → Certificate Management → SSL Certificate → Import Certificate**.
2. Upload the issued cert **+ the intermediate chain** (root is pre-trusted if enrolled via Enterprise CA; import intermediates explicitly).
3. **Reboot** iLO when prompted. After restart, the browser trust indicator (lock icon) must show the CA as a trusted issuer.
4. Verify via `ilorest`:
   ```
   ilorest login <ilo-fqdn> --user "" --password ""
   ilorest showcert
   ```

<a id="65-step-4-configure-the-ldapad-directory-integration"></a>

### 6.5 Step 4 — Configure the LDAP/AD Directory Integration

Ref [3](#ref-3), [6](#ref-6).

1. In iLO: **Administration → User Administration → Directory Settings**.
2. Set:
   - **Directory Server Type**: `Active Directory`.
   - **Directory Server (LDAPS)**: `ldaps://<dc-fqdn>:636` (use the AD Global Catalog for cross-domain groups, or a specific DC in the same site as the iLO VLAN).
   - **Directory Account Context (Base DN)**: `OU=Security,DC=bank,DC=domains` (root of the Tier-0/Tier-1 groups).
   - **Test** using a known AD bind account; confirm `LDAP bind successful`.
3. Save.

<a id="66-step-5-map-ad-groups-to-ilo-roles-trust-by-certificate-group-mapping"></a>

### 6.6 Step 5 — Map AD Groups to iLO Roles (Trust-by-Certificate Group Mapping)

Ref [7](#ref-7). This is the crux of SSO: iLO consumes the user's group membership from the LDAP bind and maps it to a local role instead of a per-server local account.

| AD Security Group (memberOf) | iLO Local Role | Scope |
| --- | --- | --- |
| `CN=iLO-Admins,OU=Security,...` | **Administrator** (all iLO privileges incl. remote console, firmware, virtual media) | Server-level |
| `CN=iLO-Console-Operators,OU=Security,...` | **Remote Console** | Server-level |
| `CN=iLO-Read-Only,OU=Security,...` | **Read Only** | Server-level |
| `CN=iLO-Auditors,OU=Security,...` | **Auditor** | Server-level |

CLI equivalent (via `ilorest`):
```
ilorest.exe config --update
  --mgr_user 0 --mgr_password 0 \
  --ad_server ldaps://dc.bank.domains:636 \
  --ad_cert "-----BEGIN CERTIFICATE----- ..." \
  --ad_group_cn "iLO-Admins"      --ad_role Administrator
  --ad_group_cn "iLO-Console-Operators" --ad_role "Remote Console"
  --ad_group_cn "iLO-Read-Only"   --ad_role "Read Only"
```

After mapping, **disable iLO-local user accounts** (set local accounts to `disabled` or delete) so authentication is enforced solely through the certificate-trusted AD path.

<a id="67-step-6-oneview-brokered-sso-optional-for-gen10synergy"></a>

### 6.7 Step 6 — OneView Brokered SSO (optional, for Gen10+/Synergy)

Because iLO is often managed through HPE OneView:
1. Import the iLO into OneView: **Server Hardware → Add** (OneView discovers the certificate via WS-Trust).
2. In OneView: **Settings → Platform Settings → iLO Settings → Enable "Use iLO for remote console with HPE SSO"**.
3. Map an AD group to the OneView *Server Administrator* role. A user in that group can then click *Remote Console* in OneView and get a seamless iLO session without a second login (token is brokered via the OneView-iLO trust relationship).

<a id="68-verification"></a>

### 6.8 Verification

- Engineer in `iLO-Admins` opens `https://<ilo-fqdn>` → browser SSO to AD → lands in the iLO UI as Administrator, no iLO password prompt.
- Engineer in `iLO-Read-Only` lands in **Read Only** mode; *Remote Console* button is greyed out.
- Local accounts confirmed `disabled` via **Administration → User Administration → Local Accounts**.

---

<a id="7-zpe-nodegrid-azure-ad-saml-claim-mapping-step-by-step"></a>

## 7. ZPE Nodegrid — Azure AD SAML Claim Mapping (Step-by-Step)

Nodegrid acts as the SAML 2.0 **Service Provider (SP)** at the physical/serial console boundary. Azure AD (Entra ID) is the **Identity Provider (IdP)**. The integration has two halves: claim rules defined in Azure AD, and the SP-side attribute mapping that grants console/SSH pass-through to iLO serial ports. Ref [2](#ref-2), [12](#ref-12), [13](#ref-13), [14](#ref-14), [16](#ref-16), [17](#ref-17).

<a id="71-part-a-define-azure-ad-side-enterprise-application-claims"></a>

### 7.1 Part A — Define Azure AD Side (Enterprise Application + Claims)

Create a non-gallery Enterprise Application for the Nodegrid SP.

1. **Azure Portal → Entra ID → Enterprise Applications → New application → Create your own application**.
   - **Name**: `ZPE Nodegrid - Bankname`
   - **Type**: `Integrate any other application you don't find in the gallery (Non-gallery)`.
   - **Assignment type**: `Assigned users and groups` (select the Tier-0/Tier-1 AD groups that map to Nodegrid roles).

2. **Set up single sign-on → SAML → Edit** (Basic SAML Configuration):
   - **Name ID**: `user.userprincipalname`
   - **Identifier (Entity ID)**: `nodegrid` (must match Nodegrid **Entity ID** field exactly, case-sensitive).
   - **Reply URL / ACS URL**: `https://<nodegrid-fqdn>/saml/acs`
   - **Relay State**: `https://<nodegrid-fqdn>/direct/<device>/console` (enables deep-link passthrough to a specific iLO console from the Nodegrid UI).

3. **Attributes & Claims → Add new claim(s)**:

   | Claim name (case-sensitive) | Namespace | Source attribute | Notes |
   | --- | --- | --- | --- |
   | `firstName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` | `user.givenName` | Required by Nodegrid attribute |
   | `lastName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` | `user.surname` | Required by Nodegrid |
   | `emailaddress` | (default) | `user.mail` | Used for Nodegrid user record |
   | `memberOf` | `http://schemas.microsoft.com/claims/group` | **Custom value**: `Administrator` or `User` | Maps the engineer's Azure-side group label into Nodegrid's local group. Default Nodegrid org groups are `Administrator` and `User`. |
   | `timeout` | (default) | `600` | Idle session timeout (seconds) before SAML re-auth. |

   Notes:
   - The `memberOf` claim **must correspond to an existing Nodegrid local group name**; users not assigned a valid group fall back to `User`.
   - For finer console access control, use **group-based claims**: set Source Group → select the AD group → transform → `member`. Then emit a custom claim like `nodegridConsoleGroup` mapped to specific Nodegrid access groups.
   - Ensure **Signature algorithm**: `SHA-256` (the default in Azure AD and what Nodegrid expects).

4. **Download** the **Federated Metadata XML** from the SAML settings page (contains the IdP cert + SSO URL + Entity ID).

<a id="72-part-b-define-nodegrid-side-service-provider"></a>

### 7.2 Part B — Define Nodegrid Side (Service Provider)

Ref [2](#ref-2), [13](#ref-13). This is configured per-Nodegrid device under **Security :: Authentication :: SSO**.

1. In the Nodegrid UI: **Security → Authentication → SSO → Import Metadata**.
2. **Add / Import Metadata** dialog:
   - **Name**: `azure` (must match Azure-side reply-context name).
   - **Status**: `Enabled`.
   - **Entity ID**: `nodegrid` (same value as the Azure Identifier).
   - **Metadata source**: upload the XML downloaded from Azure (or reference it via a Remote Server URL protected by mutual TLS — do **not** leave it world-readable).
3. **Required fields** (filled from Azure):
   - **X.509 Certificate**: IdP signing cert (auto-extracted from the metadata).
   - **Identity Provider (Issuer)**: `https://sts.windows.net/<tenant-id>/`
   - **Single Sign-On URL**: `https://login.microsoftonline.com/<tenant-id>/saml2`
4. **Enable Single Logout (SLO)**: enter `https://login.microsoftonline.com/<tenant-id>/saml2` (Azure supports SLO at the same endpoint). This prevents stale console sessions after Azure-side sign-out / MFA timeout.
5. **Force Re-authentication**: tick this so the browser always re-prompts Azure AD — critical for DORA auditability (each console launch is attributable).
6. **Map the SAML group → Nodegrid local group** (this is the claim mapping that actually grants pass-through):
   - Go to **Security → Groups → Local Groups**.
   - **Group name**: `Administrator` (exact case match to the Azure `memberOf` claim value above).
   - **Source**: `SAML` (or `Remote group`) — set the *remote group* field to `memberOf` **OR** the *Group name* to match the claim.
   - Assign **member roles**: `CLI access`, `Serial/SSH console access`, `Remote Console (iLO)`, `Local admin override` as required by policy.

   Repeat for `User` (read-only console) and any additional role-based groups (e.g., `Network-Admins`, `Hardware-Engineers`) — each AD group emitted by Azure AD as a claim gets its own Nodegrid local group with scoped console access.

7. **Optional — per-device SSO (proxy access)**:
   - Copy the **ACS URL** of the specific Nodegrid device
   - Return to Azure → add the **ACS URL** as a **Reply URL** (SP) and a **secondary Reply URL** `https://proxy-access.zpecloud.com` if remote device access is needed.
   - Save.

<a id="73-verification"></a>

### 7.3 Verification

- Engineer browses to `https://<nodegrid-fqdn>` → redirected to `login.microsoftonline.com` → MFA at ADFS/Conditional Access → lands **back in Nodegrid as `Administrator`** (no Nodegrid-local password).
- Engineer's `memberOf=Administrator` claim is reflected in **Security → Users → <username>** showing the Nodegrid group `Administrator`.
- `memberOf=User`-mapped account sees the same device list but **Serial Console / SSH** buttons are restricted per that group's ACL (no full config write).
- After Azure sign-out, Nodegrid session terminates (SLO confirmed).

---

<a id="8-windows-interactive-rdp-sso-preventing-account-lockouts"></a>

## 8. Windows Interactive & RDP SSO — Preventing Account Lockouts

The document's Sections 1 and 4 mention Kerberos/SAML/MECM but do **not** address the boss's actual pain: engineers logging into 50+ servers/day and triggering AD account lockouts via per-server interactive (password) prompts. The fix is to make AD sign-on **the single credential** that is reused across all RDP hops without re-prompting, using Kerberos SSO with Restricted Admin Mode to satisfy DORA/PSD2 SCA. Ref [1](#ref-1), [18](#ref-18), [19](#ref-19), [20](#ref-20).

<a id="81-core-principle-one-credential-no-per-server-prompts"></a>

### 8.1 Core principle: one credential, no per-server prompts

Engineers sign on **once** (AD or Azure AD + MFA at the jump box / device), obtaining a **Kerberos TGT**. Every subsequent RDP session to the 50+ servers reuses that TGT via **Credential Security Support Provider (CredSSP)** in **Restricted Admin Mode**. Because no password is ever typed at the remote server, lockout-prone interactive binds do not recur.

<a id="82-domain-controller-ad-side-controls-prevent-lockout-at-source"></a>

### 8.2 Domain Controller / AD-side controls (prevent lockout at source)

Apply via Group Policy to the **Domain Controllers OU** and the workstation/server OUs:

| GPO path | Setting | Recommended value | Rationale |
| --- | --- | --- | --- |
| `Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Account Lockout Policy` | `Account lockout threshold` | `5 invalid logons` | Allows a small MFA retry window; resets after `Lockout duration` |
| | `Account lockout duration` | `30 minutes` | Short enough to recover without a ticket; long enough to deter brute force (DORA) |
| | `Reset account lockout counter after` | `30 minutes` | |
| `Computer Configuration → Windows Settings → Security Settings → Account Policies → Kerberos Policy` | `Maximum lifetime for user ticket` | `600 minutes (10h)` | Long enough for a shift; shorter than default to limit replay |
| | `Maximum lifetime for user ticket (renewal)` | `7 days` | |
| | `Enforce user logon restrictions` | `Enabled` | Stops logons to disabled accounts immediately |

<a id="83-step-by-step-configure-windows-workstation-and-servers"></a>

### 8.3 Step-by-step: Configure Windows workstation and servers

Ref [19](#ref-19), [20](#ref-20). The critical GPO paths are under both `Computer Configuration` and `Administrative Templates`.

#### 8.3.1 Jump-box / engineer workstation (Tier-1)

1. Join workstation to AD and **enable Azure AD Hybrid** so MFA at sign-in (Conditional Access) issues a primary refresh token.
2. Apply a **device-level GPO** to the workstation OU:
   - **Computer Configuration → Administrative Templates → System → Logon →** enable:
     - `Always wait for the network at computer startup and logon` — prevents cached-credential auth on slow links (which can bypass MFA).
   - **Computer Configuration → Administrative Templates → Windows Components → Windows Logon Options →**
     - `Configure Logging on / Off over a secure channel: Enabled`
     - `Network security: Configure encryption types allowed for Kerberos` → AES256-CTS-HMAC-SHA1-916 + Future-Orders.
3. **Disable NTLM fallback** on the workstation:
   - `Network security: Network authentication: LAN Manager authentication level` → `Send NTLMv2 response only. Refuse LM & NTLM`.

#### 8.3.2 RDP target servers (the 50+ ProLiant boxes)

Ref [18](#ref-18). The lockout prevention happens by enforcing Restricted Admin Mode + Kerberos delegation so credentials are forwarded silently.

1. **Restricted Admin Mode is mandatory** — this is what stops the 50+ password prompts and stops credential theft:
   - `Computer Configuration → Administrative Templates → Windows Components → Remote Desktop Services → Remote Desktop Session Host → Security`:
     - `Require use of specific security layer for Remote Desktop` → `Enabled`, set to **SSL (TLS 1.2)** (NOT RDP Security Layer).
     - `Require Secure RPC communication` → `Enabled`.
     - `Set client connection encryption level` → `Enabled`, **High Level (TLS 1.2)**.
     - `Do not allow drive redirection` / clipboard redirection per policy.
   - **User Configuration → Administrative Templates → Windows Components → Remote Desktop Services → Remote Desktop Session Host → Connection**:
     - `Allow users to connect remotely` — leave enabled, but enforce NLA (`User Authentication for Remote Desktop by requiring user authentication at the RD client`) → **Enabled**.

2. **Kerberos delegation / CredSSP configuration** (so the jump box SSO ticket is reused):
   - `Computer Configuration → Administrative Templates → System → Credentials Delegation`:
     - `Allow delegating fresh credentials` → `Enabled` → add `TERMSRV/<server-fqdn>` for each server OU (or use a wildcard GPO: `TERMSRV/*.<domain>`).
     - `Allow delegating fresh credentials with NTLM-only server authentication` → `Disabled` (explicitly reject NTLM pass-through).
     - `Require Restricted Admin elevation for delegation` → `Enabled`.

3. **Map the Tier-0/Tier-1 AD groups to the local "Remote Desktop Users" group** (so *no* per-server local account is needed — membership + Kerberos does the auth):
   - GPO: `Computer Configuration → Preferences → Control Panel Settings → Local Users and Groups`:
     - Action: **Update** → Local group **Remote Desktop Users** → `Add: AD group <Domain>\Tier-1-Servers-Admins` (remove default `Administrators` to enforce least privilege).

4. **Force SMB/RPC signing & LDAPS** on all 50+ servers (audit boundary):
   - `Network security: Microsoft network client: Digitally sign communications (always)` → `Enabled`.
   - `Domain controller: LDAP server signing requirements` → `Negotiate`.
   - `Network security: LDAP client signing requirements` → `Negotiate`.

<a id="84-rdp-launch-pattern-the-engineers-should-use"></a>

### 8.4 RDP launch pattern the engineers should use

Rather than typing credentials at the remote desktop prompt, engineers launch RDP from the **Azure AD / Entra-joined jump box** using one of:
- `mstsc.exe /v:<server-fqdn>` — and **at the login prompt**, select *"Use my RD Gateway credentials for the remote computer"* / *"Attempt SSO"*; Windows presents the TGT to the remote server.
- `Enter-PSSession -ComputerName <server>` (WinRM over Kerberos) — no second credential.
- `ssh.exe <user>@<server>` (if WinOpenSSH + AD integration is enabled) — the local OpenSSH client can forward the GSSAPI/Kerberos ticket.
- **HPE iLO Remote Console** launched *through* OneView or Nodegrid (Section 6.7) — the console token is brokered from the engineer's SSO session.

Because NLA + Restricted Admin + Kerberos SSO are enforced, the engineer authenticates **only once per session** (at the jump box), and the TGT is silently forwarded to all 50+ servers — eliminating the interactive-password-at-every-server behavior that causes lockout spikes.

<a id="85-mfa-scoping-prevent-mfa-loops-re-authentication-storms"></a>

### 8.5 MFA scoping (prevent MFA loops / re-authentication storms)

Ref [1](#ref-1), [21](#ref-21), [22](#ref-22). Place MFA at **exactly one** control point:

| Resource | MFA required? | Mechanism | Reason |
| --- | --- | --- | --- |
| Jump box / Entra-joined workstation (interactive logon) | **Yes** (Conditional Access) | Azure MFA / FIDO2 security key | First factor — satisfies PSD2 SCA; ticket is issued once |
| RDP targets (the 50+ servers) | **No** | Kerberos TGT reuse | Re-prompting would re-trigger 50 MFA prompts / lockout risk |
| Nodegrid SAML login | **Yes** | Azure AD SAML + Conditional Access | Physical/serial boundary — needs SCA per DORA |
| iLO Remote Console (via OneView) | **No** (inherits OneView TGT) | OneView brokered token | OneView already proved identity |

This single-MFA-entry model is what collapses the 50+ daily logins into one, removing the lockout trigger.

---

<a id="core-security-architecture-matrix"></a>

## Core Security Architecture Matrix

| Component | Auth Protocol | Target Mapping Entity | Banking Regulation / Compliance Context |
| --- | --- | --- | --- |
| Windows Net / AD | Kerberos / SAML 2.0 | Central Identity Store | Centralized Audit Logging (GDPR / DORA) |
| HPE iLO | LDAPS / Trust-by-Cert | AD Tier-0 Groups | Silicon Root of Trust & Tamper-proof logging |
| Redfish API | HTTPS Session Tokens | Active Directory User | Micro-segmentation & Secure Automated Scripting |
| ZPE Nodegrid | SAML 2.0 / IdP Integration | Azure AD Claims / Groups | Strict MFA at the physical/serial boundary |
| HPE OneView | Directory Login Domain | Enterprise AD Groups | Single Point of Control for Compute Provisioning |
| SCOM & MCM | Native Kerberos | Windows Security Groups | Least-Privilege operational monitoring & patching |

<a id="references"></a>

## References

<a id="ref-1"></a>[1] [https://www.pingidentity.com](https://www.pingidentity.com/en/resources/blog/post/the-scoop-on-strong-customer-authentication-sca.html)  
<a id="ref-2"></a>[2] [https://docs.zpesystems.com](https://docs.zpesystems.com/docs/method-ldap-or-ad)  
<a id="ref-3"></a>[3] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=a00018320en_us&page=GUID-966B4429-96E8-47A3-87AD-1DBCD0516E84.html&docLocale=en_US)  
<a id="ref-4"></a>[4] [https://www.tenable.com](https://www.tenable.com/plugins/nessus/72877)  
<a id="ref-5"></a>[5] [https://redfish.redoc.ly](https://redfish.redoc.ly/docs/redfishservices/ilos/ilo5/ilo5_278/ilo5_hpe_resourcedefns278/)  
<a id="ref-6"></a>[6] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00002198en_us&page=GUID-E719CD70-69E4-4E2A-B8E1-EA6A80D55E0D.html&docLocale=en_US)  
<a id="ref-7"></a>[7] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00005250en_us&page=s_security-mapping-roles.html&docLocale=en_US)  
<a id="ref-8"></a>[8] [https://developer.hpe.com](https://developer.hpe.com/blog/getting-started-with-ilo-restful-api-redfish-api-conformance/)  
<a id="ref-9"></a>[9] [https://servermanagementportal.ext.hpe.com](https://servermanagementportal.ext.hpe.com/docs/concepts)  
<a id="ref-10"></a>[10] [https://servermanagementportal.ext.hpe.com](https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/supplementdocuments/managingusers)  
<a id="ref-11"></a>[11] [https://servermanagementportal.ext.hpe.com](https://servermanagementportal.ext.hpe.com/docs)  
<a id="ref-12"></a>[12] [https://support.zpesystems.com](https://support.zpesystems.com/portal/en/kb/articles/how-to-configure-single-sign-on-authentication-in-nodegrid-using-duo)  
<a id="ref-13"></a>[13] [https://docs.zpesystems.com](https://docs.zpesystems.com/zpe-cloud/docs/configure-sso-with-azure-ad)  
<a id="ref-14"></a>[14] [https://docs.zpesystems.com](https://docs.zpesystems.com/docs/sso-sub-tab)  
<a id="ref-15"></a>[15] [https://zpesystems.com](https://zpesystems.com/company/single-sign-on-with-nodegrid/)  
<a id="ref-16"></a>[16] [https://www.youtube.com](https://www.youtube.com/watch?v=naMajDEJmLU)  
<a id="ref-17"></a>[17] [https://docs.zpesystems.com](https://docs.zpesystems.com/zpe-cloud/docs/sso-tab)  
<a id="ref-18"></a>[18] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00006049en_us&page=s_server-hardware-mgmt-effects.html&docLocale=en_US)  
<a id="ref-19"></a>[19] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00003499en_us&page=GUID-D7147C7F-2016-0901-066E-0000000032EE.html&docLocale=en_US)  
<a id="ref-20"></a>[20] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00003904en_us&page=GUID-D7147C7F-2016-0901-066E-0000000047C0.html&docLocale=en_US)  
<a id="ref-21"></a>[21] [https://community.hpe.com](https://community.hpe.com/t5/hpe-oneview/mapping-ad-group-to-role-mapping-with-rest-api/td-p/7033253)  
<a id="ref-22"></a>[22] [https://community.hpe.com](https://community.hpe.com/t5/hpe-synergy/oneview-sso-to-ilo-scripting-with-python/td-p/7068401)
