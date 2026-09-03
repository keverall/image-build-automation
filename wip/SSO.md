# Single Sign-On (SSO) Architecture

## Overview  

- Implementing Single Sign-On (SSO) in a highly regulated EU banking environment
- subject to strict compliance frameworks - DORA, GDPR, and PSD2/3 Strong Customer Authentication
- involves unifying modern web-based identity management with legacy datacentre infrastructure.
- In a Windows network hosting HPE ProLiant infrastructure, 
- this is achieved by mapping Active Directory (AD) / Azure AD (Entra ID) identities to different
  - hardware, management, and monitoring tiers
  - using explicit trust boundaries. [1]
  - A complete architecture overview of how these distinct elements are bridged into a single identity control plane follows below.

------------------------------

## 1. Identity Infrastructure Layer (Windows Networks & Active Directory)

Central source of truth is Active Directory Domain Services (AD DS) combined with an identity provider (IdP) like Microsoft Entra ID / ADFS to enforce multi-factor authentication (MFA) and conditional access policies before granting an SSO token.

- All administrative identities belong to tiered AD security groups (e.g., Tier-0 for Domain Admins/Hardware controllers).
- Open standards are heavily enforced: SAML 2.0 / OIDC are used for web portals, while secure Kerberos or LDAP over TLS (LDAPS, Port 636) handles legacy backend authentications. [2, 3]

## 2. Bare-Metal Management Layer (iLO & Redfish)

To prevent engineers from using shared local administrator accounts on HPE ProLiant servers, individual bare-metal access is tied back to AD. [4] 

- HPE iLO (Integrated Lights-Out): iLO is configured using Trust by Certificate mode. The bank installs enterprise CA-signed certificates onto the iLO chips. In the HPE SSO settings, iLO is configured to trust assertions from the parent manager software (HPE OneView). Additionally, iLO directories map AD Security Groups natively to specific iLO roles (e.g., Admin, Remote Console, Read-Only) using LDAPS. [3, 5, 6, 7]

- Redfish API: Redfish is the modern RESTful replacement for IPMI/SNMP. For automated scripts or infrastructure-as-code, SSO is achieved via Session Tokens. A user authenticates securely via the /redfish/v1/SessionService/Sessions endpoint using their AD credentials, receives a temporary X-Auth-Token, and passes it in subsequent REST API headers. For server-to-server operations (like automated agents), HPE ProLiant Gen12+ utilizes Application Accounts / Tokens, minimizing human credential leakage. [8, 9, 10, 11]
  
## 3. Out-of-Band Network Access (ZPE Nodegrid)

Nodegrid serves as the critical console server infrastructure, providing access to hardware when the production network is down.

- SAML 2.0 Web SSO: Nodegrid devices are configured as Service Providers (SP) 
- linked to the bank's central identity provider (e.g., Azure AD/Entra ID) using XML Metadata exchange. 
- An engineer logging into the Nodegrid UI is redirected to the bank's portal to fulfill MFA requirements. [12, 13, 14, 15]
- Console/CLI SSO & Authorization: Once authenticated via SAML, the user's group claims (e.g., memberOf) are evaluated. 
- Nodegrid maps these claims to internal device access groups, 
- giving the user instant pass-through access (via serial/SSH) to specific ProLiant iLO ports without needing to log into the target servers a second time. [2, 13, 16, 17]

## 4. Management & Orchestration Layer (HPE OneView & MCM)

- **HPE OneView** (formerly HPE OpenView): OneView acts as the core controller for the entire ProLiant server pool.
- It integrates natively with Active Directory login domains. Role-Based Access Control (RBAC)
- maps AD groups directly to OneView roles (e.g., Infrastructure Administrator).
- Because OneView acts as a certificate authority/broker for the underlying hardware,
- logging into OneView via AD automatically generates an implicit SSO token to launch the iLO Remote Console for any managed server seamlessly.
- **MCM**(Microsoft Endpoint Configuration Manager / MECM): Formerly SCCM, MCM natively integrates into the Windows Domain infrastructure. 
- SSO is handled implicitly through Windows Kerberos Authentication. 
- Because the engineer logs into their Windows jump box with AD credentials, 
- MCM honours their token, granting them RBAC rights to manage ProLiant OS deployment and configuration tasks without prompting for a login. [18, 19, 20, 21, 22]

## 5. Monitoring & Alerting Layer (Microsoft SCOM)

- SCOM (System Center Operations Manager): Much like MCM, SCOM relies fully on Windows Kerberos authentication and Active Directory architecture. 
- SCOM management groups are secured via AD global security groups.
- HPE OneView Management Pack for SCOM: To achieve seamless visibility, 
- the HPE SCOM Management Pack is deployed. It utilizes a secure service account or an OAuth/Token connection back to HPE OneView. 
- The engineer looking at the SCOM console can drill down into a ProLiant hardware alert 
- and click a contextual link that passes their SSO token straight into OneView or iLO to inspect the hardware health, 
- eliminating credential friction during high-severity banking outages.

------------------------------

## Core Security Architecture Matrix

| Component | Auth Protocol | Target Mapping Entity | Banking Regulation / Compliance Context |
| --- | --- | --- | --- |
| Windows Net / AD | Kerberos / SAML 2.0 | Central Identity Store | Centralized Audit Logging (GDPR / DORA) |
| HPE iLO | LDAPS / Trust-by-Cert | AD Tier-0 Groups | Silicon Root of Trust & Tamper-proof logging |
| Redfish API | HTTPS Session Tokens | Active Directory User | Micro-segmentation & Secure Automated Scripting |
| ZPE Nodegrid | SAML 2.0 / IdP Integration | Azure AD Claims / Groups | Strict MFA at the physical/serial boundary |
| HPE OneView | Directory Login Domain | Enterprise AD Groups | Single Point of Control for Compute Provisioning |
| SCOM & MCM | Native Kerberos | Windows Security Groups | Least-Privilege operational monitoring & patching |

## References

[1] [https://www.pingidentity.com](https://www.pingidentity.com/en/resources/blog/post/the-scoop-on-strong-customer-authentication-sca.html)  
[2] [https://docs.zpesystems.com](https://docs.zpesystems.com/docs/method-ldap-or-ad)  
[3] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=a00018320en_us&page=GUID-966B4429-96E8-47A3-87AD-1DBCD0516E84.html&docLocale=en_US)  
[4] [https://www.tenable.com](https://www.tenable.com/plugins/nessus/72877)  
[5] [https://redfish.redoc.ly](https://redfish.redoc.ly/docs/redfishservices/ilos/ilo5/ilo5_278/ilo5_hpe_resourcedefns278/)  
[6] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00002198en_us&page=GUID-E719CD70-69E4-4E2A-B8E1-EA6A80D55E0D.html&docLocale=en_US)  
[7] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00005250en_us&page=s_security-mapping-roles.html&docLocale=en_US)  
[8] [https://developer.hpe.com](https://developer.hpe.com/blog/getting-started-with-ilo-restful-api-redfish-api-conformance/)  
[9] [https://servermanagementportal.ext.hpe.com](https://servermanagementportal.ext.hpe.com/docs/concepts)  
[10] [https://servermanagementportal.ext.hpe.com](https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/supplementdocuments/managingusers)  
[11] [https://servermanagementportal.ext.hpe.com](https://servermanagementportal.ext.hpe.com/docs)  
[12] [https://support.zpesystems.com](https://support.zpesystems.com/portal/en/kb/articles/how-to-configure-single-sign-on-authentication-in-nodegrid-using-duo)  
[13] [https://docs.zpesystems.com](https://docs.zpesystems.com/zpe-cloud/docs/configure-sso-with-azure-ad)  
[14] [https://docs.zpesystems.com](https://docs.zpesystems.com/docs/sso-sub-tab)  
[15] [https://zpesystems.com](https://zpesystems.com/company/single-sign-on-with-nodegrid/)  
[16] [https://www.youtube.com](https://www.youtube.com/watch?v=naMajDEJmLU)  
[17] [https://docs.zpesystems.com](https://docs.zpesystems.com/zpe-cloud/docs/sso-tab)  
[18] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00006049en_us&page=s_server-hardware-mgmt-effects.html&docLocale=en_US)  
[19] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00003499en_us&page=GUID-D7147C7F-2016-0901-066E-0000000032EE.html&docLocale=en_US)  
[20] [https://support.hpe.com](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00003904en_us&page=GUID-D7147C7F-2016-0901-066E-0000000047C0.html&docLocale=en_US)  
[21] [https://community.hpe.com](https://community.hpe.com/t5/hpe-oneview/mapping-ad-group-to-role-mapping-with-rest-api/td-p/7033253)  
[22] [https://community.hpe.com](https://community.hpe.com/t5/hpe-synergy/oneview-sso-to-ilo-scripting-with-python/td-p/7068401)  
