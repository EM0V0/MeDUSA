# MeDUSA Postmarket Cybersecurity Management Plan

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Standard Reference**: FDA Guidance - Cybersecurity in Medical Devices (2025), IEC 81001-5-1, ISO 14971  
**Author**: Zhicheng Sun

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Scope and Applicability](#2-scope-and-applicability)
3. [Roles and Responsibilities](#3-roles-and-responsibilities)
4. [Vulnerability Monitoring](#4-vulnerability-monitoring)
5. [Vulnerability Assessment and Scoring](#5-vulnerability-assessment-and-scoring)
6. [Patch and Update Management](#6-patch-and-update-management)
7. [Security Incident Response](#7-security-incident-response)
8. [Coordinated Vulnerability Disclosure](#8-coordinated-vulnerability-disclosure)
9. [Information Sharing](#9-information-sharing)
10. [End-of-Life Planning](#10-end-of-life-planning)
11. [Documentation and Records](#11-documentation-and-records)
12. [Plan Review and Updates](#12-plan-review-and-updates)

---

## 1. Introduction

### 1.1 Purpose

This Postmarket Cybersecurity Management Plan establishes the processes, procedures, and responsibilities for managing cybersecurity risks throughout the operational lifecycle of the MeDUSA (Medical Device Universal Security Alignment) platform. This plan ensures continuous monitoring, assessment, and mitigation of cybersecurity vulnerabilities in accordance with FDA postmarket cybersecurity guidance.

### 1.2 Document Objectives

| Objective | Description |
|-----------|-------------|
| **Continuous Monitoring** | Establish mechanisms for ongoing vulnerability surveillance |
| **Risk Management** | Define processes for assessing and mitigating identified risks |
| **Incident Response** | Provide structured approach to security incidents |
| **Regulatory Compliance** | Ensure alignment with FDA postmarket expectations |
| **Stakeholder Communication** | Define information sharing protocols |

### 1.3 Regulatory Framework

This plan is developed in accordance with:

- FDA Guidance: Cybersecurity in Medical Devices: Quality System Considerations and Content of Premarket Submissions (2025)
- FDA Guidance: Postmarket Management of Cybersecurity in Medical Devices (2016, updated)
- IEC 81001-5-1: Health software and health IT systems safety, effectiveness and security
- ISO 14971: Medical devices — Application of risk management to medical devices
- NIST Cybersecurity Framework 2.0

---

## 2. Scope and Applicability

### 2.1 System Components Covered

| Component | Description | Criticality |
|-----------|-------------|-------------|
| **Flutter Frontend** | Cross-platform mobile/web application | High |
| **Python Backend** | AWS Lambda-based serverless API | Critical |
| **AWS Infrastructure** | DynamoDB, API Gateway, S3, SES, CloudWatch | Critical |
| **BLE Communication** | Bluetooth Low Energy device interface | High |
| **Third-Party Dependencies** | Open-source libraries and packages | Medium-High |

### 2.2 TPLC Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Total Product Life Cycle (TPLC)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   PREMARKET                              POSTMARKET                      │
│   ─────────                              ──────────                      │
│                                                                          │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐ │
│   │   Design    │──►│ Verification│──►│ Deployment  │──►│  Operation  │ │
│   │             │   │  & Testing  │   │             │   │             │ │
│   │ • Threat    │   │ • SAST/DAST │   │ • CI/CD     │   │ • Monitoring│ │
│   │   Modeling  │   │ • Pen Test  │   │ • Security  │   │ • Patching  │ │
│   │ • Risk      │   │ • Unit Test │   │   Audit     │   │ • Incident  │ │
│   │   Assessment│   │ • Compliance│   │ • Config    │   │   Response  │ │
│   │ • SBOM      │   │             │   │   Hardening │   │ • CVD       │ │
│   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘ │
│         │                 │                 │                 │          │
│         └─────────────────┴─────────────────┴─────────────────┘          │
│                           Continuous Feedback Loop                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Roles and Responsibilities

### 3.1 Organizational Structure

| Role | Responsibilities | Contact |
|------|------------------|---------|
| **Product Security Officer** | Overall cybersecurity program management, regulatory liaison | security@medusa-edu.org |
| **Development Lead** | Secure development practices, code review, patch implementation | dev@medusa-edu.org |
| **Operations Lead** | Infrastructure security, monitoring, incident detection | ops@medusa-edu.org |
| **Quality Assurance** | Verification of security controls, compliance testing | qa@medusa-edu.org |

### 3.2 Responsibility Matrix (RACI)

| Activity | Security Officer | Dev Lead | Ops Lead | QA |
|----------|-----------------|----------|----------|-----|
| Vulnerability Monitoring | A | R | R | I |
| Risk Assessment | A | C | C | R |
| Patch Development | I | A/R | C | R |
| Patch Deployment | A | R | R | R |
| Incident Response | A/R | R | R | C |
| Regulatory Reporting | A/R | C | C | I |
| Documentation | A | R | R | R |

**Legend**: A = Accountable, R = Responsible, C = Consulted, I = Informed

---

## 4. Vulnerability Monitoring

### 4.1 Continuous Monitoring Strategy

```
┌──────────────────────────────────────────────────────────────────┐
│                  Vulnerability Monitoring Pipeline                │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐            │
│   │  Automated  │   │   Manual    │   │  External   │            │
│   │  Scanning   │   │   Review    │   │   Sources   │            │
│   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘            │
│          │                 │                 │                    │
│          └─────────────────┼─────────────────┘                    │
│                            ▼                                      │
│                  ┌─────────────────┐                              │
│                  │  Vulnerability  │                              │
│                  │    Database     │                              │
│                  └────────┬────────┘                              │
│                           │                                       │
│                           ▼                                       │
│                  ┌─────────────────┐                              │
│                  │   Assessment    │                              │
│                  │   & Triage      │                              │
│                  └─────────────────┘                              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Automated Monitoring Tools

| Tool | Purpose | Frequency | Implementation |
|------|---------|-----------|----------------|
| **Dependabot** | Dependency vulnerability alerts | Real-time | GitHub integration |
| **Safety** | Python package CVE scanning | Daily (CI/CD) | `safety check -r requirements.txt` |
| **TruffleHog** | Secret/credential scanning | Per commit | GitHub Actions |
| **Bandit** | Python SAST | Per commit | GitHub Actions |
| **Flutter Analyze** | Dart/Flutter static analysis | Per commit | GitHub Actions |
| **AWS Security Hub** | Cloud infrastructure monitoring | Continuous | AWS native |

### 4.3 External Intelligence Sources

| Source | Type | URL |
|--------|------|-----|
| **NVD** | National Vulnerability Database | https://nvd.nist.gov/ |
| **CVE** | Common Vulnerabilities and Exposures | https://cve.mitre.org/ |
| **CISA ICS-CERT** | Industrial Control Systems Alerts | https://www.cisa.gov/uscert/ics |
| **GitHub Security Advisories** | Open-source vulnerability database | https://github.com/advisories |
| **AWS Security Bulletins** | Cloud provider advisories | https://aws.amazon.com/security/security-bulletins/ |
| **H-ISAC** | Healthcare sector intelligence sharing | https://h-isac.org/ |

### 4.4 Monitoring Schedule

| Activity | Frequency | Responsible |
|----------|-----------|-------------|
| Automated dependency scanning | Per commit + daily | CI/CD Pipeline |
| NVD/CVE database review | Weekly | Security Officer |
| Third-party advisory review | Weekly | Development Lead |
| AWS Security Hub review | Daily | Operations Lead |
| Comprehensive security assessment | Quarterly | External Assessor |

---

## 5. Vulnerability Assessment and Scoring

### 5.1 CVSS-Based Severity Classification

All identified vulnerabilities are assessed using the Common Vulnerability Scoring System (CVSS) v3.1:

| CVSS Score | Severity | Classification |
|------------|----------|----------------|
| 9.0 - 10.0 | Critical | Uncontrolled Risk |
| 7.0 - 8.9 | High | Uncontrolled Risk |
| 4.0 - 6.9 | Medium | Controlled Risk |
| 0.1 - 3.9 | Low | Controlled Risk |

### 5.2 Medical Device Risk Contextualization

Beyond CVSS scoring, vulnerabilities are assessed for medical device-specific impact:

| Factor | Assessment Criteria | Weight |
|--------|---------------------|--------|
| **Patient Safety Impact** | Could exploitation cause patient harm? | Critical |
| **Data Confidentiality** | Is PHI/PII at risk of exposure? | High |
| **System Availability** | Could exploitation disrupt clinical operations? | High |
| **Exploitability** | Is exploit code publicly available? | Medium |
| **Attack Vector** | Network-accessible vs. local access required | Medium |

### 5.3 Risk Assessment Matrix

```
                    LIKELIHOOD
                    Low    Medium    High
              ┌─────────┬─────────┬─────────┐
        High  │ Medium  │  High   │ Critical│
              ├─────────┼─────────┼─────────┤
IMPACT  Med   │   Low   │ Medium  │  High   │
              ├─────────┼─────────┼─────────┤
        Low   │   Low   │   Low   │ Medium  │
              └─────────┴─────────┴─────────┘
```

### 5.4 Vulnerability Triage Workflow

```
┌─────────────────┐
│  Vulnerability  │
│   Identified    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Initial Triage  │──── False Positive? ───► Documented & Closed
│  (24 hours)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ CVSS Scoring +  │
│ Context Analysis│
└────────┬────────┘
         │
    ┌────┴────┬────────────┬───────────┐
    ▼         ▼            ▼           ▼
Critical    High        Medium       Low
    │         │            │           │
    ▼         ▼            ▼           ▼
 24 hours   7 days      30 days    90 days
Remediation Timeline
```

---

## 6. Patch and Update Management

### 6.1 Remediation Timeline Requirements

| Severity | Initial Response | Remediation | Deployment |
|----------|-----------------|-------------|------------|
| **Critical** | 4 hours | 24 hours | Immediate |
| **High** | 24 hours | 7 days | Within 14 days |
| **Medium** | 72 hours | 30 days | Next scheduled release |
| **Low** | 7 days | 90 days | Next major release |

### 6.2 Patch Development Process

```
┌─────────────────────────────────────────────────────────────────┐
│                    Patch Development Workflow                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │  Develop │─►│   Test   │─►│  Review  │─►│  Deploy  │        │
│  │  Patch   │  │  Patch   │  │  & Approve│  │  Patch   │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│       │             │             │             │                │
│       ▼             ▼             ▼             ▼                │
│   • Code fix    • Unit tests  • Security   • Staged            │
│   • Impact      • Integration   review       rollout           │
│     analysis    • Regression  • QA sign-off • Monitoring       │
│   • SBOM update • Pen test    • Risk accept • Rollback plan    │
│                   (if needed)                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.3 Update Distribution Channels

| Component | Update Mechanism | Notification |
|-----------|-----------------|--------------|
| **Frontend (Web)** | Automatic deployment | In-app notification |
| **Frontend (Mobile)** | App store update | Push notification + Email |
| **Frontend (Desktop)** | Auto-updater / Manual download | Email + In-app alert |
| **Backend** | AWS SAM deployment | Transparent (no user action) |
| **Documentation** | GitHub repository | Release notes |

### 6.4 Rollback Procedures

| Scenario | Rollback Method | RTO |
|----------|-----------------|-----|
| **Backend deployment failure** | SAM rollback to previous version | < 15 minutes |
| **Frontend critical bug** | Revert to cached version | < 30 minutes |
| **Database corruption** | DynamoDB point-in-time recovery | < 1 hour |
| **Infrastructure compromise** | Terraform state restore | < 2 hours |

---

## 7. Security Incident Response

### 7.1 Incident Classification

| Level | Definition | Examples |
|-------|------------|----------|
| **P1 - Critical** | Active exploitation with patient safety impact | Data breach with PHI exposure, system compromise |
| **P2 - High** | Confirmed vulnerability with imminent threat | Zero-day affecting production, credential exposure |
| **P3 - Medium** | Vulnerability with exploitation potential | Unpatched known CVE, configuration weakness |
| **P4 - Low** | Minor security issue | Policy violation, low-impact misconfiguration |

### 7.2 Incident Response Phases

```
┌─────────────────────────────────────────────────────────────────┐
│                 Incident Response Lifecycle                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌────────────┐    ┌────────────┐    ┌────────────┐            │
│   │ Detection  │───►│ Analysis   │───►│Containment │            │
│   │ & Reporting│    │ & Triage   │    │            │            │
│   └────────────┘    └────────────┘    └────────────┘            │
│         │                                    │                   │
│         │                                    ▼                   │
│   ┌────────────┐    ┌────────────┐    ┌────────────┐            │
│   │  Lessons   │◄───│  Recovery  │◄───│Eradication │            │
│   │  Learned   │    │            │    │            │            │
│   └────────────┘    └────────────┘    └────────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Response Timeline Requirements

| Phase | P1 Critical | P2 High | P3 Medium | P4 Low |
|-------|-------------|---------|-----------|--------|
| **Detection to Acknowledgment** | 15 min | 1 hour | 4 hours | 24 hours |
| **Initial Analysis** | 1 hour | 4 hours | 24 hours | 72 hours |
| **Containment** | 2 hours | 8 hours | 48 hours | 1 week |
| **Eradication** | 24 hours | 72 hours | 1 week | 2 weeks |
| **Recovery** | 48 hours | 1 week | 2 weeks | 1 month |
| **Post-Incident Review** | 72 hours | 1 week | 2 weeks | 1 month |

### 7.4 Communication Protocol

| Stakeholder | P1 Critical | P2 High | P3-P4 |
|-------------|-------------|---------|-------|
| **Internal Team** | Immediate | 1 hour | Daily summary |
| **Affected Users** | 4 hours | 24 hours | As needed |
| **Regulatory Bodies (FDA)** | 24 hours (if reportable) | Assessment | N/A |
| **Law Enforcement** | If criminal activity suspected | Assessment | N/A |

### 7.5 Incident Documentation Requirements

Each incident must be documented with:

- Incident ID and classification
- Timeline of events
- Affected systems and data
- Root cause analysis
- Remediation actions taken
- Lessons learned
- Preventive measures implemented

---

## 8. Coordinated Vulnerability Disclosure

### 8.1 CVD Policy

MeDUSA maintains a Coordinated Vulnerability Disclosure policy to facilitate responsible reporting of security vulnerabilities by external researchers.

### 8.2 Reporting Channel

| Method | Contact | Response Time |
|--------|---------|---------------|
| **Email** | security@medusa-edu.org | 48 hours |
| **GitHub Security Advisory** | Private vulnerability reporting | 48 hours |
| **Encrypted Communication** | PGP key available on request | 48 hours |

### 8.3 CVD Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│              Coordinated Vulnerability Disclosure                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Day 0        Day 2         Day 7          Day 90               │
│    │            │             │              │                   │
│    ▼            ▼             ▼              ▼                   │
│  Report    Acknowledge    Validate &    Public                  │
│  Received   Receipt       Assess        Disclosure              │
│                                                                  │
│              ◄────────── Remediation Window ──────────►         │
│                           (90 days max)                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.4 Researcher Guidelines

- **In Scope**: All MeDUSA components (frontend, backend, infrastructure)
- **Out of Scope**: Social engineering, physical attacks, denial of service
- **Safe Harbor**: Good-faith security research will not result in legal action
- **Recognition**: Researchers may be acknowledged in security advisories (with consent)

---

## 9. Information Sharing

### 9.1 Information Sharing Organizations

| Organization | Purpose | Membership Status |
|--------------|---------|-------------------|
| **H-ISAC** | Healthcare sector threat intelligence | Recommended |
| **CISA** | Critical infrastructure protection | Public resources |
| **FDA** | Regulatory guidance and alerts | Compliance required |
| **ICS-CERT** | Industrial control system advisories | Public resources |

### 9.2 Shared Information Types

| Information Type | Sharing Level | Recipients |
|------------------|---------------|------------|
| **Threat Indicators** | TLP:WHITE | Public |
| **Vulnerability Details** | TLP:GREEN | Sector partners |
| **Incident Information** | TLP:AMBER | Affected parties |
| **Sensitive Technical Details** | TLP:RED | Named recipients only |

### 9.3 Regulatory Reporting Requirements

| Condition | Reporting Obligation | Timeline |
|-----------|---------------------|----------|
| **Vulnerability affecting patient safety** | FDA notification | 30 days |
| **Active exploitation in the wild** | FDA notification | 5 days |
| **Healthcare data breach** | HHS/OCR notification | 60 days |
| **Cybersecurity incident affecting device function** | MDR consideration | As required |

---

## 10. End-of-Life Planning

### 10.1 End-of-Support (EOS) Criteria

| Trigger | Description |
|---------|-------------|
| **Technology Obsolescence** | Underlying platform no longer supported |
| **Security Unsustainability** | Vulnerabilities cannot be adequately mitigated |
| **Regulatory Change** | Compliance requirements can no longer be met |
| **Business Decision** | Product line discontinuation |

### 10.2 EOS Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    End-of-Life Timeline                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Announcement    EOS           EOL          Data               │
│  (T-12 months)   (T-6 months)  (T=0)        Retention End      │
│       │              │           │              │                │
│       ▼              ▼           ▼              ▼                │
│   • User        • Security   • No new     • Data deletion      │
│     notification  patches      updates       per policy         │
│   • Migration     only       • Read-only   • Certificate       │
│     guidance    • No new       access        revocation         │
│   • Alternative   features   • Support                          │
│     recommendations           ends                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.3 Data Handling at EOL

| Data Type | Retention Period | Disposal Method |
|-----------|------------------|-----------------|
| **User credentials** | Deleted at EOL | Cryptographic erasure |
| **Patient data** | Per regulatory requirements | Secure deletion with certificate |
| **Audit logs** | 7 years post-EOL | Archived, then deleted |
| **System configurations** | 1 year post-EOL | Secure deletion |

### 10.4 Customer Communication

| Phase | Communication | Channel |
|-------|---------------|---------|
| **EOS Announcement** | 12-month advance notice | Email, In-app, Website |
| **Migration Support** | Data export tools and guidance | Documentation |
| **EOL Reminder** | Monthly countdown notifications | Email, In-app |
| **Final Notice** | 30-day final warning | All channels |

---

## 11. Documentation and Records

### 11.1 Required Documentation

| Document | Retention Period | Location |
|----------|------------------|----------|
| **Vulnerability Assessments** | Product lifetime + 5 years | Secure repository |
| **Incident Reports** | Product lifetime + 7 years | Secure repository |
| **Patch Release Notes** | Product lifetime + 5 years | GitHub releases |
| **Risk Assessments** | Product lifetime + 5 years | doc_assets/ |
| **Audit Logs** | 7 years | AWS CloudWatch / S3 |
| **CVD Communications** | 5 years | Secure email archive |

### 11.2 Audit Trail Requirements

All postmarket cybersecurity activities must maintain auditable records including:

- Date and time of activity
- Personnel involved
- Actions taken
- Outcomes and decisions
- Approval signatures (where applicable)

---

## 12. Plan Review and Updates

### 12.1 Review Schedule

| Review Type | Frequency | Trigger Events |
|-------------|-----------|----------------|
| **Routine Review** | Annually | Calendar-based |
| **Triggered Review** | As needed | Major incident, regulatory change |
| **Comprehensive Audit** | Every 2 years | Compliance verification |

### 12.2 Change Control

All modifications to this plan require:

1. Documented change request
2. Impact assessment
3. Approval from Product Security Officer
4. Communication to affected stakeholders
5. Training update (if procedures change)

### 12.3 Training Requirements

| Role | Training Frequency | Topics |
|------|-------------------|--------|
| **All Staff** | Annually | Security awareness, incident reporting |
| **Development Team** | Quarterly | Secure coding, vulnerability management |
| **Operations Team** | Quarterly | Monitoring, incident response |
| **Security Officer** | Continuous | Regulatory updates, threat landscape |

---

## Appendix A: Related Documents

| Document | Location | Purpose |
|----------|----------|---------|
| Threat Model | `doc_assets/01_premarket/Threat_Model.md` | STRIDE threat analysis |
| Risk Assessment | `doc_assets/01_premarket/ISO14971_Risk_Assessment.md` | ISO 14971 risk management |
| Security Traceability | `doc_assets/02_security/Security_Traceability_Matrix.md` | Requirements mapping |
| SBOM Documentation | `doc_assets/01_premarket/SBOM_Documentation.md` | Software bill of materials |
| FDA Checklist | `doc_assets/01_premarket/FDA_Premarket_Cybersecurity_Checklist.md` | Premarket compliance |
| Testing Guide | `doc_assets/04_testing/Testing_Guide.md` | Comprehensive test procedures |
| Security Implementation | `doc_assets/02_security/Security_Implementation_Summary.md` | Technical controls |

---

## Appendix B: Contact Information

| Role | Email | Phone | Availability |
|------|-------|-------|--------------|
| Security Officer | security@medusa-edu.org | On file | 24/7 for P1 |
| Development Lead | dev@medusa-edu.org | On file | Business hours |
| Operations Lead | ops@medusa-edu.org | On file | 24/7 on-call |
| Regulatory Affairs | regulatory@medusa-edu.org | On file | Business hours |

---

## Appendix C: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | February 2026 | Zhicheng Sun | Initial release |

---

**Document Control:**
- Document ID: MeDUSA-PMCM-001
- Classification: Internal
- Review Cycle: Annual
- Next Review: February 2027
