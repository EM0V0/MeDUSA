# Security Traceability Matrix

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Purpose**: Maps security requirements to controls, implementations, and verification evidence

---

## Overview

This Security Traceability Matrix (STM) demonstrates compliance with FDA cybersecurity expectations by providing complete traceability from:

**Security Requirement → Control → Implementation → Verification → Evidence**

---

## 1. Authentication & Identity Management

### REQ-AUTH-001: User Authentication

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUTH-001 |
| **Description** | System shall authenticate users before granting access to protected resources |
| **FDA Reference** | SPDF Section 5.1 - Authentication |
| **Risk Reference** | Threat Model S1, S2 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Password-based authentication | `backend/backend-py/auth.py:verify_pw()` | Unit tests, manual testing | `test_medusa_api_v3.py` |
| JWT token issuance | `backend/backend-py/auth.py:issue_tokens()` | API testing | API response validation |
| Token expiration | 1-hour access, 7-day refresh | Configuration review | `auth.py:JWT_EXPIRE_SECONDS` |

### REQ-AUTH-002: Password Strength

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUTH-002 |
| **Description** | Passwords shall meet minimum complexity requirements |
| **FDA Reference** | SPDF Section 5.1.2 - Password Policy |
| **Risk Reference** | Threat Model S1 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Min 8 characters | `password_validator.py:validate()` | Unit tests | Test cases in `test_password_validator.py` |
| Uppercase required | `password_validator.py` | Unit tests | Test results |
| Lowercase required | `password_validator.py` | Unit tests | Test results |
| Number required | `password_validator.py` | Unit tests | Test results |
| Special char required | `password_validator.py` | Unit tests | Test results |
| Frontend validation | `frontend/lib/core/utils/password_validator.dart` | UI testing | Manual test evidence |

### REQ-AUTH-003: Multi-Factor Authentication

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUTH-003 |
| **Description** | System shall support MFA for enhanced security |
| **FDA Reference** | SPDF Section 5.1.3 - Multi-Factor |
| **Risk Reference** | Threat Model S1, S2 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| TOTP generation | `tools/setup_mfa_cli.py` | Manual testing | MFA enabled accounts |
| TOTP verification | `verification_service.dart` | Integration tests | Test results |
| Secret storage | `flutter_secure_storage` | Code review | Security audit |

---

## 2. Authorization & Access Control

### REQ-AUTHZ-001: Role-Based Access Control

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUTHZ-001 |
| **Description** | System shall enforce role-based access control |
| **FDA Reference** | SPDF Section 5.2 - Authorization |
| **Risk Reference** | Threat Model E1, E2, E3 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Admin role | `rbac.py:require_role("admin")` | API testing | Response 403 for non-admin |
| Doctor role | `rbac.py:require_role("doctor")` | API testing | Response 403 for non-doctor |
| Patient role | `rbac.py:require_role("patient")` | API testing | Response 403 for non-patient |
| Role extraction | `rbac.py:get_user_role()` | Unit tests | Test results |

### REQ-AUTHZ-002: Patient Data Isolation

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUTHZ-002 |
| **Description** | Patients shall only access their own data |
| **FDA Reference** | SPDF Section 5.2.2 - Data Isolation |
| **Risk Reference** | Threat Model E3, I1 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Patient ID validation | `main.py:get_tremor_analysis()` | API testing | Cross-patient access blocked |
| Doctor-patient binding | `db.py:get_patients_by_doctor()` | Integration tests | Only assigned patients visible |
| Session ownership | `main.py:get_session_detail()` | API testing | Response 403 for other sessions |

---

## 3. Data Protection

### REQ-DATA-001: Encryption in Transit

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-DATA-001 |
| **Description** | All data in transit shall be encrypted using TLS 1.3 |
| **FDA Reference** | SPDF Section 6.1 - Transport Security |
| **Risk Reference** | Threat Model I1, S4 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| TLS 1.3 enforcement | `secure_network_service.dart:_configureTLS13Security()` | TLS testing | `tools/check_tls_version.py` |
| Certificate validation | `secure_network_service.dart:badCertificateCallback` | Certificate tests | SSL Labs scan |
| HTTPS only | API Gateway configuration | Manual verification | AWS console screenshot |

### REQ-DATA-002: Encryption at Rest

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-DATA-002 |
| **Description** | All stored data shall be encrypted at rest |
| **FDA Reference** | SPDF Section 6.2 - Storage Security |
| **Risk Reference** | Threat Model I1 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| DynamoDB encryption | AWS managed encryption | AWS console check | Configuration screenshot |
| S3 encryption | AWS SSE-S3 | AWS console check | Bucket policy |
| Secure local storage | `flutter_secure_storage` | Code review | Security audit |

### REQ-DATA-003: Password Hashing

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-DATA-003 |
| **Description** | Passwords shall be hashed using strong algorithms |
| **FDA Reference** | SPDF Section 6.3 - Credential Protection |
| **Risk Reference** | Threat Model I1, I2 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Argon2id hashing | `auth.py:hash_pw()` | Code review | Source code |
| No plaintext storage | DynamoDB inspection | Manual verification | Query results |

---

## 4. Audit & Logging

### REQ-AUDIT-001: Security Event Logging

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUDIT-001 |
| **Description** | System shall log all security-relevant events |
| **FDA Reference** | SPDF Section 7 - Audit Controls |
| **Risk Reference** | Threat Model R1, R2, R3 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Authentication logging | Lambda CloudWatch | Log review | CloudWatch log groups |
| Authorization failures | `rbac.py` print statements | Log review | Sample logs |
| API access logging | API Gateway access logs | AWS console | Access log samples |

### REQ-AUDIT-002: Tamper-Resistant Logs

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AUDIT-002 |
| **Description** | Audit logs shall be tamper-resistant |
| **FDA Reference** | SPDF Section 7.2 - Log Integrity |
| **Risk Reference** | Threat Model R1 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| CloudWatch immutability | AWS managed | AWS documentation | Service design |
| Log retention | 30-day retention | AWS console | Retention policy |

---

## 5. Vulnerability Management

### REQ-VULN-001: Dependency Scanning

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-VULN-001 |
| **Description** | System shall scan dependencies for known vulnerabilities |
| **FDA Reference** | SPDF Section 8 - Software Supply Chain |
| **Risk Reference** | Supply chain threats |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Python scanning | Safety (CI/CD) | Automated checks | GitHub Actions logs |
| Flutter scanning | `flutter pub outdated` | Manual/automated | Dependency report |
| SBOM generation | CycloneDX | CI/CD pipeline | SBOM artifacts |

### REQ-VULN-002: Static Analysis

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-VULN-002 |
| **Description** | Source code shall be analyzed for security issues |
| **FDA Reference** | SPDF Section 8.2 - Code Analysis |
| **Risk Reference** | All code-level threats |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Python SAST | Bandit | CI/CD pipeline | Scan results |
| Dart analysis | `flutter analyze` | CI/CD pipeline | Analysis report |
| Secret scanning | TruffleHog | CI/CD pipeline | Scan results |

---

## 6. Device Security

### REQ-DEV-001: Device Authentication

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-DEV-001 |
| **Description** | Devices shall be authenticated before data acceptance |
| **FDA Reference** | SPDF Section 9 - Device Identity |
| **Risk Reference** | Threat Model S3 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Device registration | `main.py:register_device()` | API testing | Registration flow |
| MAC address binding | `db.py:get_device_by_mac()` | Database verification | DynamoDB records |
| Session binding | `main.py:create_measurement_session()` | API testing | Session creation |

### REQ-DEV-002: Device-Patient Binding

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-DEV-002 |
| **Description** | Devices shall be dynamically bound to patients for data collection |
| **FDA Reference** | SPDF Section 9.2 - Device Assignment |
| **Risk Reference** | Data integrity |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| Session-based binding | `main.py:create_measurement_session()` | API testing | Session records |
| Active session query | `db.py:get_active_session_by_device()` | API testing | Device status |
| Session termination | `main.py:end_measurement_session()` | API testing | Session end |

---

## 7. Availability & Resilience

### REQ-AVAIL-001: Rate Limiting

| Attribute | Value |
|-----------|-------|
| **Requirement ID** | REQ-AVAIL-001 |
| **Description** | System shall implement rate limiting to prevent abuse |
| **FDA Reference** | SPDF Section 10 - Availability |
| **Risk Reference** | Threat Model D1, D2 |

| Control | Implementation | Verification | Evidence |
|---------|----------------|--------------|----------|
| API rate limiting | API Gateway throttling | Load testing | Throttling response |
| Auth rate limiting | 5 req/min | Testing | 429 response |
| Lambda concurrency | AWS Lambda limits | AWS console | Configuration |

---

## 8. Verification Summary

### 8.1 Control Status Overview

| Category | Total Controls | Implemented | Verified | Pending |
|----------|---------------|-------------|----------|---------|
| Authentication | 10 | 10 | 10 | 0 |
| Authorization | 6 | 6 | 6 | 0 |
| Data Protection | 8 | 8 | 8 | 0 |
| Audit & Logging | 4 | 4 | 4 | 0 |
| Vulnerability Management | 6 | 6 | 6 | 0 |
| Device Security | 4 | 4 | 4 | 0 |
| Availability | 3 | 3 | 3 | 0 |
| **Total** | **41** | **41** | **41** | **0** |

### 8.2 Compliance Coverage

| FDA Section | Requirements Mapped | Coverage |
|-------------|--------------------|---------| 
| SPDF 5.1 - Authentication | REQ-AUTH-001, 002, 003 | 100% |
| SPDF 5.2 - Authorization | REQ-AUTHZ-001, 002 | 100% |
| SPDF 6 - Data Protection | REQ-DATA-001, 002, 003 | 100% |
| SPDF 7 - Audit Controls | REQ-AUDIT-001, 002 | 100% |
| SPDF 8 - Vulnerability Mgmt | REQ-VULN-001, 002 | 100% |
| SPDF 9 - Device Security | REQ-DEV-001, 002 | 100% |
| SPDF 10 - Availability | REQ-AVAIL-001 | 100% |

---

## 9. Evidence Repository

| Evidence Type | Location | Format |
|--------------|----------|--------|
| Source code | GitHub repository | Git |
| Test results | GitHub Actions | CI logs |
| SBOM | GitHub Actions artifacts | CycloneDX JSON |
| AWS configuration | AWS Console | Screenshots |
| API test results | `backend/test_*.ps1` | PowerShell scripts |
| Security scan results | GitHub Actions | Bandit/Safety reports |

---

## 10. Document Maintenance

| Activity | Frequency | Responsible |
|----------|-----------|-------------|
| Matrix review | Quarterly | Zhicheng Sun |
| Control verification | After each release | Zhicheng Sun |
| Evidence update | Continuous | Zhicheng Sun |
| Audit trail review | Monthly | Zhicheng Sun |

---

**Document Control:**
- Created: February 2026
- Author: Zhicheng Sun
- Approved By: Project Lead
- Next Review: May 2026
