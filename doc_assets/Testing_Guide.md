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

#### Development & Unit Testing

| Requirement | Version | Purpose |
|-------------|---------|----------|
| Python | 3.10+ | Backend testing |
| Flutter | 3.x | Frontend testing |
| AWS CLI | 2.x | Cloud deployment verification |
| PowerShell | 7.x | Test script execution |
| pytest | 7.x | Python unit testing |

#### Professional Penetration Testing Tools

| Tool | Category | Purpose | Installation |
|------|----------|---------|-------------|
| **Burp Suite Pro** | Web Security | HTTP interception, scanning, exploitation | [portswigger.net](https://portswigger.net/burp) |
| **OWASP ZAP** | DAST | Automated vulnerability scanning | `docker pull zaproxy/zap-stable` |
| **Nmap** | Network | Port scanning, service detection | `apt install nmap` / `choco install nmap` |
| **Nikto** | Web Server | Web server vulnerability scanner | `apt install nikto` |
| **SQLMap** | Injection | Automated SQL injection testing | `pip install sqlmap` |
| **Hydra** | Brute Force | Password cracking, auth testing | `apt install hydra` |
| **Nessus** | Vulnerability | Enterprise vulnerability scanner | [tenable.com](https://www.tenable.com/products/nessus) |
| **testssl.sh** | TLS/SSL | TLS configuration analysis | `git clone https://github.com/drwetter/testssl.sh` |
| **Nuclei** | Vulnerability | Template-based vuln scanner | `go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest` |
| **ffuf** | Fuzzing | Web fuzzer for directories/params | `go install github.com/ffuf/ffuf/v2@latest` |
| **MobSF** | Mobile | Mobile app security testing | `docker pull opensecurity/mobile-security-framework-mobsf` |
| **Wireshark** | Network | Packet capture and analysis | [wireshark.org](https://www.wireshark.org/) |
| **Metasploit** | Exploitation | Penetration testing framework | `curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && chmod 755 msfinstall && ./msfinstall` |
| **Gobuster** | Enumeration | Directory/DNS brute forcing | `go install github.com/OJ/gobuster/v3@latest` |
| **JWT_Tool** | JWT | JWT token testing & exploitation | `pip install jwt_tool` |

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
| **Tools** | pytest, Hydra, Burp Suite Intruder |

**Test Cases:**

| Password | Expected | Reason |
|----------|----------|--------|
| `short` | Reject | < 8 characters |
| `alllowercase1!` | Reject | No uppercase |
| `ALLUPPERCASE1!` | Reject | No lowercase |
| `NoNumbers!!` | Reject | No digit |
| `NoSpecial123` | Reject | No special char |
| `ValidPass123!` | Accept | All requirements met |

**Unit Test:**
```python
# Located at: backend/backend-py/test_security_features.py
python -m pytest test_security_features.py::TestPasswordValidator -v
```

**Brute Force Testing with Hydra:**
```bash
# Test rate limiting and account lockout
hydra -l admin_test@medusa.local -P /usr/share/wordlists/rockyou.txt \
  <api-gateway-host> https-post-form \
  "/api/v1/auth/login:email=^USER^&password=^PASS^:Invalid credentials"

# Expected: Rate limiting should block after 5 attempts
```

**Burp Suite Intruder Test:**
1. Capture login request in Burp Proxy
2. Send to Intruder → Set password field as payload position
3. Load weak password wordlist (top 1000 passwords)
4. Start attack → Verify rate limiting triggers after 5 attempts

---

#### ST-AUTH-002: JWT Token Security

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-AUTH-002 |
| **Priority** | Critical |
| **Tools** | JWT_Tool, Burp Suite, jwt.io |

**Test Steps:**

| Step | Action | Expected Result |
|------|--------|------------------|
| 1 | Decode JWT and verify algorithm is HS256 | Algorithm correct |
| 2 | Attempt to change algorithm to "none" | Request rejected |
| 3 | Modify payload and re-sign with wrong key | 401 Unauthorized |
| 4 | Use token after expiration | 401 Unauthorized |
| 5 | Verify sensitive data not in token | No PII in payload |

**JWT_Tool Commands:**
```bash
# Install JWT_Tool
pip install jwt_tool

# Decode and analyze token
jwt_tool <token>

# Test algorithm confusion attack (alg:none)
jwt_tool <token> -X a

# Test key confusion attack (RS256 → HS256)
jwt_tool <token> -X k -pk public_key.pem

# Brute force weak secret
jwt_tool <token> -C -d /usr/share/wordlists/rockyou.txt

# Tamper claims and re-sign (if secret known)
jwt_tool <token> -T -S hs256 -p "test-secret"
```

**Burp Suite JWT Testing:**
1. Install "JWT Editor" extension from BApp Store
2. Capture authenticated request
3. In JWT Editor tab → try algorithm substitution attacks
4. Verify server rejects tampered tokens

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

### 4.3 Input Validation & Injection Testing

#### ST-INPUT-001: SQL/NoSQL Injection

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-INPUT-001 |
| **Priority** | Critical |
| **Tools** | SQLMap, Burp Suite Pro, NoSQLMap |

**SQLMap Automated Testing:**
```bash
# Test login endpoint for SQL injection
sqlmap -u "https://<api-url>/api/v1/auth/login" \
  --data='{"email":"test@test.com","password":"test"}' \
  --headers="Content-Type: application/json" \
  --level=5 --risk=3 --batch

# Test patient endpoint with authenticated session
sqlmap -u "https://<api-url>/api/v1/patients?id=1" \
  --headers="Authorization: Bearer <token>" \
  --level=5 --risk=3 --batch --dbs

# NoSQL injection specific payloads
sqlmap -u "https://<api-url>/api/v1/patients" \
  --data='{"patient_id":{"$gt":""}}' \
  --headers="Content-Type: application/json" \
  --tamper=between,randomcase --batch
```

**Manual NoSQL Injection Payloads:**
```json
// MongoDB operator injection
{"email": {"$gt": ""}, "password": {"$gt": ""}}
{"email": {"$regex": ".*"}, "password": {"$regex": ".*"}}
{"email": {"$ne": ""}, "password": {"$ne": ""}}

// DynamoDB injection attempts
{"patient_id": {"S": {"$or": [{}, {"a": "a"}]}}}
```

**Burp Suite Active Scan:**
1. Configure target scope: `https://<api-url>/*`
2. Spider the application with authenticated session
3. Right-click → "Active scan" on API endpoints
4. Review "Issues" tab for injection vulnerabilities

**Expected Result:** All injection attempts rejected with 400 Bad Request

---

#### ST-INPUT-002: XSS Prevention

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-INPUT-002 |
| **Priority** | High |
| **Tools** | OWASP ZAP, Burp Suite, XSStrike |

**XSStrike Automated Testing:**
```bash
# Install XSStrike
git clone https://github.com/s0md3v/XSStrike.git
cd XSStrike
pip install -r requirements.txt

# Test patient name field
python xsstrike.py -u "https://<api-url>/api/v1/patients" \
  --data '{"first_name":"test"}' \
  --headers "Authorization: Bearer <token>"
```

**Manual XSS Payloads (OWASP Cheat Sheet):**
```html
<!-- Basic XSS -->
<script>alert('XSS')</script>
<img src=x onerror=alert('XSS')>
<svg onload=alert('XSS')>

<!-- Encoded XSS -->
%3Cscript%3Ealert('XSS')%3C/script%3E
&#60;script&#62;alert('XSS')&#60;/script&#62;

<!-- Event handlers -->
<body onload=alert('XSS')>
<input onfocus=alert('XSS') autofocus>
```

**Expected Result:** Payloads sanitized or rejected, no script execution

---

### 4.4 Encryption Verification

#### ST-CRYPTO-001: TLS Configuration

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-CRYPTO-001 |
| **Priority** | Critical |
| **Tools** | testssl.sh, sslyze, Nmap, OpenSSL |

**testssl.sh Comprehensive Scan:**
```bash
# Clone and run testssl.sh
git clone https://github.com/drwetter/testssl.sh.git
cd testssl.sh

# Full scan with all checks
./testssl.sh --full https://<api-gateway-url>

# Quick vulnerability check
./testssl.sh --vulnerable https://<api-gateway-url>

# Check specific vulnerabilities
./testssl.sh --heartbleed --ccs --ticketbleed --robot \
  --crime --breach --poodle --tls-fallback --sweet32 \
  --freak --drown --logjam --beast https://<api-gateway-url>

# Export results as JSON
./testssl.sh --jsonfile results.json https://<api-gateway-url>
```

**sslyze Scan:**
```bash
# Install sslyze
pip install sslyze

# Run comprehensive scan
sslyze --regular <api-gateway-host>:443

# Check for specific issues
sslyze --certinfo --compression --fallback --heartbleed \
  --openssl_ccs --reneg --resum --robot <api-gateway-host>:443
```

**Nmap SSL/TLS Scripts:**
```bash
# Enumerate SSL/TLS ciphers
nmap --script ssl-enum-ciphers -p 443 <api-gateway-host>

# Check for vulnerabilities
nmap --script ssl-heartbleed,ssl-poodle,ssl-ccs-injection \
  -p 443 <api-gateway-host>

# Certificate information
nmap --script ssl-cert -p 443 <api-gateway-host>
```

**OpenSSL Manual Testing:**
```bash
# Test TLS 1.3 support
openssl s_client -connect <api-gateway-host>:443 -tls1_3

# Test TLS 1.2 (should work)
openssl s_client -connect <api-gateway-host>:443 -tls1_2

# Test TLS 1.1 (should fail)
openssl s_client -connect <api-gateway-host>:443 -tls1_1

# Check certificate chain
openssl s_client -connect <api-gateway-host>:443 -showcerts
```

**Pass Criteria:**
- TLS 1.2 or 1.3 only (no TLS 1.0/1.1)
- Strong cipher suites (AES-GCM, ChaCha20-Poly1305)
- No weak ciphers (RC4, 3DES, CBC with SHA1, EXPORT)
- Perfect Forward Secrecy (ECDHE/DHE) enabled
- Valid certificate chain with proper trust path
- HSTS header present

**MeDUSA Test Script:**
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
| **Tools** | Nikto, OWASP ZAP, curl, SecurityHeaders.com |

**Required Headers:**

| Header | Expected Value |
|--------|---------------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Content-Security-Policy` | Defined policy |

**Nikto Web Server Scan:**
```bash
# Install Nikto
apt install nikto

# Run scan against API
nikto -h https://<api-gateway-url> -ssl -Format htm -output nikto_report.html

# Scan with authentication
nikto -h https://<api-gateway-url> -ssl \
  -id "Authorization: Bearer <token>"
```

**OWASP ZAP Header Analysis:**
```bash
# Run ZAP in daemon mode
docker run -u zap -p 8080:8080 zaproxy/zap-stable zap.sh -daemon -port 8080

# Run baseline scan
docker run -t zaproxy/zap-stable zap-baseline.py \
  -t https://<api-gateway-url> -r zap_report.html

# Run full scan
docker run -t zaproxy/zap-stable zap-full-scan.py \
  -t https://<api-gateway-url> -r zap_full_report.html
```

**curl Header Check:**
```bash
curl -I -s https://<api-gateway-url>/api/v1/admin/health | grep -E "^(Strict|X-|Content-Security)"
```

---

#### ST-API-003: Network & Infrastructure Scanning

| Attribute | Value |
|-----------|-------|
| **Test ID** | ST-API-003 |
| **Priority** | High |
| **Tools** | Nmap, Nessus, Nuclei |

**Nmap Service Discovery:**
```bash
# Basic port scan
nmap -sV -sC -p- <api-gateway-host>

# Aggressive scan with OS detection
nmap -A -T4 <api-gateway-host>

# Vulnerability scripts
nmap --script vuln <api-gateway-host>

# HTTP enumeration
nmap --script http-enum,http-headers,http-methods \
  -p 443 <api-gateway-host>
```

**Nuclei Vulnerability Scanning:**
```bash
# Install Nuclei
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Update templates
nuclei -update-templates

# Run all templates
nuclei -u https://<api-gateway-url> -t ~/nuclei-templates/

# Run specific categories
nuclei -u https://<api-gateway-url> \
  -t ~/nuclei-templates/cves/ \
  -t ~/nuclei-templates/vulnerabilities/ \
  -t ~/nuclei-templates/exposed-panels/

# Run with severity filter
nuclei -u https://<api-gateway-url> -s critical,high,medium
```

**Nessus Professional Scan:**
1. Create new scan → "Web Application Tests"
2. Enter target: `https://<api-gateway-url>`
3. Configure credentials if needed
4. Enable all plugins → Launch scan
5. Review findings by severity

**Pass Criteria:**
- Only port 443 exposed
- No high/critical Nessus findings
- No CVEs detected by Nuclei

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

## Appendix A: Professional Penetration Testing Tools Reference

### A.1 Web Application Security

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **Burp Suite Pro** | HTTP proxy, scanner, intruder | [portswigger.net](https://portswigger.net/burp/pro) | [Documentation](https://portswigger.net/burp/documentation) |
| **OWASP ZAP** | Automated DAST scanner | `docker pull zaproxy/zap-stable` | [zaproxy.org](https://www.zaproxy.org/docs/) |
| **Nikto** | Web server scanner | `apt install nikto` | [GitHub](https://github.com/sullo/nikto) |
| **Nuclei** | Template-based scanner | `go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest` | [nuclei.sh](https://nuclei.projectdiscovery.io/) |
| **ffuf** | Web fuzzer | `go install github.com/ffuf/ffuf/v2@latest` | [GitHub](https://github.com/ffuf/ffuf) |
| **Gobuster** | Directory brute forcing | `go install github.com/OJ/gobuster/v3@latest` | [GitHub](https://github.com/OJ/gobuster) |

### A.2 Injection Testing

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **SQLMap** | SQL injection automation | `pip install sqlmap` | [sqlmap.org](https://sqlmap.org/) |
| **NoSQLMap** | NoSQL injection | `git clone https://github.com/codingo/NoSQLMap` | [GitHub](https://github.com/codingo/NoSQLMap) |
| **XSStrike** | XSS detection | `git clone https://github.com/s0md3v/XSStrike` | [GitHub](https://github.com/s0md3v/XSStrike) |
| **Commix** | Command injection | `git clone https://github.com/commixproject/commix` | [GitHub](https://github.com/commixproject/commix) |

### A.3 Authentication & Session Testing

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **JWT_Tool** | JWT exploitation | `pip install jwt_tool` | [GitHub](https://github.com/ticarpi/jwt_tool) |
| **Hydra** | Brute force testing | `apt install hydra` | [GitHub](https://github.com/vanhauser-thc/thc-hydra) |
| **John the Ripper** | Password cracking | `apt install john` | [openwall.com](https://www.openwall.com/john/) |
| **Hashcat** | GPU password cracking | [hashcat.net](https://hashcat.net/hashcat/) | [Documentation](https://hashcat.net/wiki/) |

### A.4 Network & Infrastructure

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **Nmap** | Port scanning | `apt install nmap` | [nmap.org](https://nmap.org/docs.html) |
| **Nessus** | Vulnerability scanner | [tenable.com](https://www.tenable.com/products/nessus) | [Documentation](https://docs.tenable.com/nessus/) |
| **Metasploit** | Exploitation framework | `curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && chmod 755 msfinstall && ./msfinstall` | [metasploit.com](https://docs.metasploit.com/) |
| **Wireshark** | Packet analysis | [wireshark.org](https://www.wireshark.org/) | [Documentation](https://www.wireshark.org/docs/) |

### A.5 TLS/SSL Testing

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **testssl.sh** | TLS configuration | `git clone https://github.com/drwetter/testssl.sh` | [testssl.sh](https://testssl.sh/) |
| **sslyze** | SSL/TLS scanner | `pip install sslyze` | [GitHub](https://github.com/nabla-c0d3/sslyze) |
| **sslscan** | SSL cipher enumeration | `apt install sslscan` | [GitHub](https://github.com/rbsec/sslscan) |

### A.6 Mobile Application Testing

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **MobSF** | Mobile security framework | `docker pull opensecurity/mobile-security-framework-mobsf` | [mobsf.github.io](https://mobsf.github.io/docs/) |
| **Frida** | Dynamic instrumentation | `pip install frida-tools` | [frida.re](https://frida.re/docs/home/) |
| **Objection** | Runtime mobile exploration | `pip install objection` | [GitHub](https://github.com/sensepost/objection) |

### A.7 Performance & Load Testing

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **k6** | Load testing | [k6.io](https://k6.io/docs/getting-started/installation/) | [Documentation](https://k6.io/docs/) |
| **Apache JMeter** | Load testing | [jmeter.apache.org](https://jmeter.apache.org/download_jmeter.cgi) | [User Manual](https://jmeter.apache.org/usermanual/index.html) |
| **Locust** | Python load testing | `pip install locust` | [locust.io](https://docs.locust.io/) |
| **Artillery** | Modern load testing | `npm install -g artillery` | [artillery.io](https://www.artillery.io/docs) |

### A.8 Unit & Integration Testing

| Tool | Purpose | Installation | Documentation |
|------|---------|--------------|---------------|
| **pytest** | Python unit testing | `pip install pytest pytest-cov` | [pytest.org](https://docs.pytest.org/) |
| **flutter test** | Dart/Flutter testing | Built-in | [flutter.dev](https://docs.flutter.dev/testing) |
| **Postman/Newman** | API testing | [postman.com](https://www.postman.com/downloads/) | [Documentation](https://learning.postman.com/docs/) |

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
