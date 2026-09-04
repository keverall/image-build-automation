# GDPR Compliance Statement

<a id="top"></a>

## Table of Contents

- [Overview](#overview)
- [Data Protection by Design and Default](#data-protection-by-design-and-default)
  - [1. Data Minimization (Article 5(1)(c))](#1-data-minimization-article-51c)
  - [2. Purpose Limitation (Article 5(1)(b))](#2-purpose-limitation-article-51b)
  - [3. Storage Limitation (Article 5(1)(e))](#3-storage-limitation-article-51e)
  - [4. Integrity & Confidentiality (Article 5(1)(f))](#4-integrity-confidentiality-article-51f)
- [Personal Data Processing](#personal-data-processing)
- [Lawful Basis for Processing (Article 6)](#lawful-basis-for-processing-article-6)
- [Data Subject Rights](#data-subject-rights)
- [Data Protection Impact Assessment (DPIA)](#data-protection-impact-assessment-dpia)
- [Data Breach Notification](#data-breach-notification)
- [International Data Transfers](#international-data-transfers)
- [Third-Party Processors](#third-party-processors)
- [Data Controller Responsibilities](#data-controller-responsibilities)
- [Records of Processing Activities (ROPA)](#records-of-processing-activities-ropa)
- [Compliance Checklist](#compliance-checklist)
- [Contact](#contact)

<a id="overview"></a>

## Overview

GDPR compliance measures implemented in the HPE ProLiant Windows Server ISO Automation repository for the EU Bank client.

<a id="data-protection-by-design-and-default"></a>

## Data Protection by Design and Default

<a id="1-data-minimization-article-51c"></a>

### 1. Data Minimization (Article 5(1)(c))

**Collected:** Server hostnames/IPs (technical identifiers, not personal data), firmware/driver component names and versions, Windows patch KB numbers and status, ISO checksums and metadata, build timestamps and success/failure status.

**Not collected:** User names, emails, or personal identifiers; end-user data from Windows installations; application data from target servers; network traffic content.

<a id="2-purpose-limitation-article-51b"></a>

### 2. Purpose Limitation (Article 5(1)(b))

Data is used solely for: building and deploying customized Windows Server ISOs; monitoring installation progress; reporting compliance and vulnerability status; auditing and troubleshooting the automation pipeline. Not repurposed for marketing, profiling, or unrelated analytics.

<a id="3-storage-limitation-article-51e"></a>

### 3. Storage Limitation (Article 5(1)(e))

- Build logs (JSON): 30 days in CI workspace, then purged
- Build records: as configured by CI admin (typically 90 days)
- Audit reports: archived monthly to secure, access-controlled storage for 7 years
- Docker image layers: no logs or sensitive data embedded

All logs and artifacts stored within the EU region. No cross-border transfers outside the EEA without Standard Contractual Clauses.

<a id="4-integrity-confidentiality-article-51f"></a>

### 4. Integrity & Confidentiality (Article 5(1)(f))

- Credentials stored in CI Credentials Store (encrypted)
- Audit logs write-once, append-only (tamper-evident)
- Docker images built with non-root user (`appuser`)
- Network communications use TLS 1.3 (HTTPS to HPE, OpsRamp)
- Each build runs in an isolated workspace
- CI agents run with least-privilege service accounts

<a id="personal-data-processing"></a>

## Personal Data Processing

Personal data = any information relating to an identified or identifiable natural person. This automation processes **NO** personal data; server hostnames are technical identifiers unless explicitly configured otherwise (which is prohibited). Since zero personal data is processed, most GDPR obligations (data subject rights, consent) do not apply.

<a id="lawful-basis-for-processing-article-6"></a>

## Lawful Basis for Processing (Article 6)

Processing is necessary for a task in the public interest / exercise of official authority (Article 6(1)(e)) or for the controller's legitimate interests (Article 6(1)(f)): the Bank has a legitimate interest in automating server provisioning for security, compliance, and operational efficiency, and it is required by IT infrastructure contracts and SLAs.

<a id="data-subject-rights"></a>

## Data Subject Rights

Not applicable, as no personal data is processed. The Bank's DPO may request audit logs and processing records at any time.

<a id="data-protection-impact-assessment-dpia"></a>

## Data Protection Impact Assessment (DPIA)

Screening completed — processing is **NOT** likely to result in high risk: no personal data is processed, the automation affects infrastructure not individuals, and security measures are robust. Full DPIA not required; this statement serves as the assessment record.

<a id="data-breach-notification"></a>

## Data Breach Notification

- **Detection:** CI security logs and audit trails
- **Notification:** report to Bank CIRT within 1 hour of discovery
- **GDPR Notification:** CIRT assesses personal-data impact and notifies the supervisory authority within 72 hours if required

Scenarios covered: unauthorized access to CI credentials; container escape compromising host or other builds; log injection (unlikely given non-personal data).

<a id="international-data-transfers"></a>

## International Data Transfers

- All infrastructure (CI agents, Docker hosts, storage) resides within the EEA
- External APIs (HPE, OpsRamp) may process data outside the EEA; ensure adequacy decisions or SCCs
- No personal data is transferred; technical data only

<a id="third-party-processors"></a>

## Third-Party Processors

| Processor | Purpose | Data Category | Location | Safeguards |
|-----------|---------|---------------|----------|------------|
| HPE (downloads.hpe.com) | Firmware/driver downloads | Firmware components, server models | Global CDN | TLS 1.3, no personal data |
| OpsRamp (opsramp.com) | Monitoring/alerting | Server status, metric values | US (EU region available) | TLS, SOC 2 Type II |
| Docker Hub (if used) | Base image pulls | Base OS layers | Global | Content trust (Notary), signed images |
| Microsoft (Windows Update) | Security patches | KB numbers, patch metadata | Global | HTTPS |

All processors must comply with the Bank's third-party risk management requirements.

<a id="data-controller-responsibilities"></a>

## Data Controller Responsibilities

- Confirm this automation does not process personal data
- Rotate CI credentials regularly (90 days)
- Review audit logs weekly for anomalies
- Maintain this assessment documentation
- Respond to DPO inquiries

<a id="records-of-processing-activities-ropa"></a>

## Records of Processing Activities (ROPA)

Article 30 record:
- **System name:** HPE Windows ISO Automation
- **Purpose:** Automated server provisioning and patching
- **Data categories:** Server hostnames, firmware versions, patch statuses, build logs
- **Retention:** 30 days (logs), 7 years (audit reports in archive)
- **Security measures:** as described above
- **Data transfers:** to HPE, OpsRamp (non-EEA possible)
- **DPIA:** Not required (low risk)

<a id="compliance-checklist"></a>

## Compliance Checklist

- [x] Data minimization verified - no personal data collected
- [x] Purpose limitation documented
- [x] Retention periods defined and automated
- [x] Credentials stored in CI Credential Store (not in repo)
- [x] Access controls: CI agents run as non-root
- [x] Docker image uses non-root user (`appuser`)
- [x] Audit logging enabled (`generated/logs/audit/audit_trail.log`)
- [x] TLS enforced for all external API calls
- [x] No secrets in configuration files (use environment variables only)
- [x] Data residency confirmed (EEA-hosted infrastructure)
- [x] Third-party processor review completed
- [x] Incident response plan includes this system
- [x] Documentation reviewed by DPO (pending)
- [ ] Annual privacy review scheduled

<a id="contact"></a>

## Contact

- Data Protection Officer: dpo@yourbank.com
- Platform Engineering: platform@yourbank.com
- Security Team: security@yourbank.com

---

**Document version:** 1.0
**Effective date:** 2026-05-14
**Next review:** 2027-05-14
**Owner:** Platform Engineering
