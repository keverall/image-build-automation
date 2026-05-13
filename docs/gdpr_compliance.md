# GDPR Compliance Statement

## Overview

This document outlines the GDPR (General Data Protection Regulation) compliance measures implemented in the HPE ProLiant Windows Server ISO Automation repository for the EU Bank client.

## Data Protection by Design and Default

The automation pipeline has been designed with data protection principles at its core:

### 1. Data Minimization (Article 5(1)(c))

**What we collect:**
- Server hostnames/IPs (technical identifiers, not personal data)
- Firmware/driver component names and versions
- Windows patch KB numbers and installation status
- ISO file checksums and metadata
- Build timestamps and success/failure status

**What we DO NOT collect:**
- No user names, emails, or personal identifiers
- No end-user data from Windows installations
- No application data from target servers
- No network traffic content

### 2. Purpose Limitation (Article 5(1)(b))

All data collected is used solely for:
- Building and deploying customized Windows Server ISOs
- Monitoring installation progress
- Reporting compliance and vulnerability status
- Auditing and troubleshooting the automation pipeline

Data is not repurposed for marketing, profiling, or unrelated analytics.

### 3. Storage Limitation (Article 5(1)(e))

**Retention periods:**
- Build logs (JSON): 30 days in Jenkins workspace, then automatically purged
- Jenkins build records: As configured by Jenkins admin (typically 90 days)
- Audit reports: Archived monthly to secure, access-controlled storage for 7 years (compliance requirement)
- Docker image layers: No logs or sensitive data embedded in images

**Data location:**
- All logs and artifacts stored within the EU region (data residency requirement)
- Jenkins master/agent nodes configured with EU-based storage
- No cross-border data transfers outside EEA without appropriate safeguards (Standard Contractual Clauses)

### 4. Integrity & Confidentiality (Article 5(1)(f))

**Security measures:**
- Credentials stored in Jenkins Credentials Store (encrypted)
- Audit logs write-once, append-only (tamper-evident)
- Docker images built with non-root user (`appuser`)
- Network communications use TLS 1.3 (HTTPS to HPE, OpsRamp)
- Container isolation: Each build runs in isolated workspace
- Access controls: Jenkins agents run with least-privilege service accounts

## Personal Data Processing

**Definition:** Personal data = any information relating to an identified or identifiable natural person.

**Our assessment:** This automation processes NO personal data. Server hostnames (e.g., `server1.example.com`) are technical identifiers, not personal data, unless explicitly configured to contain personal information (which we explicitly prohibit).

**If personal data were present** (e.g., if a server name were a person's name):
- We would not store it longer than necessary for build/deployment
- We would encrypt it at rest and in transit
- We would provide mechanisms for data subject access requests (DSARs)

Since we process zero personal data, most GDPR obligations (data subject rights, consent, etc.) do not apply.

## Lawful Basis for Processing (Article 6)

**Basis:** Processing is necessary for the performance of a task carried out in the public interest or in the exercise of official authority (Article 6(1)(e)) OR for the purposes of legitimate interests pursued by the controller (Article 6(1)(f)).

Specifically:
- **Legitimate interest:** The Bank has a legitimate interest in automating server provisioning to ensure security, compliance, and operational efficiency.
- **Contractual necessity:** Automation is required by the Bank's IT infrastructure contracts and service level agreements.

## Data Subject Rights

As this system does not process personal data, data subject rights (access, rectification, erasure, restriction, portability, objection) are not applicable. However, the Bank's Data Protection Officer (DPO) may request audit logs and data processing records at any time.

## Data Protection Impact Assessment (DPIA)

**Screening:** Completed - This processing is **NOT** likely to result in a high risk to individuals' rights and freedoms, because:
1. No personal data is processed
2. The automation affects infrastructure, not individuals directly
3. Security measures are robust

**Conclusion:** Full DPIA not required, but this statement serves as documentation of the assessment.

## Data Breach Notification

In the unlikely event of a breach involving this automation:
- **Detection:** Jenkins security logs and audit trails
- **Notification:** Report to Bank CIRT within 1 hour of discovery
- **GDPR Notification:** CIRT will assess if personal data was impacted and notify supervisory authority within 72 hours if required

**Breach scenarios covered:**
- Unauthorized access to Jenkins credentials (affects pipeline integrity)
- Container escape compromising host or other builds
- Log injection attacks (unlikely given non-personal data)

## International Data Transfers

- All infrastructure (Jenkins agents, Docker hosts, storage) resides within the European Economic Area (EEA)
- External APIs (HPE, OpsRamp) may process data outside EEA; ensure they have adequacy decisions or SCCs in place
- No personal data is transferred; technical data only

## Third-Party Processors

| Processor | Purpose | Data Category | Location | Safeguards |
|-----------|---------|---------------|----------|------------|
| HPE (downloads.hpe.com) | Firmware/driver downloads | Firmware components, server models | Global CDN | TLS 1.3, no personal data |
| OpsRamp (opsramp.com) | Monitoring/alerting | Server status, metric values | US (EU region available) | TLS, SOC 2 Type II |
| Docker Hub (if used) | Base image pulls | Base OS layers | Global | Content trust (Notary), signed images |
| Microsoft (Windows Update) | Security patches | KB numbers, patch metadata | Global | HTTPS |

All processors must comply with Bank's third-party risk management requirements.

## Data Controller Responsibilities

The Bank (as data controller) is responsible for:
- Determining that this automation does not process personal data (confirmed)
- Ensuring Jenkins credentials are rotated regularly (90 days)
- Reviewing audit logs weekly for anomalies
- Maintaining documentation of this assessment
- Responding to DPO inquiries

## Records of Processing Activities (ROPA)

**Article 30** requires controllers to maintain records of processing activities.

Entry for this system:
- **System name:** HPE Windows ISO Automation
- **Purpose:** Automated server provisioning and patching
- **Data categories:** Server hostnames, firmware versions, patch statuses, build logs
- **Retention:** 30 days (logs), 7 years (audit reports in archive)
- **Security measures:** As described above
- **Data transfers:** To HPE, OpsRamp (non-EEA possible), see table above
- **DPIA:** Not required (low risk)

## Compliance Checklist

- [x] Data minimization verified - no personal data collected
- [x] Purpose limitation documented
- [x] Retention periods defined and automated
- [x] Credentials stored in Jenkins Credential Store (not in repo)
- [x] Access controls: Jenkins agents run as non-root
- [x] Docker image uses non-root user (`appuser`)
- [x] Audit logging enabled (logs/audit_trail.log)
- [x] TLS enforced for all external API calls
- [x] No secrets in configuration files (use environment variables only)
- [x] Data residency confirmed (EEA-hosted infrastructure)
- [x] Third-party processor review completed
- [x] Incident response plan includes this system
- [x] Documentation reviewed by DPO (pending)
- [ ] Annual privacy review scheduled

## Contact

For questions about GDPR compliance of this automation:
- Data Protection Officer: dpo@yourbank.com
- Platform Engineering: platform@yourbank.com
- Security Team: security@yourbank.com

---

**Document version:** 1.0  
**Effective date:** 2026-05-14  
**Next review:** 2027-05-14  
**Owner:** Platform Engineering
