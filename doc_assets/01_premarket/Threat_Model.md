# MeDUSA Threat Model Document

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Methodology**: STRIDE + PASTA (Process for Attack Simulation and Threat Analysis)  
**Reference**: MITRE/MDIC Playbook for Threat Modeling Medical Devices

---

## 1. Executive Summary

This document provides a comprehensive threat model for the MeDUSA (Medical Data Unified System & Analytics) platform. The analysis follows FDA/MITRE recommended approaches and identifies threats, attack vectors, and mitigations across the device-to-cloud architecture.

**System Overview**: MeDUSA is a tremor assessment platform for Parkinson's disease monitoring, comprising:
- Raspberry Pi 5 sensor device (hardware - out of scope for this document)
- Cross-platform Flutter mobile/desktop application
- AWS serverless backend (Lambda, DynamoDB, S3, API Gateway)

---

## 2. Scope & Boundaries

### 2.1 In Scope

| Component | Description |
|-----------|-------------|
| Flutter Application | Mobile/Desktop client application |
| API Gateway | AWS REST API endpoints |
| Lambda Functions | Backend business logic |
| DynamoDB | Data persistence layer |
| S3 Storage | File storage |
| Authentication System | JWT + MFA |

### 2.2 Out of Scope

| Component | Reason |
|-----------|--------|
| Raspberry Pi Hardware | Covered in separate hardware threat model |
| AWS Infrastructure | Covered by AWS shared responsibility model |
| Network Infrastructure | Carrier/ISP responsibility |

---

## 3. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────�?
�?                             MeDUSA System                                   �?
├─────────────────────────────────────────────────────────────────────────────�?
�?                                                                             �?
�? ┌──────────────�?     HTTPS/TLS 1.3      ┌──────────────────────────────�?�?
�? �?             �?◄──────────────────────�?�?                             �?�?
�? �?  Flutter    �?                         �?      AWS API Gateway        �?�?
�? �?  Mobile/    �?                         �?      (REST API)             �?�?
�? �?  Desktop    �?                         └──────────────┬───────────────�?�?
�? �?  App        �?                                        �?                �?
�? �?             �?                                        �?IAM Auth        �?
�? └──────────────�?                                        �?                �?
�?        �?                                  ┌──────────────────────────────�?�?
�?        �?BLE                               �?                             �?�?
�?        �?                                  �?      Lambda Functions       �?�?
�? ┌──────────────�?                         �?      (medusa-api-v3)        �?�?
�? �?             �?                         �?                             �?�?
�? �? Raspberry   �?─── MQTT/TLS ───────────�?�? ┌────────────────────────�?�?�?
�? �?    Pi       �?                         �? �? Auth    �? RBAC       �?�?�?
�? �?  Device     �?                         �? �? Module  �? Module     �?�?�?
�? �?             �?                         �? └──────────┴─────────────�?�?�?
�? └──────────────�?                         └──────────────┬───────────────�?�?
�?                                                          �?                �?
�?                                                          �?IAM Auth        �?
�?                                                          �?                �?
�?                                           ┌──────────────────────────────�?�?
�?                                           �?                             �?�?
�?                                           �?      Data Stores            �?�?
�?                                           �? ┌─────────�?┌─────────�?   �?�?
�?                                           �? │DynamoDB �?�?  S3    �?   �?�?
�?                                           �? �?Tables  �?�?Bucket  �?   �?�?
�?                                           �? └─────────�?└─────────�?   �?�?
�?                                           �?                             �?�?
�?                                           └──────────────────────────────�?�?
�?                                                                             �?
└─────────────────────────────────────────────────────────────────────────────�?
```

### 3.1 Trust Boundaries

| Boundary | Components | Trust Level |
|----------|------------|-------------|
| **TB1** | User Device �?Internet | Untrusted |
| **TB2** | Internet �?API Gateway | Semi-trusted (TLS protected) |
| **TB3** | API Gateway �?Lambda | Trusted (AWS internal) |
| **TB4** | Lambda �?DynamoDB/S3 | Trusted (AWS internal, IAM controlled) |

---

## 4. STRIDE Threat Analysis

### 4.1 Spoofing (Identity)

| ID | Threat | Attack Vector | Impact | Likelihood | Mitigation | Status |
|----|--------|---------------|--------|------------|------------|--------|
| S1 | User impersonation | Stolen credentials | High | Medium | MFA, strong password policy | �?Implemented |
| S2 | Session hijacking | Token theft | High | Low | Short-lived tokens, HTTPS only | �?Implemented |
| S3 | Device spoofing | Fake device registration | Medium | Low | Device authentication, admin approval | �?Implemented |
| S4 | API spoofing | Man-in-the-middle | High | Low | TLS 1.3, certificate validation | �?Implemented |

### 4.2 Tampering (Data Integrity)

| ID | Threat | Attack Vector | Impact | Likelihood | Mitigation | Status |
|----|--------|---------------|--------|------------|------------|--------|
| T1 | Tremor data modification | API parameter tampering | High | Low | Input validation, audit logging | �?Implemented |
| T2 | Patient record tampering | Unauthorized API calls | High | Low | RBAC, audit logging | �?Implemented |
| T3 | JWT token modification | Token forgery | Critical | Very Low | HS256 signature verification | �?Implemented |
| T4 | Request replay | Replay captured requests | Medium | Low | Timestamp validation, nonce | ⚠️ Partial |

### 4.3 Repudiation (Non-repudiation)

| ID | Threat | Attack Vector | Impact | Likelihood | Mitigation | Status |
|----|--------|---------------|--------|------------|------------|--------|
| R1 | Deny data access | No audit trail | Medium | Medium | CloudWatch logging | �?Implemented |
| R2 | Deny treatment decisions | Missing timestamps | High | Low | Immutable timestamps in DynamoDB | �?Implemented |
| R3 | Deny device actions | No device logging | Medium | Medium | Session-based tracking | �?Implemented |

### 4.4 Information Disclosure (Confidentiality)

| ID | Threat | Attack Vector | Impact | Likelihood | Mitigation | Status |
|----|--------|---------------|--------|------------|------------|--------|
| I1 | Patient data leak | Unauthorized access | Critical | Low | RBAC, encryption at rest | �?Implemented |
| I2 | Credential exposure | Log leakage | High | Low | Sensitive data masking | �?Implemented |
| I3 | API key exposure | Source code leak | High | Low | Environment variables, Secrets Manager | �?Implemented |
| I4 | Error message disclosure | Verbose errors | Low | Medium | Sanitized error responses | �?Implemented |

### 4.5 Denial of Service (Availability)

| ID | Threat | Attack Vector | Impact | Likelihood | Mitigation | Status |
|----|--------|---------------|--------|------------|------------|--------|
| D1 | API flooding | High request volume | Medium | Medium | API Gateway throttling | �?Implemented |
| D2 | Authentication brute force | Login attempts | Medium | Medium | Rate limiting (5 req/min) | �?Implemented |
| D3 | Lambda exhaustion | Resource-heavy requests | Medium | Low | Lambda concurrency limits | �?Implemented |
| D4 | Database throttling | High read/write | Medium | Low | DynamoDB on-demand billing | �?Implemented |

### 4.6 Elevation of Privilege

| ID | Threat | Attack Vector | Impact | Likelihood | Mitigation | Status |
|----|--------|---------------|--------|------------|------------|--------|
| E1 | Patient to Doctor | Role parameter injection | Critical | Very Low | Server-side role assignment | �?Implemented |
| E2 | Doctor to Admin | Token manipulation | Critical | Very Low | JWT signature verification | �?Implemented |
| E3 | Cross-patient access | IDOR vulnerability | High | Low | Patient ID validation in RBAC | �?Implemented |
| E4 | Lambda function escalation | IAM misconfiguration | High | Very Low | Least privilege IAM roles | �?Implemented |

---

## 5. Attack Trees

### 5.1 Unauthorized Patient Data Access

```
Goal: Access Patient Health Data Without Authorization
├── 1. Compromise User Account
�?  ├── 1.1 Credential Theft [MITIGATED: MFA]
�?  �?  ├── 1.1.1 Phishing
�?  �?  └── 1.1.2 Keylogger
�?  ├── 1.2 Session Hijacking [MITIGATED: HTTPS, Short tokens]
�?  └── 1.3 Brute Force [MITIGATED: Rate limiting]
├── 2. Exploit API Vulnerabilities
�?  ├── 2.1 IDOR (Insecure Direct Object Reference) [MITIGATED: RBAC checks]
�?  ├── 2.2 SQL/NoSQL Injection [MITIGATED: Pydantic validation]
�?  └── 2.3 Broken Access Control [MITIGATED: Role-based middleware]
├── 3. Intercept Data in Transit
�?  ├── 3.1 Man-in-the-Middle [MITIGATED: TLS 1.3]
�?  └── 3.2 SSL Stripping [MITIGATED: HSTS headers]
└── 4. Access Data at Rest
    ├── 4.1 Database Compromise [MITIGATED: AWS encryption]
    └── 4.2 Backup Exposure [MITIGATED: AWS managed backups]
```

### 5.2 Device Manipulation

```
Goal: Manipulate Medical Device or Data
├── 1. Spoof Device Identity
�?  ├── 1.1 Clone Device ID [MITIGATED: MAC binding]
�?  └── 1.2 Register Fake Device [MITIGATED: Admin approval]
├── 2. Inject False Data
�?  ├── 2.1 Modify Sensor Readings [MITIGATED: Timestamp validation]
�?  └── 2.2 Replay Old Data [PARTIAL: Session tokens]
└── 3. Disrupt Device Communication
    ├── 3.1 BLE Jamming [OUT OF SCOPE: Hardware]
    └── 3.2 API Flooding [MITIGATED: Rate limiting]
```

---

## 6. Patient Safety Impact Analysis

### 6.1 Safety-Critical Functions

| Function | Potential Harm | Severity | Mitigations |
|----------|---------------|----------|-------------|
| Tremor Score Display | Misdiagnosis if manipulated | High | Data integrity checks, audit logging |
| Medication Reminder | Missed doses if blocked | Medium | Local storage backup, offline mode |
| Alert Generation | Missed critical events | High | Multiple notification channels |
| Treatment History | Wrong decisions if altered | High | Immutable records, audit trail |

### 6.2 Risk Matrix

| Impact �?Likelihood �?| Very Low | Low | Medium | High |
|----------------------|----------|-----|--------|------|
| **Critical** | E1, E2 | I1 | | |
| **High** | T4 | T2, I3, E3 | S1, T1 | |
| **Medium** | D3, D4 | S3, R1, R3 | D1, D2 | |
| **Low** | | I4 | | |

---

## 7. Security Controls Summary

### 7.1 Preventive Controls

| Control | Threats Addressed | Implementation |
|---------|------------------|----------------|
| TLS 1.3 Encryption | S4, I1, I2 | `SecureNetworkService` |
| JWT Authentication | S1, S2, E1, E2 | `auth.py` |
| RBAC | E1, E2, E3, I1 | `rbac.py` |
| Input Validation | T1, T2, T3 | Pydantic models |
| Rate Limiting | D1, D2 | API Gateway config |
| Password Policy | S1 | `password_validator.py` |
| MFA | S1, S2 | TOTP implementation |

### 7.2 Detective Controls

| Control | Threats Addressed | Implementation |
|---------|------------------|----------------|
| CloudWatch Logging | R1, R2, R3 | AWS Lambda config |
| Security Scanning | All | GitHub Actions CI/CD |
| Dependency Scanning | Supply chain | Safety/Dependabot |

### 7.3 Corrective Controls

| Control | Threats Addressed | Implementation |
|---------|------------------|----------------|
| Token Revocation | S2 | Refresh token invalidation |
| Account Lockout | S1, D2 | Rate limiting response |
| Incident Response | All | Documented procedures |

---

## 8. Residual Risk Assessment

### 8.1 Accepted Residual Risks

| Risk ID | Description | Justification | Owner |
|---------|-------------|---------------|-------|
| T4 | Partial replay protection | Low likelihood, session-based mitigation adequate | Zhicheng Sun |
| D1 | DDoS beyond rate limits | AWS Shield provides additional protection | Zhicheng Sun |

### 8.2 Risk Acceptance Criteria

- Critical risks: Must be fully mitigated before deployment
- High risks: Must have compensating controls
- Medium risks: Acceptable with monitoring
- Low risks: Acceptable with documentation

---

## 9. Recommendations

### 9.1 Short-term (0-3 months)

1. **Implement request nonces** for replay attack protection (T4)
2. **Add anomaly detection** in CloudWatch for unusual access patterns
3. **Enable AWS WAF** for additional API protection

### 9.2 Medium-term (3-6 months)

1. **Conduct penetration testing** by third-party security firm
2. **Implement device attestation** for stronger device authentication
3. **Add data integrity verification** with checksums

### 9.3 Long-term (6-12 months)

1. **Implement zero-trust architecture** principles
2. **Add hardware security module (HSM)** for key management
3. **Achieve SOC 2 Type II certification**

---

## 10. Document Maintenance

| Action | Frequency | Responsible |
|--------|-----------|-------------|
| Threat model review | Quarterly | Zhicheng Sun |
| Control verification | Monthly | Zhicheng Sun |
| Risk assessment update | After any significant change | Zhicheng Sun |
| Penetration testing | Annually | Third-party |

---

## Appendix A: STRIDE Reference

| Category | Description | Security Property |
|----------|-------------|-------------------|
| **S**poofing | Impersonating something or someone | Authentication |
| **T**ampering | Modifying data or code | Integrity |
| **R**epudiation | Claiming to not have performed an action | Non-repudiation |
| **I**nformation Disclosure | Exposing information | Confidentiality |
| **D**enial of Service | Making system unavailable | Availability |
| **E**levation of Privilege | Gaining unauthorized capabilities | Authorization |

---

## Appendix B: References

1. MITRE & MDIC. (2021). Playbook for Threat Modeling Medical Devices
2. Microsoft. (2022). STRIDE Threat Model
3. FDA. (2025). Cybersecurity in Medical Devices Guidance
4. OWASP. (2023). Application Security Verification Standard

---

**Document Control:**
- Created: February 2026
- Author: Zhicheng Sun
- Review Cycle: Quarterly
- Approved By: Project Lead
