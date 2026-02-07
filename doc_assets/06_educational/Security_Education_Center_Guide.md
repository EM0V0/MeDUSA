# Security Education Center Guide

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: Zhicheng Sun

---

## Overview

The MeDUSA Security Education Center is an interactive learning platform designed to help developers, students, and medical device security professionals understand cybersecurity concepts through hands-on demonstrations.

This feature directly supports the FDA's guidance on cybersecurity education and demonstrates the STRIDE threat model mitigations in practice.

---

## Table of Contents

1. [Accessing the Security Education Center](#accessing-the-security-education-center)
2. [Security Modes](#security-modes)
3. [Security Features](#security-features)
4. [Interactive Demonstrations](#interactive-demonstrations)
5. [Learning Modules](#learning-modules)
6. [API Reference](#api-reference)
7. [Configuration](#configuration)

---

## Accessing the Security Education Center

### Frontend Access

1. Login as an **Admin** user
2. Navigate to **Security Lab** in the navigation menu
3. Or directly access: `/security-education`

### API Access

All security education endpoints are available at `/api/v1/security/*`:

```bash
# Get security configuration
curl -X GET "https://api.medusa.example/api/v1/security/config" \
  -H "Authorization: Bearer <your-token>"

# Get specific feature details
curl -X GET "https://api.medusa.example/api/v1/security/features/password_hashing" \
  -H "Authorization: Bearer <your-token>"
```

---

## Security Modes

MeDUSA supports three security modes. **Modes can be switched at RUNTIME without restarting the server!**

### SECURE Mode (Default)

- All 12 security features are enabled and **cannot be toggled off**
- No educational logging overhead
- **Suitable for production deployment**

### EDUCATIONAL Mode (Recommended for Learning)

- All security features are enabled
- Verbose console logging explains each security check
- Features can be toggled on/off for demonstration
- **Ideal for learning and development**

### INSECURE Mode

- Security features can be disabled to demonstrate vulnerabilities
- **⚠️ FOR EDUCATIONAL USE ONLY - NEVER USE IN PRODUCTION**

### 🔄 Runtime Mode Switching (No Restart Needed!)

Switch modes instantly via API:

```bash
# Switch to EDUCATIONAL mode
curl -X POST "http://localhost:8080/api/v1/security/mode?mode=educational"

# Switch to INSECURE mode (for vulnerability demos)
curl -X POST "http://localhost:8080/api/v1/security/mode?mode=insecure"

# Switch back to SECURE mode
curl -X POST "http://localhost:8080/api/v1/security/mode?mode=secure"

# Toggle educational logging
curl -X POST "http://localhost:8080/api/v1/security/logging?enabled=true"
```

Or use the **Frontend UI**: Navigate to Security Lab → click mode buttons (SECURE / EDUCATIONAL / INSECURE)

---

## Security Features

The platform implements 12 security features across 6 categories:

### 1. Authentication (4 features)

| Feature | Description | Code Location |
|---------|-------------|---------------|
| **Password Hashing** | Argon2id with 64MB memory cost | `backend/backend-py/auth.py` |
| **Password Complexity** | 8+ chars, mixed case, digit, special | `backend/backend-py/password_validator.py` |
| **JWT Authentication** | HS256 signed tokens, 1-hour expiry | `backend/backend-py/auth.py` |
| **MFA (TOTP)** | Time-based one-time passwords | `backend/backend-py/auth.py` |

### 2. Authorization (2 features)

| Feature | Description | Code Location |
|---------|-------------|---------------|
| **RBAC** | Role-based access (admin, doctor, patient) | `backend/backend-py/rbac.py` |
| **Resource Ownership** | IDOR prevention via ownership checks | `backend/backend-py/rbac.py` |

### 3. Transport Security (1 feature)

| Feature | Description | Code Location |
|---------|-------------|---------------|
| **TLS Enforcement** | TLS 1.3 with certificate pinning | `frontend/lib/shared/services/secure_network_service.dart` |

### 4. Replay Protection (1 feature)

| Feature | Description | Code Location |
|---------|-------------|---------------|
| **Nonce Validation** | Cryptographic nonces with HMAC | `backend/backend-py/replay_protection.py` |

### 5. Audit & Logging (1 feature)

| Feature | Description | Code Location |
|---------|-------------|---------------|
| **Audit Logging** | PII-masked event logging | `backend/backend-py/audit_service.py` |

### 6. Input & Storage (3 features)

| Feature | Description | Code Location |
|---------|-------------|---------------|
| **Input Validation** | Pydantic schema validation | `backend/backend-py/models.py` |
| **Secure Storage** | Keychain/Keystore for credentials | `frontend/lib/shared/services/security_service.dart` |
| **Rate Limiting** | API throttling (5 login/min) | `backend/template.yaml` (API Gateway) |

---

## Interactive Demonstrations

### Password Hashing Demo

Shows real-time comparison of different hashing algorithms:

```
GET /api/v1/security/demo/password-hashing

Response:
{
  "testPassword": "MeDUSA_Demo_2026!",
  "algorithms": {
    "md5": {
      "hash": "a1b2c3...",
      "timeMs": 0.1,
      "secure": false,
      "vulnerability": "Rainbow tables, collision attacks"
    },
    "sha256": {
      "hash": "d4e5f6...",
      "timeMs": 0.2,
      "secure": false,
      "vulnerability": "Fast computation enables brute force"
    },
    "argon2id": {
      "hash": "$argon2id$v=19$m=65536...",
      "timeMs": 98.5,
      "secure": true,
      "explanation": "Memory-hard, GPU-resistant"
    }
  }
}
```

### JWT Token Demo

Breaks down a JWT token structure:

```
GET /api/v1/security/demo/jwt-token

Response:
{
  "header": {"alg": "HS256", "typ": "JWT"},
  "payload": {"sub": "demo_user", "role": "doctor", "exp": 1707235260},
  "signature": "HMAC-SHA256(base64(header) + . + base64(payload), secret)",
  "explanation": "Stateless authentication with cryptographic signature"
}
```

### RBAC Demo

Shows role permissions matrix:

```
GET /api/v1/security/demo/rbac

Response:
{
  "roles": ["patient", "doctor", "admin"],
  "permissions": {
    "patient": ["view_own_data", "send_messages"],
    "doctor": ["view_own_data", "view_patient_data", "create_reports"],
    "admin": ["*"]
  }
}
```

### Replay Protection Demo

Demonstrates nonce generation and validation:

```
GET /api/v1/security/demo/replay-protection

Response:
{
  "nonce": "1707235260000.abc123def456.hmac1234",
  "components": {
    "timestamp": 1707235260000,
    "random": "abc123def456",
    "signature": "hmac1234"
  },
  "explanation": "Each nonce valid once, expires in 5 minutes"
}
```

---

## Learning Modules

The Security Education Center includes structured learning content:

### Module 1: FDA Cybersecurity Requirements

- Premarket submission requirements
- TPLC (Total Product Life Cycle) approach
- SBOM documentation

### Module 2: STRIDE Threat Model

- Spoofing → Authentication
- Tampering → Integrity checks
- Repudiation → Audit logging
- Information Disclosure → Encryption
- Denial of Service → Rate limiting
- Elevation of Privilege → RBAC

### Module 3: Authentication Deep Dive

- Password hashing evolution
- JWT vs session-based auth
- MFA implementation

### Module 4: Cryptography Fundamentals

- Symmetric vs asymmetric encryption
- TLS handshake process
- Certificate validation

### Module 5: Compliance Standards

- IEC 62443
- NIST Cybersecurity Framework
- OWASP Top 10 for Healthcare

---

## API Reference

### Runtime Control Endpoints (No Restart Needed!)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/security/mode?mode={mode}` | **Switch security mode instantly** (secure/educational/insecure) |
| POST | `/api/v1/security/logging?enabled={bool}` | **Toggle educational logging** |
| GET | `/api/v1/security/live-status` | Get real-time security status with score |

### Configuration Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/security/config` | Get full security configuration |
| GET | `/api/v1/security/features` | List all features by category |
| GET | `/api/v1/security/features/{id}` | Get specific feature details |
| POST | `/api/v1/security/features/{id}/toggle` | Toggle feature (educational/insecure mode only) |

### Demo Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/security/demo/password-hashing` | Password hashing comparison |
| GET | `/api/v1/security/demo/jwt-token` | JWT structure breakdown |
| GET | `/api/v1/security/demo/rbac` | Role permissions matrix |
| GET | `/api/v1/security/demo/replay-protection` | Nonce demonstration |

---

## Configuration

### Environment Variables

```bash
# Security mode selection
SECURITY_MODE=secure|insecure|educational

# Educational logging (verbose console output)
EDUCATIONAL_LOGGING=true|false

# JWT configuration
JWT_SECRET=your-256-bit-secret
JWT_EXPIRE_SECONDS=3600

# Replay protection
NONCE_TTL_SECONDS=300
HMAC_SECRET=your-hmac-secret
```

### Startup Banner

In EDUCATIONAL mode, the backend displays a startup banner:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MeDUSA SECURITY CONFIGURATION                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Mode: EDUCATIONAL                                                           ║
║  Security Features: 12/12 enabled                                            ║
║  Educational Logging: ON                                                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  📚 EDUCATIONAL MODE: Security enabled with verbose logging                  ║
║  📚 All security checks will output detailed explanations.                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Security_Implementation_Summary.md](../02_security/Security_Implementation_Summary.md) | Comprehensive security controls |
| [Threat_Model.md](../01_premarket/Threat_Model.md) | STRIDE threat analysis |
| [Testing_Guide.md](../04_testing/Testing_Guide.md) | Security testing procedures |
| [Cybersecurity_Risk_Assessment_Worksheet.md](Cybersecurity_Risk_Assessment_Worksheet.md) | Student exercises |

---

## Educational Use Cases

### Classroom Scenario 1: Password Security

1. Set `SECURITY_MODE=insecure`
2. Disable password hashing feature
3. Observe plaintext password storage
4. Demonstrate brute force attack
5. Enable feature and compare

### Classroom Scenario 2: IDOR Attack

1. Login as Patient A
2. Attempt to access Patient B's data via ID manipulation
3. Observe 403 Forbidden (resource ownership check)
4. Discuss OWASP A01 Broken Access Control

### Classroom Scenario 3: Replay Attack

1. Capture a valid API request with nonce
2. Replay the exact same request
3. Observe "Nonce already used" error
4. Discuss replay attack prevention

---

**Document Control:**
- Document ID: MeDUSA-DOC-SEC-EDU-001
- Classification: Educational
- Review Cycle: Bi-annually
