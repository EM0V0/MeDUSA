# MeDUSA Preliminary Hazard Analysis (PHA)

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Standard Reference**: MIL-STD-882E, ISO 14971:2019, IEC 62443-3-2  
**Author**: Zhicheng Sun

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Description](#2-system-description)
3. [Hazard Identification Methodology](#3-hazard-identification-methodology)
4. [Hazard Categories](#4-hazard-categories)
5. [Preliminary Hazard List (PHL)](#5-preliminary-hazard-list-phl)
6. [Preliminary Hazard Analysis Worksheets](#6-preliminary-hazard-analysis-worksheets)
7. [Hazardous Situation Analysis](#7-hazardous-situation-analysis)
8. [Initial Risk Assessment](#8-initial-risk-assessment)
9. [Recommended Controls](#9-recommended-controls)
10. [PHA Summary and Conclusions](#10-pha-summary-and-conclusions)

---

## 1. Introduction

### 1.1 Purpose

This Preliminary Hazard Analysis (PHA) document identifies and analyzes potential hazards associated with the MeDUSA tremor monitoring platform during the early stages of system development. The PHA serves as the foundation for subsequent detailed risk analysis activities and informs security control requirements.

### 1.2 Scope

| In Scope | Out of Scope |
|----------|--------------|
| Flutter mobile/web/desktop application | Physical Raspberry Pi hardware safety |
| Python AWS Lambda backend | Electrical hazards of sensor devices |
| AWS cloud infrastructure | Environmental hazards |
| BLE communication interface | Manufacturing process hazards |
| Data storage and transmission | Distribution and logistics |

### 1.3 Objectives

1. Identify potential hazards before detailed design completion
2. Assess initial risk levels for identified hazards
3. Recommend design requirements to eliminate or control hazards
4. Provide traceability from hazards to safety requirements
5. Support FDA premarket cybersecurity submission requirements

### 1.4 Reference Documents

| Document | Standard | Application |
|----------|----------|-------------|
| MIL-STD-882E | System Safety | PHA methodology |
| ISO 14971:2019 | Medical Devices Risk Management | Risk assessment framework |
| IEC 62443-3-2 | Industrial Security | Security risk assessment |
| FDA Cybersecurity Guidance (2025) | Regulatory | Medical device requirements |
| NIST SP 800-30 | Information Security | Risk assessment guide |

---

## 2. System Description

### 2.1 System Overview

MeDUSA (Medical Device Universal Security Alignment) is a tremor monitoring platform designed for Parkinson's disease patients. The system collects sensor data from wearable devices, transmits data to cloud infrastructure, and provides visualization and analysis tools for healthcare providers.

### 2.2 System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         MeDUSA System Architecture                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐        ┌──────────────┐        ┌──────────────┐       │
│  │   Wearable   │  BLE   │   Mobile/    │ HTTPS  │    AWS       │       │
│  │   Sensor     │───────►│   Desktop    │───────►│   Backend    │       │
│  │   Device     │        │     App      │  TLS   │   (Lambda)   │       │
│  └──────────────┘        └──────────────┘        └──────┬───────┘       │
│        │                        │                        │               │
│        │                        │                        ▼               │
│        │                        │                 ┌──────────────┐       │
│        │                        │                 │   DynamoDB   │       │
│        │                        │                 │   (Data)     │       │
│        │                        │                 └──────────────┘       │
│        │                        │                        │               │
│        │                        ▼                        ▼               │
│  ┌─────┴────────────────────────────────────────────────────────┐       │
│  │                    Trust Boundaries                           │       │
│  │  TB1: Device ↔ App    TB2: App ↔ Cloud    TB3: Cloud ↔ DB    │       │
│  └───────────────────────────────────────────────────────────────┘       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 User Roles

| Role | Description | Data Access |
|------|-------------|-------------|
| **Patient** | End user wearing sensor device | Own data only |
| **Doctor** | Healthcare provider managing patients | Assigned patients |
| **Administrator** | System administrator | Full system access |

### 2.4 Data Types

| Data Category | Sensitivity | Examples |
|---------------|-------------|----------|
| **PHI** | High | Patient name, DOB, medical records |
| **Sensor Data** | Medium | Tremor measurements, timestamps |
| **Authentication** | Critical | Passwords, tokens, MFA secrets |
| **Device Info** | Medium | MAC address, device ID, firmware |
| **Audit Logs** | Medium | User actions, security events |

---

## 3. Hazard Identification Methodology

### 3.1 Approach

The PHA employs multiple complementary techniques to ensure comprehensive hazard identification:

```
┌─────────────────────────────────────────────────────────────────┐
│               Hazard Identification Techniques                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│   │   STRIDE    │   │   Checklist │   │   Expert    │          │
│   │   Analysis  │   │   Review    │   │   Judgment  │          │
│   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘          │
│          │                 │                 │                   │
│          └─────────────────┼─────────────────┘                   │
│                            ▼                                     │
│                   ┌─────────────────┐                            │
│                   │  Consolidated   │                            │
│                   │  Hazard List    │                            │
│                   └─────────────────┘                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 STRIDE Threat Categories

| Category | Description | Relevance to MeDUSA |
|----------|-------------|---------------------|
| **S**poofing | Impersonating users or devices | User authentication, device identity |
| **T**ampering | Modifying data or code | Sensor data, API requests |
| **R**epudiation | Denying actions performed | Audit trail requirements |
| **I**nformation Disclosure | Exposing confidential data | PHI protection |
| **D**enial of Service | Preventing legitimate access | System availability |
| **E**levation of Privilege | Gaining unauthorized access | RBAC enforcement |

### 3.3 Analysis Boundaries

| Boundary | Components | Threats Considered |
|----------|------------|-------------------|
| **Device-App Interface** | BLE communication | Spoofing, tampering, eavesdropping |
| **App-Cloud Interface** | HTTPS/TLS API | MITM, injection, session hijacking |
| **Cloud-Database Interface** | AWS internal | Data breach, integrity loss |
| **User Interface** | Flutter UI | Social engineering, input validation |

---

## 4. Hazard Categories

### 4.1 Cybersecurity Hazard Categories

| Category ID | Category | Description |
|-------------|----------|-------------|
| **CAT-AUTH** | Authentication | Hazards related to identity verification |
| **CAT-AUTHZ** | Authorization | Hazards related to access control |
| **CAT-CONF** | Confidentiality | Hazards involving data exposure |
| **CAT-INTG** | Integrity | Hazards involving data modification |
| **CAT-AVAIL** | Availability | Hazards affecting system access |
| **CAT-ACCT** | Accountability | Hazards affecting audit capability |

### 4.2 Medical Device Hazard Categories

| Category ID | Category | Description |
|-------------|----------|-------------|
| **CAT-DIAG** | Diagnostic | Incorrect or delayed diagnosis |
| **CAT-TREAT** | Treatment | Incorrect treatment decisions |
| **CAT-PRIV** | Privacy | Patient privacy violation |
| **CAT-SAFE** | Safety | Direct patient harm |

---

## 5. Preliminary Hazard List (PHL)

### 5.1 Authentication Hazards

| PH-ID | Hazard | STRIDE | Category |
|-------|--------|--------|----------|
| PH-001 | Weak password allows brute force attack | S | CAT-AUTH |
| PH-002 | Credential theft via phishing | S | CAT-AUTH |
| PH-003 | Session token hijacking | S | CAT-AUTH |
| PH-004 | MFA bypass through implementation flaw | S | CAT-AUTH |
| PH-005 | Password reset mechanism exploitation | S | CAT-AUTH |
| PH-006 | Refresh token theft and reuse | S | CAT-AUTH |

### 5.2 Authorization Hazards

| PH-ID | Hazard | STRIDE | Category |
|-------|--------|--------|----------|
| PH-007 | RBAC bypass allowing cross-patient access | E | CAT-AUTHZ |
| PH-008 | Privilege escalation from patient to admin | E | CAT-AUTHZ |
| PH-009 | IDOR allowing access to other users' data | E | CAT-AUTHZ |
| PH-010 | JWT manipulation to change role claims | E, T | CAT-AUTHZ |
| PH-011 | Missing function-level access control | E | CAT-AUTHZ |

### 5.3 Confidentiality Hazards

| PH-ID | Hazard | STRIDE | Category |
|-------|--------|--------|----------|
| PH-012 | PHI exposure through API response | I | CAT-CONF |
| PH-013 | Unencrypted data transmission | I | CAT-CONF |
| PH-014 | Insecure local data storage | I | CAT-CONF |
| PH-015 | Database breach exposing patient records | I | CAT-CONF |
| PH-016 | Log files containing sensitive data | I | CAT-CONF |
| PH-017 | Error messages revealing system information | I | CAT-CONF |

### 5.4 Integrity Hazards

| PH-ID | Hazard | STRIDE | Category |
|-------|--------|--------|----------|
| PH-018 | Sensor data tampering during transmission | T | CAT-INTG |
| PH-019 | API request modification (MITM) | T | CAT-INTG |
| PH-020 | SQL/NoSQL injection attacks | T | CAT-INTG |
| PH-021 | Device spoofing sending false data | S, T | CAT-INTG |
| PH-022 | Replay attacks resubmitting old data | T | CAT-INTG |
| PH-023 | Timestamp manipulation | T | CAT-INTG |

### 5.5 Availability Hazards

| PH-ID | Hazard | STRIDE | Category |
|-------|--------|--------|----------|
| PH-024 | API denial of service attack | D | CAT-AVAIL |
| PH-025 | Database resource exhaustion | D | CAT-AVAIL |
| PH-026 | Lambda concurrency limit abuse | D | CAT-AVAIL |
| PH-027 | Network-level DDoS attack | D | CAT-AVAIL |
| PH-028 | Account lockout abuse | D | CAT-AVAIL |

### 5.6 Accountability Hazards

| PH-ID | Hazard | STRIDE | Category |
|-------|--------|--------|----------|
| PH-029 | Insufficient audit logging | R | CAT-ACCT |
| PH-030 | Log tampering or deletion | R, T | CAT-ACCT |
| PH-031 | Shared account usage | R | CAT-ACCT |
| PH-032 | Missing timestamps in audit records | R | CAT-ACCT |

---

## 6. Preliminary Hazard Analysis Worksheets

### 6.1 PHA Worksheet: Authentication Hazards

| PH-ID | PH-001 |
|-------|--------|
| **Hazard** | Weak password allows brute force attack |
| **System Element** | Authentication module (`auth.py`) |
| **Causal Factors** | No password complexity enforcement, no lockout |
| **Potential Effects** | Unauthorized account access, PHI exposure |
| **Hazardous Situation** | Attacker gains access to patient account |
| **Initial Severity** | S3 - Serious |
| **Initial Probability** | P3 - Remote |
| **Initial Risk** | Medium (ALARP) |
| **Recommended Action** | Implement NIST password policy, account lockout |

| PH-ID | PH-003 |
|-------|--------|
| **Hazard** | Session token hijacking |
| **System Element** | JWT token mechanism |
| **Causal Factors** | Insecure token storage, XSS vulnerability |
| **Potential Effects** | Account takeover, unauthorized data access |
| **Hazardous Situation** | Attacker impersonates legitimate user |
| **Initial Severity** | S3 - Serious |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Low |
| **Recommended Action** | Secure storage, short expiration, HTTPS only |

| PH-ID | PH-004 |
|-------|--------|
| **Hazard** | MFA bypass through implementation flaw |
| **System Element** | TOTP verification service |
| **Causal Factors** | Time window too large, code reuse allowed |
| **Potential Effects** | MFA protection defeated |
| **Hazardous Situation** | Attacker bypasses MFA with stolen credentials |
| **Initial Severity** | S3 - Serious |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Low |
| **Recommended Action** | Strict time validation, one-time code use |

### 6.2 PHA Worksheet: Data Integrity Hazards

| PH-ID | PH-018 |
|-------|--------|
| **Hazard** | Sensor data tampering during transmission |
| **System Element** | BLE and HTTPS communication |
| **Causal Factors** | Unencrypted BLE, compromised TLS |
| **Potential Effects** | Incorrect tremor readings recorded |
| **Hazardous Situation** | Doctor makes treatment decision on false data |
| **Initial Severity** | S4 - Critical |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Medium (ALARP) |
| **Recommended Action** | End-to-end encryption, data validation |

| PH-ID | PH-021 |
|-------|--------|
| **Hazard** | Device spoofing sending false data |
| **System Element** | Device registration and binding |
| **Causal Factors** | No device authentication, MAC spoofing |
| **Potential Effects** | False sensor data attributed to patient |
| **Hazardous Situation** | Incorrect patient record contamination |
| **Initial Severity** | S4 - Critical |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Medium (ALARP) |
| **Recommended Action** | Device registration, admin approval, session binding |

| PH-ID | PH-022 |
|-------|--------|
| **Hazard** | Replay attacks resubmitting old data |
| **System Element** | API endpoints |
| **Causal Factors** | No nonce/timestamp validation |
| **Potential Effects** | Duplicate/outdated data recorded |
| **Hazardous Situation** | Stale data presented as current |
| **Initial Severity** | S3 - Serious |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Low |
| **Recommended Action** | Nonce-based replay protection, timestamp validation |

### 6.3 PHA Worksheet: Privacy Hazards

| PH-ID | PH-007 |
|-------|--------|
| **Hazard** | RBAC bypass allowing cross-patient access |
| **System Element** | RBAC module (`rbac.py`) |
| **Causal Factors** | Incomplete authorization checks |
| **Potential Effects** | Patient A accesses Patient B's data |
| **Hazardous Situation** | PHI breach, privacy violation |
| **Initial Severity** | S2 - Minor (privacy) to S3 |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Low |
| **Recommended Action** | Comprehensive RBAC testing, ownership verification |

| PH-ID | PH-015 |
|-------|--------|
| **Hazard** | Database breach exposing patient records |
| **System Element** | DynamoDB storage |
| **Causal Factors** | Misconfigured IAM, API vulnerability |
| **Potential Effects** | Mass PHI exposure |
| **Hazardous Situation** | Large-scale privacy breach |
| **Initial Severity** | S3 - Serious |
| **Initial Probability** | P2 - Improbable |
| **Initial Risk** | Low |
| **Recommended Action** | Encryption at rest, IAM least privilege, WAF |

---

## 7. Hazardous Situation Analysis

### 7.1 Hazardous Situation Catalog

| HS-ID | Hazard(s) | Hazardous Situation | Foreseeable Harm |
|-------|-----------|---------------------|------------------|
| HS-001 | PH-001, PH-002 | Attacker gains unauthorized access to patient account | PHI exposure, identity theft |
| HS-002 | PH-018, PH-021 | False tremor data recorded for patient | Incorrect treatment decision |
| HS-003 | PH-007, PH-009 | User accesses another patient's medical data | Privacy violation, trust breach |
| HS-004 | PH-024, PH-027 | System unavailable during patient monitoring | Missed critical tremor event |
| HS-005 | PH-010, PH-008 | Attacker escalates privileges to admin | System compromise, data breach |
| HS-006 | PH-029, PH-030 | Security incident occurs without audit trail | Inability to investigate/respond |

### 7.2 Harm Severity Analysis

| HS-ID | Primary Harm | Severity | Justification |
|-------|--------------|----------|---------------|
| HS-001 | PHI exposure | S3 | HIPAA violation, patient distress |
| HS-002 | Incorrect treatment | S4 | Could lead to medication errors |
| HS-003 | Privacy breach | S2-S3 | Regulatory violation, trust impact |
| HS-004 | Delayed care | S3 | Missed intervention opportunity |
| HS-005 | System compromise | S3-S4 | Widespread impact potential |
| HS-006 | Undetected breach | S3 | Prolonged exposure, regulatory |

### 7.3 Sequence of Events Analysis

#### HS-002: False Tremor Data Scenario

```
┌─────────────────────────────────────────────────────────────────┐
│         Sequence of Events: False Tremor Data (HS-002)          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Initiating Event              Contributing Factors              │
│        │                              │                          │
│        ▼                              ▼                          │
│  ┌──────────────┐             ┌──────────────┐                  │
│  │ Attacker     │             │ No device    │                  │
│  │ spoofs device│────────────►│ authentication│                  │
│  └──────────────┘             └──────────────┘                  │
│        │                                                         │
│        ▼                                                         │
│  ┌──────────────┐                                               │
│  │ False sensor │                                               │
│  │ data uploaded│                                               │
│  └──────────────┘                                               │
│        │                                                         │
│        ▼                                                         │
│  ┌──────────────┐             ┌──────────────┐                  │
│  │ Data stored  │────────────►│ Doctor views │                  │
│  │ in patient   │             │ falsified    │                  │
│  │ record       │             │ tremor data  │                  │
│  └──────────────┘             └──────────────┘                  │
│                                      │                           │
│                                      ▼                           │
│                               ┌──────────────┐                  │
│                               │ Incorrect    │                  │
│                               │ treatment    │                  │
│                               │ decision     │ ← HARM           │
│                               └──────────────┘                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Initial Risk Assessment

### 8.1 Risk Assessment Matrix

```
                         PROBABILITY
               P1      P2      P3      P4      P5
           ┌───────┬───────┬───────┬───────┬───────┐
       S5  │   M   │   H   │   U   │   U   │   U   │
           ├───────┼───────┼───────┼───────┼───────┤
       S4  │   L   │   M   │   H   │   U   │   U   │
           ├───────┼───────┼───────┼───────┼───────┤
SEVERITY   S3  │   L   │   L   │   M   │   H   │   U   │
           ├───────┼───────┼───────┼───────┼───────┤
       S2  │   L   │   L   │   L   │   M   │   H   │
           ├───────┼───────┼───────┼───────┼───────┤
       S1  │   L   │   L   │   L   │   L   │   M   │
           └───────┴───────┴───────┴───────┴───────┘

Legend: L = Low (Acceptable), M = Medium (ALARP), H = High, U = Unacceptable
```

### 8.2 Initial Risk Summary Table

| PH-ID | Hazard | Severity | Probability | Initial Risk | Action Required |
|-------|--------|----------|-------------|--------------|-----------------|
| PH-001 | Weak password brute force | S3 | P3 | **M** | ALARP - Design control |
| PH-002 | Credential phishing | S3 | P3 | **M** | ALARP - MFA required |
| PH-003 | Session token hijacking | S3 | P2 | L | Monitor |
| PH-004 | MFA bypass | S3 | P2 | L | Verify implementation |
| PH-005 | Password reset exploitation | S3 | P2 | L | Secure flow design |
| PH-006 | Refresh token theft | S3 | P2 | L | Secure storage |
| PH-007 | RBAC bypass | S3 | P2 | L | Comprehensive testing |
| PH-008 | Privilege escalation | S4 | P2 | **M** | ALARP - Design control |
| PH-009 | IDOR vulnerability | S3 | P2 | L | Input validation |
| PH-010 | JWT manipulation | S4 | P2 | **M** | ALARP - Signature verify |
| PH-011 | Missing access control | S3 | P2 | L | Code review |
| PH-012 | PHI exposure in API | S3 | P2 | L | Response filtering |
| PH-013 | Unencrypted transmission | S4 | P1 | L | TLS enforcement |
| PH-014 | Insecure local storage | S3 | P2 | L | Secure storage API |
| PH-015 | Database breach | S3 | P2 | L | AWS security controls |
| PH-016 | Sensitive data in logs | S2 | P3 | L | Log filtering |
| PH-017 | Information disclosure | S2 | P3 | L | Error handling |
| PH-018 | Data tampering | S4 | P2 | **M** | ALARP - Encryption |
| PH-019 | MITM attack | S4 | P1 | L | TLS 1.3 |
| PH-020 | Injection attacks | S4 | P2 | **M** | ALARP - Input validation |
| PH-021 | Device spoofing | S4 | P2 | **M** | ALARP - Device auth |
| PH-022 | Replay attacks | S3 | P2 | L | Nonce protection |
| PH-023 | Timestamp manipulation | S3 | P2 | L | Server-side timestamps |
| PH-024 | API DoS | S3 | P3 | **M** | ALARP - Rate limiting |
| PH-025 | DB resource exhaustion | S3 | P2 | L | On-demand scaling |
| PH-026 | Lambda abuse | S3 | P2 | L | Concurrency limits |
| PH-027 | DDoS attack | S3 | P3 | **M** | ALARP - WAF/Shield |
| PH-028 | Account lockout abuse | S2 | P2 | L | Lockout design |
| PH-029 | Insufficient logging | S2 | P3 | L | Audit requirements |
| PH-030 | Log tampering | S3 | P2 | L | Log protection |
| PH-031 | Shared accounts | S2 | P2 | L | Account policy |
| PH-032 | Missing timestamps | S2 | P2 | L | Logging requirements |

### 8.3 Risk Statistics Summary

| Risk Level | Count | Percentage |
|------------|-------|------------|
| **Unacceptable (U)** | 0 | 0% |
| **High (H)** | 0 | 0% |
| **Medium/ALARP (M)** | 9 | 28% |
| **Low (L)** | 23 | 72% |
| **Total** | 32 | 100% |

---

## 9. Recommended Controls

### 9.1 Design Requirements from PHA

| PH-ID | Risk | Recommended Control | Requirement ID |
|-------|------|---------------------|----------------|
| PH-001 | M | NIST-compliant password policy | REQ-SEC-001 |
| PH-002 | M | Mandatory MFA for all users | REQ-SEC-002 |
| PH-008 | M | JWT signature verification with HS256 | REQ-SEC-003 |
| PH-010 | M | Role claim validation on every request | REQ-SEC-004 |
| PH-018 | M | TLS 1.3 for all communications | REQ-SEC-005 |
| PH-020 | M | Pydantic input validation on all APIs | REQ-SEC-006 |
| PH-021 | M | Device registration with admin approval | REQ-SEC-007 |
| PH-024 | M | API Gateway rate limiting (100/min) | REQ-SEC-008 |
| PH-027 | M | AWS WAF with DDoS protection | REQ-SEC-009 |

### 9.2 Control Hierarchy Application

```
┌─────────────────────────────────────────────────────────────────┐
│                    Control Hierarchy (Preferred Order)           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   1. ELIMINATE ─────────► Remove hazard entirely                │
│         │                 Example: Not collecting unnecessary   │
│         │                          sensitive data               │
│         ▼                                                        │
│   2. SUBSTITUTE ────────► Replace with safer alternative        │
│         │                 Example: Argon2id instead of MD5      │
│         │                          for password hashing         │
│         ▼                                                        │
│   3. ENGINEERING ───────► Design controls                       │
│         │                 Example: TLS encryption, RBAC,        │
│         │                          input validation             │
│         ▼                                                        │
│   4. ADMINISTRATIVE ────► Policies and procedures               │
│         │                 Example: Password policy, training    │
│         │                                                        │
│         ▼                                                        │
│   5. PROTECTIVE ────────► Detection and response                │
│                           Example: Audit logging, monitoring    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 9.3 Control Implementation Matrix

| Requirement | Control Type | Implementation | Verification |
|-------------|--------------|----------------|--------------|
| REQ-SEC-001 | Engineering | `password_validator.py` | Unit test |
| REQ-SEC-002 | Engineering | TOTP in `verification_service.dart` | Integration test |
| REQ-SEC-003 | Engineering | `auth.py:decode_token()` | Unit test |
| REQ-SEC-004 | Engineering | `rbac.py:require_role()` | Integration test |
| REQ-SEC-005 | Engineering | `SecureNetworkService` | TLS scan |
| REQ-SEC-006 | Engineering | Pydantic models in API | Fuzz testing |
| REQ-SEC-007 | Administrative + Engineering | Device registration flow | API test |
| REQ-SEC-008 | Engineering | API Gateway configuration | Load test |
| REQ-SEC-009 | Engineering | AWS WAF rules | Penetration test |

---

## 10. PHA Summary and Conclusions

### 10.1 Key Findings

1. **No Unacceptable Risks Identified**: Initial analysis shows no hazards with unacceptable risk levels
2. **Nine ALARP Hazards**: Require design controls to reduce to acceptable levels
3. **Critical Areas**: Authentication, data integrity, and availability identified as primary concern areas
4. **Defense-in-Depth Required**: Multiple control layers needed for adequate protection

### 10.2 Risk Reduction Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                   Risk Reduction Approach                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ALARP Hazards (9)                                             │
│         │                                                        │
│         ├──► Authentication: MFA, password policy, token mgmt   │
│         │                                                        │
│         ├──► Data Integrity: TLS 1.3, input validation, signing │
│         │                                                        │
│         ├──► Availability: Rate limiting, WAF, auto-scaling     │
│         │                                                        │
│         └──► Authorization: RBAC, JWT validation, ownership     │
│                                                                  │
│   Expected Outcome: All risks reduced to L (Acceptable)         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.3 Next Steps

| Action | Responsible | Timeline |
|--------|-------------|----------|
| Implement recommended controls | Development Team | Design phase |
| Detailed FMEA for high-risk components | Risk Manager | Before development |
| Control effectiveness verification | QA Team | Integration testing |
| Residual risk evaluation | Risk Manager | Pre-release |
| PHA update with verification results | Author | Post-verification |

### 10.4 Traceability

This PHA feeds into:
- **ISO 14971 Risk Assessment**: Detailed risk analysis
- **Security Requirements Specification**: REQ-SEC-XXX requirements
- **Test Plan**: Verification test cases
- **Security Traceability Matrix**: Requirements to controls mapping

---

## Appendix A: Hazard Log Cross-Reference

| PH-ID | ISO 14971 Risk ID | STRIDE | Control ID | Test Case |
|-------|-------------------|--------|------------|-----------|
| PH-001 | R1 | S | RC1.1 | ST-AUTH-001 |
| PH-002 | R1 | S | RC1.2 | ST-AUTH-002 |
| PH-018 | R2 | T | RC2.2 | ST-INTG-001 |
| PH-021 | R4 | S, T | RC4.1-4.3 | TC-DEV-001 |
| PH-024 | R3 | D | RC3.1 | PT-LOAD-001 |

---

## Appendix B: Acronyms and Definitions

| Term | Definition |
|------|------------|
| **ALARP** | As Low As Reasonably Practicable |
| **BLE** | Bluetooth Low Energy |
| **FMEA** | Failure Mode and Effects Analysis |
| **IDOR** | Insecure Direct Object Reference |
| **MITM** | Man-in-the-Middle |
| **PHA** | Preliminary Hazard Analysis |
| **PHI** | Protected Health Information |
| **PHL** | Preliminary Hazard List |
| **RBAC** | Role-Based Access Control |
| **STRIDE** | Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation of Privilege |
| **TOTP** | Time-based One-Time Password |

---

## Appendix C: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | February 2026 | Zhicheng Sun | Initial release |

---

**Document Control:**
- Document ID: MeDUSA-PHA-001
- Classification: Internal
- Review Cycle: After design changes or annually
- Next Review: After control implementation verification
