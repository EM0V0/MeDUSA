# MeDUSA Comprehensive Testing Guide

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Standard Reference**: FDA Premarket Cybersecurity Guidance (2025), IEC 62443, OWASP Testing Guide  
**Author**: Zhicheng Sun

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Test Environment Setup](#2-test-environment-setup)
3. [Functional Testing](#3-functional-testing)
4. [Security Testing](#4-security-testing)
5. [Performance Testing](#5-performance-testing)
6. [Compliance Testing](#6-compliance-testing)
7. [Test Execution Procedures](#7-test-execution-procedures)
8. [Test Report Template](#8-test-report-template)

---

## 1. Introduction

### 1.1 Purpose

This document provides comprehensive testing procedures for the MeDUSA platform, ensuring all functional, security, and compliance requirements are validated before deployment.

### 1.2 Scope

| Component | Test Coverage |
|-----------|---------------|
| Flutter Frontend | UI, Authentication, Data Display, BLE Integration |
| Python Backend | API Endpoints, Business Logic, Database Operations |
| AWS Infrastructure | Lambda, API Gateway, DynamoDB, SES |
| Security Controls | Authentication, Authorization, Encryption, Audit |

### 1.3 Testing Methodology

```
┌─────────────────────────────────────────────────────────────────┐
│                    MeDUSA Testing Pyramid                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                    ┌─────────────────┐                          │
│                    │   E2E Tests     │  ← Manual/Automated      │
│                    │   (10%)         │                          │
│                    └────────┬────────┘                          │
│                   ┌─────────┴─────────┐                         │
│                   │ Integration Tests │  ← API Testing          │
│                   │     (30%)         │                         │
│                   └─────────┬─────────┘                         │
│              ┌──────────────┴──────────────┐                    │
│              │       Unit Tests            │  ← pytest/flutter  │
│              │         (60%)               │                    │
│              └─────────────────────────────┘                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 Pass/Fail Criteria

| Severity | Criteria |
|----------|----------|
| **Critical** | Zero tolerance - must fix before release |
| **High** | Must fix before release or document risk acceptance |
| **Medium** | Should fix, may defer with justification |
| **Low** | Fix when feasible |

---

## 2. Test Environment Setup

### 2.1 Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Python | 3.10+ | Backend testing |
| Flutter | 3.x | Frontend testing |
| AWS CLI | 2.x | Cloud deployment verification |
| PowerShell | 7.x | Test script execution |
| pytest | 7.x | Python unit testing |
| Burp Suite | Latest | Security testing |
| OWASP ZAP | Latest | Automated security scanning |

### 2.2 Environment Configuration

#### Local Development Environment

```powershell
# 1. Clone repository
git clone https://github.com/EM0V0/MeDUSA.git
cd MeDUSA

# 2. Setup Python virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# 3. Install backend dependencies
cd backend/backend-py
pip install -r requirements.txt
pip install pytest pytest-cov

# 4. Set environment variables for local testing
$env:USE_MEMORY = "true"
$env:JWT_SECRET = "test-secret-key-for-local-testing-only"
$env:JWT_EXPIRE_SECONDS = "3600"

# 5. Start local backend
.\start_local.ps1
```

#### Frontend Test Environment

```powershell
# Navigate to frontend
cd frontend

# Install dependencies
flutter pub get

# Run tests
flutter test
```

### 2.3 Test Data Setup

| Data Type | Description | Location |
|-----------|-------------|----------|
| Test Users | Pre-configured accounts for each role | Created via API |
| Test Devices | Simulated tremor sensors | `tools/register_device.py` |
| Test Patients | Sample patient profiles | Created via API |

**Test Account Credentials:**

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin_test@medusa.local` | `Admin@Test123!` |
| Doctor | `doctor_test@medusa.local` | `Doctor@Test123!` |
| Patient | `patient_test@medusa.local` | `Patient@Test123!` |

---

## 3. Functional Testing

### 3.1 Authentication Module

#### TC-AUTH-001: User Registration

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-AUTH-001 |
| **Priority** | Critical |
| **Precondition** | API server running |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Send POST to `/api/v1/auth/register` with valid data | 201 Created |
| 2 | Verify response contains `userId` and `accessJwt` | Fields present |
| 3 | Attempt duplicate registration | 409 Conflict |
| 4 | Send request with weak password | 400 Bad Request with `INVALID_PASSWORD` |

**Test Script:**
```powershell
# Located at: backend/test_device_api.ps1
$response = Invoke-RestMethod -Uri "$API_URL/auth/register" -Method POST -Body (@{
    email = "newuser@test.com"
    password = "SecurePass123!"
    role = "patient"
} | ConvertTo-Json) -ContentType "application/json"

# Verify response
if ($response.userId -and $response.accessJwt) {
    Write-Host "✅ TC-AUTH-001 PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ TC-AUTH-001 FAILED" -ForegroundColor Red
}
```

**Pass Criteria:** All steps complete successfully  
**Fail Criteria:** Any step returns unexpected result

---

#### TC-AUTH-002: User Login

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-AUTH-002 |
| **Priority** | Critical |
| **Precondition** | User account exists |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | POST `/api/v1/auth/login` with valid credentials | 200 OK with tokens |
| 2 | POST with invalid password | 401 Unauthorized |
| 3 | POST with non-existent email | 401 Unauthorized |
| 4 | Verify `accessJwt` is valid JWT format | JWT decodes correctly |
| 5 | Verify `expiresIn` equals 3600 | Token TTL = 1 hour |

---

#### TC-AUTH-003: Token Refresh

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-AUTH-003 |
| **Priority** | High |
| **Precondition** | Valid refresh token |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | POST `/api/v1/auth/refresh` with valid refresh token | New access token |
| 2 | Use expired refresh token | 401 Unauthorized |
| 3 | Use revoked refresh token | 401 Unauthorized |

---

#### TC-AUTH-004: Password Reset Flow

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-AUTH-004 |
| **Priority** | High |
| **Precondition** | User with verified email |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | POST `/api/v1/auth/forgot-password` | Email sent (or 200 OK) |
| 2 | Use valid verification code | Password reset successful |
| 3 | Use expired code (>15 min) | 400 Bad Request |
| 4 | Use invalid code | 400 Bad Request |

---

### 3.2 Patient Management Module

#### TC-PAT-001: Create Patient Profile

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-PAT-001 |
| **Priority** | High |
| **Precondition** | Authenticated as Doctor/Admin |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | POST `/api/v1/patients` with complete profile | 201 Created |
| 2 | Verify `patient_id` generated | ID format: `PAT-XXX` |
| 3 | Attempt creation without auth | 401 Unauthorized |
| 4 | Attempt creation as Patient role | 403 Forbidden |

---

#### TC-PAT-002: Patient Data Access Control

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-PAT-002 |
| **Priority** | Critical |
| **Precondition** | Multiple patients exist |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Patient A requests own data | 200 OK with data |
| 2 | Patient A requests Patient B's data | 403 Forbidden |
| 3 | Doctor requests assigned patient | 200 OK |
| 4 | Doctor requests unassigned patient | 403 Forbidden |
| 5 | Admin requests any patient | 200 OK |

---

### 3.3 Device Management Module

#### TC-DEV-001: Device Registration

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-DEV-001 |
| **Priority** | High |
| **Precondition** | Authenticated user |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | POST `/api/v1/devices` with valid MAC | 201 Created |
| 2 | Attempt duplicate MAC registration | 409 Conflict |
| 3 | Verify device status is "available" | Status correct |

**Test Script:**
```powershell
# Located at: backend/test_device_api.ps1
.\test_device_api.ps1
```

---

#### TC-DEV-002: Device-Patient Binding

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-DEV-002 |
| **Priority** | High |
| **Precondition** | Device registered, Patient exists |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | PUT `/api/v1/devices/{id}/assign` | Device bound to patient |
| 2 | Query device status | Status = "in_use" |
| 3 | Attempt assign already-bound device | 409 Conflict |
| 4 | PUT `/api/v1/devices/{id}/unassign` | Device unbound |

---

### 3.4 Tremor Data Module

#### TC-TREMOR-001: Data Query

| Attribute | Value |
|-----------|-------|
| **Test ID** | TC-TREMOR-001 |
| **Priority** | High |
| **Precondition** | Tremor data exists for patient |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | GET `/api/v1/tremor/analysis?patient_id=X` | 200 OK with data |
| 2 | Verify data fields complete | All required fields present |
| 3 | Query with time range filter | Filtered results |
| 4 | Query non-existent patient | Empty result or 404 |

---

## 4. Security Testing

### 4.1 Authentication Security

#### ST-AUTH-001: Password Policy Enforcement

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-AUTH-001 |
| **Priority** | Critical |
| **Tools** | Manual, pytest |

**Test Cases:**

| Password | Expected | Reason |
|----------|----------|--------|
| `short` | Reject | < 8 characters |
| `alllowercase1!` | Reject | No uppercase |
| `ALLUPPERCASE1!` | Reject | No lowercase |
| `NoNumbers!!` | Reject | No digit |
| `NoSpecial123` | Reject | No special char |
| `ValidPass123!` | Accept | All requirements met |

**Test Script:**
```python
# Located at: backend/backend-py/test_security_features.py
python -m pytest test_security_features.py::TestPasswordValidator -v
```

---

#### ST-AUTH-002: JWT Token Security

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-AUTH-002 |
| **Priority** | Critical |
| **Tools** | Burp Suite, jwt.io |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Decode JWT and verify algorithm is HS256 | Algorithm correct |
| 2 | Attempt to change algorithm to "none" | Request rejected |
| 3 | Modify payload and re-sign with wrong key | 401 Unauthorized |
| 4 | Use token after expiration | 401 Unauthorized |
| 5 | Verify sensitive data not in token | No PII in payload |

---

#### ST-AUTH-003: Session Hijacking Prevention

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-AUTH-003 |
| **Priority** | High |
| **Tools** | Burp Suite |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Capture valid token via proxy | Token obtained |
| 2 | Logout from original session | Logout successful |
| 3 | Attempt to use captured token | Token should be invalid |

---

### 4.2 Authorization Security

#### ST-AUTHZ-001: RBAC Enforcement

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-AUTHZ-001 |
| **Priority** | Critical |
| **Tools** | Manual, PowerShell scripts |

**RBAC Test Matrix:**

| Endpoint | Admin | Doctor | Patient | Expected |
|----------|-------|--------|---------|----------|
| `GET /admin/health` | ✅ | ❌ | ❌ | Admin only |
| `GET /patients` | ✅ | ✅ | ❌ | Admin/Doctor |
| `POST /devices` | ✅ | ✅ | ✅ | All authenticated |
| `GET /devices/my` | ✅ | ✅ | ✅ | Own devices only |
| `DELETE /patients/{id}` | ✅ | ❌ | ❌ | Admin only |

**Test Script:**
```powershell
# Located at: backend/test_device_api.ps1
# Tests RBAC with different role tokens
```

---

#### ST-AUTHZ-002: Horizontal Privilege Escalation

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-AUTHZ-002 |
| **Priority** | Critical |
| **Tools** | Burp Suite |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Patient A | Token for Patient A |
| 2 | Request Patient B's data with A's token | 403 Forbidden |
| 3 | Attempt to modify Patient B's record | 403 Forbidden |
| 4 | Attempt to access Patient B's devices | 403 Forbidden |

---

### 4.3 Input Validation

#### ST-INPUT-001: SQL/NoSQL Injection

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-INPUT-001 |
| **Priority** | Critical |
| **Tools** | OWASP ZAP, Burp Suite |

**Test Payloads:**

```json
// Test in email field
{"email": "test@test.com' OR '1'='1", "password": "Test123!"}

// Test in patient_id parameter
GET /api/v1/patients/{"$gt":""}

// Test in search fields
{"name": {"$regex": ".*"}}
```

**Expected Result:** All injection attempts rejected with 400 Bad Request

---

#### ST-INPUT-002: XSS Prevention

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-INPUT-002 |
| **Priority** | High |
| **Tools** | OWASP ZAP |

**Test Payloads:**

```html
<script>alert('XSS')</script>
<img src=x onerror=alert('XSS')>
javascript:alert('XSS')
```

**Expected Result:** Payloads sanitized or rejected, no script execution

---

### 4.4 Encryption Verification

#### ST-CRYPTO-001: TLS Configuration

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-CRYPTO-001 |
| **Priority** | Critical |
| **Tools** | testssl.sh, sslyze |

**Test Steps:**

```bash
# Using testssl.sh
./testssl.sh https://<api-gateway-url>

# Expected results:
# - TLS 1.2 or 1.3 only (no TLS 1.0/1.1)
# - Strong cipher suites (AES-GCM, ChaCha20)
# - No weak ciphers (RC4, 3DES, CBC with SHA1)
# - Perfect Forward Secrecy (PFS) enabled
# - Valid certificate chain
```

**Test Script:**
```python
# Located at: tools/check_tls_version.py
python tools/check_tls_version.py
```

---

#### ST-CRYPTO-002: Password Storage

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-CRYPTO-002 |
| **Priority** | Critical |
| **Tools** | Database inspection |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Register new user | User created |
| 2 | Query DynamoDB for user record | Record found |
| 3 | Verify password field | Argon2id hash format |
| 4 | Verify no plaintext password | No `password` field |

---

### 4.5 API Security

#### ST-API-001: Rate Limiting

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-API-001 |
| **Priority** | High |
| **Tools** | Custom script, Baton |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Send 10 login requests in 1 minute | First 5 succeed |
| 2 | Send request #6-10 | 429 Too Many Requests |
| 3 | Wait 60 seconds | Requests succeed again |

---

#### ST-API-002: Security Headers

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-API-002 |
| **Priority** | Medium |
| **Tools** | OWASP ZAP, curl |

**Required Headers:**

| Header | Expected Value |
|--------|---------------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Content-Security-Policy` | Defined policy |

**Test Command:**
```powershell
curl -I https://<api-gateway-url>/api/v1/admin/health
```

---

### 4.6 Replay Attack Prevention

#### ST-REPLAY-001: Nonce Validation

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-REPLAY-001 |
| **Priority** | High |
| **Tools** | pytest |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Generate request with nonce | Request succeeds |
| 2 | Replay same request with same nonce | Request rejected |
| 3 | Use expired nonce (>5 min old) | Request rejected |

**Test Script:**
```python
# Located at: backend/backend-py/test_security_features.py
python -m pytest test_security_features.py::TestNonceService -v
```

---

## 5. Performance Testing

### 5.1 Load Testing

#### PT-LOAD-001: API Response Time

| Attribute | Value |
|-----------|-------|
| **Test ID** | PT-LOAD-001 |
| **Priority** | Medium |
| **Tools** | Baton, k6 |

**Test Parameters:**

| Metric | Target |
|--------|--------|
| Response time (p95) | < 500ms |
| Response time (p99) | < 1000ms |
| Throughput | > 100 req/s |

**Test Script:**
```bash
# Using Baton
baton -u https://<api-url>/api/v1/admin/health -c 50 -r 1000
```

---

#### PT-LOAD-002: Concurrent Users

| Attribute | Value |
|-----------|-------|
| **Test ID** | PT-LOAD-002 |
| **Priority** | Medium |
| **Tools** | k6, Artillery |

**Test Scenario:**

| Phase | Users | Duration |
|-------|-------|----------|
| Ramp-up | 1→50 | 2 min |
| Steady | 50 | 5 min |
| Ramp-down | 50→1 | 1 min |

**Pass Criteria:** No errors during steady state, response time < 1s

---

### 5.2 Stress Testing

#### PT-STRESS-001: DoS Resilience

| Attribute | Value |
|-----------|-------|
| **Test ID** | PT-STRESS-001 |
| **Priority** | High |
| **Tools** | Baton |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Send 1000 requests in 10 seconds | Rate limiting triggers |
| 2 | Verify legitimate requests still work | Service available |
| 3 | Remove load | Service recovers |

---

## 6. Compliance Testing

### 6.1 FDA Cybersecurity Requirements

#### CT-FDA-001: SBOM Verification

| Attribute | Value |
|-----------|-------|
| **Test ID** | CT-FDA-001 |
| **Priority** | Critical |
| **Reference** | FDA Premarket Guidance Section 8 |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Generate SBOM | CycloneDX JSON created |
| 2 | Verify all components listed | Complete inventory |
| 3 | Check vulnerability status | No critical/high CVEs |
| 4 | Verify license compliance | All licenses compatible |

**Test Script:**
```powershell
# Generate Backend SBOM
cd backend/backend-py
pip install cyclonedx-bom
cyclonedx-py -r requirements.txt -o sbom-backend.json

# Generate Frontend SBOM
cd frontend
dart run cyclonedx:cyclonedx -o sbom-frontend.json
```

---

#### CT-FDA-002: Threat Model Validation

| Attribute | Value |
|-----------|-------|
| **Test ID** | CT-FDA-002 |
| **Priority** | Critical |
| **Reference** | FDA Premarket Guidance Section 5 |

**Checklist:**

- [ ] STRIDE analysis completed for all components
- [ ] All identified threats have mitigations
- [ ] Residual risks documented and accepted
- [ ] Threat model document current (`doc_assets/Threat_Model.md`)

---

#### CT-FDA-003: Risk Assessment Verification

| Attribute | Value |
|-----------|-------|
| **Test ID** | CT-FDA-003 |
| **Priority** | Critical |
| **Reference** | ISO 14971:2019 |

**Checklist:**

- [ ] All hazards identified
- [ ] Risk levels assigned (Severity × Probability)
- [ ] Controls implemented for unacceptable risks
- [ ] Residual risk evaluation completed
- [ ] Document current (`doc_assets/ISO14971_Risk_Assessment.md`)

---

### 6.2 Security Controls Verification

#### CT-SEC-001: Authentication Controls

| Attribute | Value |
|-----------|-------|
| **Test ID** | CT-SEC-001 |
| **Priority** | Critical |
| **Reference** | Security_Traceability_Matrix.md |

**Verification Matrix:**

| Control | Implementation | Test | Result |
|---------|----------------|------|--------|
| Password complexity | `password_validator.py` | ST-AUTH-001 | ☐ |
| JWT authentication | `auth.py` | ST-AUTH-002 | ☐ |
| MFA support | `verification_service.dart` | Manual | ☐ |
| Session timeout | 1-hour access token | ST-AUTH-002 | ☐ |

---

## 7. Test Execution Procedures

### 7.1 Pre-Test Checklist

- [ ] Test environment configured per Section 2
- [ ] Test data created (accounts, devices, patients)
- [ ] Test tools installed and configured
- [ ] Previous test results archived
- [ ] Test plan reviewed and approved

### 7.2 Test Execution Order

```
Phase 1: Unit Tests (Automated)
├── Backend: pytest test_security_features.py
├── Backend: pytest test_audit_service.py
└── Frontend: flutter test

Phase 2: Integration Tests (Semi-Automated)
├── backend/test_device_api.ps1
├── backend/test_patient_api.ps1
├── backend/test_session_api.ps1
└── Manual API verification

Phase 3: Security Tests (Manual + Automated)
├── OWASP ZAP automated scan
├── Manual penetration testing
├── TLS verification: tools/check_tls_version.py
└── Compliance verification: tools/check_security_compliance.py

Phase 4: Performance Tests (Automated)
├── Load testing with Baton
└── Stress testing
```

### 7.3 Running All Tests

```powershell
# From repository root
cd MeDUSA

# 1. Run backend unit tests
cd backend/backend-py
$env:USE_MEMORY = "true"
$env:JWT_SECRET = "test-secret"
python -m pytest test_security_features.py test_audit_service.py -v --tb=short

# 2. Run frontend tests
cd ../../frontend
flutter test

# 3. Run API integration tests (requires running backend)
cd ../backend
.\test_device_api.ps1
.\test_patient_api.ps1
.\test_session_api.ps1

# 4. Run security compliance check
cd ../tools
python check_security_compliance.py
python check_tls_version.py
```

---

## 8. Test Report Template

### 8.1 Test Summary Report

```markdown
# MeDUSA Test Report

**Test Date**: [DATE]
**Tester**: [NAME]
**Version**: [VERSION]
**Environment**: [LOCAL/STAGING/PRODUCTION]

## Executive Summary

| Category | Total | Passed | Failed | Skipped |
|----------|-------|--------|--------|---------|
| Functional | XX | XX | XX | XX |
| Security | XX | XX | XX | XX |
| Performance | XX | XX | XX | XX |
| Compliance | XX | XX | XX | XX |
| **Total** | **XX** | **XX** | **XX** | **XX** |

## Pass Rate: XX%

## Critical Issues

| ID | Description | Severity | Status |
|----|-------------|----------|--------|
| | | | |

## Test Details

### Functional Tests
[Details...]

### Security Tests
[Details...]

### Recommendations
[Recommendations...]

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Tester | | | |
| Reviewer | | | |
| Approver | | | |
```

### 8.2 Defect Report Template

```markdown
# Defect Report

**Defect ID**: DEF-XXX
**Date Found**: [DATE]
**Found By**: [NAME]
**Severity**: [Critical/High/Medium/Low]
**Status**: [Open/In Progress/Resolved/Closed]

## Description
[Clear description of the defect]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Result
[What should happen]

## Actual Result
[What actually happened]

## Environment
- OS: [Operating System]
- Browser/App: [Version]
- Backend Version: [Version]

## Screenshots/Logs
[Attach relevant evidence]

## Resolution
[How it was fixed - filled after resolution]
```

---

## Appendix A: Test Tools Reference

| Tool | Purpose | Installation |
|------|---------|--------------|
| pytest | Python unit testing | `pip install pytest` |
| flutter test | Dart/Flutter testing | Built-in |
| Burp Suite | Web security testing | [portswigger.net](https://portswigger.net/burp) |
| OWASP ZAP | Automated security scanning | [zaproxy.org](https://www.zaproxy.org/) |
| testssl.sh | TLS configuration testing | [testssl.sh](https://testssl.sh/) |
| Baton | Load testing | `cargo install baton` |
| k6 | Performance testing | [k6.io](https://k6.io/) |

---

## Appendix B: Related Documents

| Document | Location |
|----------|----------|
| API Documentation | `doc_assets/API_DOCUMENTATION.md` |
| Security Implementation | `doc_assets/Security_Implementation_Summary.md` |
| Threat Model | `doc_assets/Threat_Model.md` |
| Risk Assessment | `doc_assets/ISO14971_Risk_Assessment.md` |
| Security Traceability | `doc_assets/Security_Traceability_Matrix.md` |
| SBOM Documentation | `doc_assets/SBOM_Documentation.md` |

---

## Appendix C: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Feb 2026 | Zhicheng Sun | Initial release |

---

**Document Control:**
- Document ID: MeDUSA-TEST-001
- Classification: Internal
- Review Cycle: Quarterly
- Next Review: May 2026
