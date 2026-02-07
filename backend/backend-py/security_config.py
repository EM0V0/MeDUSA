"""
MeDUSA Security Configuration & Education Mode

This module provides a centralized security configuration system with
educational toggle switches. Each security feature can be enabled/disabled
to demonstrate the difference between secure and insecure implementations.

⚠️ WARNING: INSECURE MODE IS FOR EDUCATIONAL PURPOSES ONLY!
Never use insecure mode in production environments.

Security Features Covered:
1. Password Security (Argon2id hashing, complexity requirements)
2. Authentication (JWT tokens, expiration, MFA)
3. Authorization (RBAC, ownership checks)
4. Transport Security (TLS 1.3, certificate validation)
5. Replay Attack Prevention (Nonces, HMAC signatures)
6. Audit Logging (Event tracking, PII masking)
7. Input Validation (Pydantic schemas)
8. Rate Limiting (Request throttling)

FDA Cybersecurity Guidance Reference:
- Pre-market Submission Requirements (2025)
- IEC 62443 Industrial Security Standards
- OWASP Top 10 for Healthcare Applications
"""

import os
from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional
from enum import Enum
import json


class SecurityMode(Enum):
    """Security mode enumeration"""
    SECURE = "secure"
    INSECURE = "insecure"
    EDUCATIONAL = "educational"  # Secure with verbose logging


@dataclass
class SecurityFeature:
    """Represents a single security feature with educational context"""
    id: str
    name: str
    description: str
    enabled: bool
    category: str
    risk_if_disabled: str
    fda_requirement: str
    educational_explanation: str
    code_location: str
    cwe_reference: Optional[str] = None
    owasp_reference: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "enabled": self.enabled,
            "category": self.category,
            "riskIfDisabled": self.risk_if_disabled,
            "fdaRequirement": self.fda_requirement,
            "educationalExplanation": self.educational_explanation,
            "codeLocation": self.code_location,
            "cweReference": self.cwe_reference,
            "owaspReference": self.owasp_reference
        }


class SecurityConfig:
    """
    Centralized security configuration with educational mode support.
    
    In EDUCATIONAL mode, security features remain enabled but produce
    verbose console output explaining what each security check does.
    
    In INSECURE mode, selected security features are disabled to
    demonstrate vulnerabilities (FOR EDUCATIONAL USE ONLY).
    """
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        
        # Default mode from environment
        mode_env = os.environ.get("SECURITY_MODE", "secure").lower()
        self._mode = SecurityMode(mode_env) if mode_env in [m.value for m in SecurityMode] else SecurityMode.SECURE
        
        # Educational logging enabled by default in EDUCATIONAL mode
        self._educational_logging = os.environ.get("EDUCATIONAL_LOGGING", "true").lower() == "true"
        
        # Initialize all security features
        self._features: Dict[str, SecurityFeature] = {}
        self._init_features()
        
        # Print startup banner
        self._print_startup_banner()
    
    def _init_features(self):
        """Initialize all security features with educational context"""
        
        # ============== AUTHENTICATION FEATURES ==============
        
        self._features["password_hashing"] = SecurityFeature(
            id="password_hashing",
            name="Argon2id Password Hashing",
            description="Passwords are hashed using Argon2id, the winner of the Password Hashing Competition (PHC).",
            enabled=True,
            category="Authentication",
            risk_if_disabled="Passwords stored in plaintext can be immediately compromised if database is breached. "
                            "Weak hashing (MD5/SHA1) allows rainbow table attacks.",
            fda_requirement="FDA Pre-market Guidance 2025: Authentication mechanisms must use industry-standard cryptographic methods.",
            educational_explanation="""
🔐 ARGON2ID PASSWORD HASHING EXPLAINED:

WHY ARGON2ID?
- Memory-hard: Requires large amounts of RAM to compute, making GPU/ASIC attacks expensive
- Time-hard: Configurable iteration count increases computation time
- Resistant to: Rainbow tables, brute force, GPU attacks, ASIC attacks

ATTACK SCENARIOS PREVENTED:
1. Rainbow Table Attack: Precomputed hash tables are useless because Argon2id uses unique salt
2. GPU Parallel Attack: Memory requirements prevent efficient parallelization
3. ASIC Attack: Custom hardware can't efficiently compute memory-hard functions

PARAMETERS (backend/backend-py/auth.py):
- type: Argon2id (combination of Argon2i and Argon2d)
- memory_cost: 65536 KB (64 MB)
- time_cost: 3 iterations
- parallelism: 4 threads
- salt: Random 16 bytes per password

COMPARISON WITH OTHER ALGORITHMS:
| Algorithm | Rainbow Table | GPU Resistant | Memory-Hard |
|-----------|---------------|---------------|-------------|
| MD5       | ❌ Vulnerable | ❌ No         | ❌ No       |
| SHA-256   | ❌ Vulnerable | ❌ No         | ❌ No       |
| bcrypt    | ✅ Protected  | ⚠️ Partial    | ❌ No       |
| scrypt    | ✅ Protected  | ✅ Yes        | ✅ Yes      |
| Argon2id  | ✅ Protected  | ✅ Yes        | ✅ Yes      |
""",
            code_location="backend/backend-py/auth.py:hash_pw(), verify_pw()",
            cwe_reference="CWE-916: Use of Password Hash With Insufficient Computational Effort",
            owasp_reference="A02:2021 – Cryptographic Failures"
        )
        
        self._features["password_complexity"] = SecurityFeature(
            id="password_complexity",
            name="Password Complexity Requirements",
            description="Enforces minimum password length (8), uppercase, lowercase, digit, and special character.",
            enabled=True,
            category="Authentication",
            risk_if_disabled="Weak passwords are easily guessable through dictionary attacks or brute force.",
            fda_requirement="FDA Pre-market Guidance: Strong authentication including password policies.",
            educational_explanation="""
🔑 PASSWORD COMPLEXITY REQUIREMENTS EXPLAINED:

CURRENT POLICY (password_validator.py):
- Minimum Length: 8 characters
- Uppercase: At least 1 (A-Z)
- Lowercase: At least 1 (a-z)
- Digit: At least 1 (0-9)
- Special Character: At least 1 (!@#$%^&*()_+-=[]{}|;:,.<>?)

NIST SP 800-63B RECOMMENDATIONS:
- Minimum 8 characters (MeDUSA: ✅)
- Allow up to 64 characters
- Check against breached password databases
- No arbitrary complexity requirements that encourage predictable patterns

ATTACK TIME ESTIMATES (assuming 10 billion guesses/second):
| Password Style        | Entropy | Time to Crack |
|-----------------------|---------|---------------|
| 6 lowercase           | 28 bits | <1 second     |
| 8 lowercase           | 38 bits | ~4 minutes    |
| 8 mixed case          | 46 bits | ~2 hours      |
| 8 mixed + digit       | 48 bits | ~8 hours      |
| 8 mixed + digit + sym | 52 bits | ~5 days       |
| 12 mixed + digit + sym| 78 bits | ~10,000 years |

WHY THESE REQUIREMENTS?
- Balance between security and usability
- Prevents common password patterns
- Increases entropy without being too burdensome
""",
            code_location="backend/backend-py/password_validator.py:PasswordValidator.validate()",
            cwe_reference="CWE-521: Weak Password Requirements",
            owasp_reference="A07:2021 – Identification and Authentication Failures"
        )
        
        self._features["jwt_authentication"] = SecurityFeature(
            id="jwt_authentication",
            name="JWT Token Authentication",
            description="Stateless authentication using JSON Web Tokens with HS256 signature.",
            enabled=True,
            category="Authentication",
            risk_if_disabled="Without proper token authentication, attackers can impersonate any user.",
            fda_requirement="FDA Pre-market Guidance: Secure authentication for all user interactions.",
            educational_explanation="""
🎟️ JWT (JSON WEB TOKEN) AUTHENTICATION EXPLAINED:

TOKEN STRUCTURE:
┌─────────────────────────────────────────────────────────────┐
│ HEADER          │ PAYLOAD           │ SIGNATURE             │
│ {"alg":"HS256", │ {"sub":"usr_123", │ HMAC-SHA256(          │
│  "typ":"JWT"}   │  "role":"doctor", │   base64(header) +    │
│                 │  "exp":1234567890}│   base64(payload),    │
│                 │                   │   secret)             │
└─────────────────────────────────────────────────────────────┘

MeDUSA IMPLEMENTATION (auth.py):
- Algorithm: HS256 (HMAC with SHA-256)
- Access Token Expiry: 1 hour (configurable via JWT_EXPIRE_SECONDS)
- Refresh Token Expiry: 7 days (configurable via REFRESH_TTL_SECONDS)
- Claims: sub (user ID), role (user role), exp (expiration)

SECURITY MEASURES:
1. Server-side secret key (never exposed to client)
2. Short-lived access tokens (limit window of compromise)
3. Refresh token rotation (detect token theft)
4. Token blacklisting (not implemented - stateless design)

ATTACK SCENARIOS PREVENTED:
- Token Forgery: Invalid signature is rejected
- Token Tampering: Modified payload changes signature
- Session Fixation: Each login issues new tokens
- Token Reuse: Expiration prevents indefinite use

JWT VS SESSION-BASED AUTH:
| Feature           | JWT            | Session Cookie |
|-------------------|----------------|----------------|
| Stateless         | ✅ Yes         | ❌ No          |
| Scalable          | ✅ Yes         | ⚠️ Requires Redis |
| Mobile-friendly   | ✅ Yes         | ❌ Cookie issues |
| Revocable         | ⚠️ Needs work  | ✅ Yes         |
""",
            code_location="backend/backend-py/auth.py:issue_tokens(), verify_jwt()",
            cwe_reference="CWE-287: Improper Authentication",
            owasp_reference="A07:2021 – Identification and Authentication Failures"
        )
        
        self._features["mfa_totp"] = SecurityFeature(
            id="mfa_totp",
            name="Multi-Factor Authentication (TOTP)",
            description="Time-based One-Time Password provides a second factor using authenticator apps.",
            enabled=True,
            category="Authentication",
            risk_if_disabled="Single-factor auth is vulnerable to credential theft (phishing, keyloggers, breaches).",
            fda_requirement="FDA Pre-market Guidance: Multi-factor authentication SHOULD be employed where appropriate.",
            educational_explanation="""
📱 MFA WITH TOTP (TIME-BASED ONE-TIME PASSWORD) EXPLAINED:

HOW TOTP WORKS:
1. Server generates shared secret (base32 encoded, 160 bits)
2. User stores secret in authenticator app (Google Authenticator, Authy)
3. Both parties compute: TOTP = HOTP(secret, floor(time / 30))
4. 6-digit code changes every 30 seconds

ALGORITHM (RFC 6238):
┌─────────────────────────────────────────────────────────────┐
│ T = floor((current_unix_time - T0) / 30)                    │
│ HMAC = HMAC-SHA1(secret, T)                                 │
│ offset = HMAC[-1] & 0x0F                                    │
│ code = (HMAC[offset:offset+4] & 0x7FFFFFFF) % 10^6          │
└─────────────────────────────────────────────────────────────┘

MeDUSA IMPLEMENTATION (auth.py):
- Library: pyotp
- Algorithm: HMAC-SHA1 (RFC 6238 standard)
- Digits: 6
- Period: 30 seconds
- Valid Window: ±1 period (clock skew tolerance)

WHY MFA MATTERS:
┌──────────────────────────────────────────────────────────┐
│ FACTOR TYPES:                                            │
│ 1. Something you KNOW (password)      - can be stolen    │
│ 2. Something you HAVE (phone/token)   - can be lost      │
│ 3. Something you ARE (biometrics)     - can be copied    │
│                                                          │
│ Combining factors exponentially increases security:      │
│ - Single factor: 1 attack vector                         │
│ - Two factors: 2 independent attacks needed              │
└──────────────────────────────────────────────────────────┘

ATTACK SCENARIOS PREVENTED:
- Phishing: Even if password is stolen, attacker needs phone
- Credential Stuffing: Reused passwords from breaches are useless
- Keyloggers: TOTP code is only valid for 30-60 seconds
""",
            code_location="backend/backend-py/auth.py:generate_mfa_secret(), verify_mfa_code()",
            cwe_reference="CWE-308: Use of Single-factor Authentication",
            owasp_reference="A07:2021 – Identification and Authentication Failures"
        )
        
        # ============== AUTHORIZATION FEATURES ==============
        
        self._features["rbac"] = SecurityFeature(
            id="rbac",
            name="Role-Based Access Control (RBAC)",
            description="Access permissions are determined by user roles (patient, doctor, admin).",
            enabled=True,
            category="Authorization",
            risk_if_disabled="Users can access or modify data they shouldn't have access to.",
            fda_requirement="FDA Pre-market Guidance: Role-based access controls for device functions and data.",
            educational_explanation="""
👥 ROLE-BASED ACCESS CONTROL (RBAC) EXPLAINED:

MeDUSA ROLE HIERARCHY:
┌─────────────────────────────────────────────────────────────┐
│                         ADMIN                               │
│              ┌───────────┴───────────┐                      │
│           DOCTOR                   DOCTOR                   │
│       ┌─────┴─────┐           ┌─────┴─────┐                │
│   PATIENT    PATIENT      PATIENT    PATIENT               │
└─────────────────────────────────────────────────────────────┘

ROLE PERMISSIONS MATRIX:
| Resource          | Patient | Doctor | Admin |
|-------------------|---------|--------|-------|
| View own profile  | ✅      | ✅     | ✅    |
| View own data     | ✅      | ✅     | ✅    |
| View patient data | ❌      | ✅*    | ✅    |
| Manage patients   | ❌      | ✅*    | ✅    |
| Register devices  | ❌      | ✅     | ✅    |
| System settings   | ❌      | ❌     | ✅    |
| Audit logs        | ❌      | ❌     | ✅    |
| User management   | ❌      | ❌     | ✅    |

* Only for assigned patients

IMPLEMENTATION (rbac.py):
@require_role("doctor", "admin")
async def get_patients():
    # Only doctors and admins can access this endpoint
    ...

ATTACK SCENARIOS PREVENTED:
1. Horizontal Privilege Escalation: Patient A can't access Patient B's data
2. Vertical Privilege Escalation: Patient can't access doctor functions
3. Role Bypass: API validates role on every request

PRINCIPLE OF LEAST PRIVILEGE:
- Users receive minimum permissions needed
- Permissions are explicitly granted, not implied
- Default deny: if not explicitly allowed, access is denied
""",
            code_location="backend/backend-py/rbac.py:require_role(), get_user_role()",
            cwe_reference="CWE-285: Improper Authorization",
            owasp_reference="A01:2021 – Broken Access Control"
        )
        
        self._features["resource_ownership"] = SecurityFeature(
            id="resource_ownership",
            name="Resource Ownership Verification",
            description="Users can only access resources they own or are explicitly assigned to.",
            enabled=True,
            category="Authorization",
            risk_if_disabled="Insecure Direct Object Reference (IDOR) vulnerabilities allow data theft.",
            fda_requirement="FDA Pre-market Guidance: Access controls must verify user authorization for each resource.",
            educational_explanation="""
🔒 RESOURCE OWNERSHIP VERIFICATION EXPLAINED:

WHAT IS IDOR (Insecure Direct Object Reference)?
┌─────────────────────────────────────────────────────────────┐
│ VULNERABLE CODE:                                            │
│ GET /api/patient/12345  ← User can guess other IDs          │
│                                                             │
│ SECURE CODE:                                                │
│ GET /api/patient/12345                                      │
│   → Check: user.id == 12345 OR user.role == "doctor"        │
│   → Check: doctor is assigned to patient 12345              │
└─────────────────────────────────────────────────────────────┘

MeDUSA OWNERSHIP CHECKS (rbac.py):

1. Direct Ownership:
   check_resource_ownership(request, resource_owner_id)
   - User ID must match resource owner ID

2. Ownership OR Role:
   @require_ownership_or_role("doctor", "admin")
   - User owns resource, OR has elevated role

3. Assignment-based Access:
   - Doctors only see patients assigned to them
   - Patients only see their own data

EXAMPLE ATTACK PREVENTED:
┌──────────────────────────────────────────────────────────┐
│ ATTACKER (Patient ID: usr_111)                          │
│                                                         │
│ Attempt: GET /api/v1/patients/usr_222/tremor-data       │
│                                                         │
│ Without ownership check: ✅ Returns usr_222's data      │
│ With ownership check:    ❌ 403 Forbidden               │
└──────────────────────────────────────────────────────────┘

DEFENSE IN DEPTH:
1. Token validates user identity (who they are)
2. RBAC validates user role (what they can do)
3. Ownership validates resource access (what they can see)
""",
            code_location="backend/backend-py/rbac.py:check_resource_ownership(), require_ownership_or_role()",
            cwe_reference="CWE-639: Authorization Bypass Through User-Controlled Key",
            owasp_reference="A01:2021 – Broken Access Control"
        )
        
        # ============== TRANSPORT SECURITY ==============
        
        self._features["tls_enforcement"] = SecurityFeature(
            id="tls_enforcement",
            name="TLS 1.3 Enforcement",
            description="All communications are encrypted using TLS 1.3, the latest and most secure version.",
            enabled=True,
            category="Transport Security",
            risk_if_disabled="Network traffic can be intercepted (man-in-the-middle attack), exposing credentials and patient data.",
            fda_requirement="FDA Pre-market Guidance: Use current TLS standard (1.2 or higher recommended).",
            educational_explanation="""
🔐 TLS 1.3 TRANSPORT ENCRYPTION EXPLAINED:

TLS (TRANSPORT LAYER SECURITY) OVERVIEW:
┌─────────────────────────────────────────────────────────────┐
│ Application Layer   │  HTTP Request (encrypted payload)    │
├─────────────────────┼───────────────────────────────────────┤
│ TLS Layer           │  Encryption, Authentication, Integrity│
├─────────────────────┼───────────────────────────────────────┤
│ TCP Layer           │  Reliable packet delivery             │
├─────────────────────┼───────────────────────────────────────┤
│ IP Layer            │  Addressing and routing               │
└─────────────────────┴───────────────────────────────────────┘

TLS 1.3 IMPROVEMENTS OVER TLS 1.2:
| Feature                | TLS 1.2        | TLS 1.3        |
|------------------------|----------------|----------------|
| Handshake RTT          | 2 RTT          | 1 RTT (0-RTT)  |
| Cipher Suites          | Many (some weak)| 5 strong only  |
| Forward Secrecy        | Optional       | Mandatory      |
| Removed Algorithms     | N/A            | RSA key exchange, SHA-1, MD5, DES, 3DES |

MeDUSA TLS CONFIGURATION:
- Protocol: TLS 1.3 only (1.2 allowed for compatibility)
- Cipher Suite: TLS_AES_256_GCM_SHA384
- Certificate: AWS-managed (ACM)
- HSTS: Enabled (Strict-Transport-Security header)

ATTACK SCENARIOS PREVENTED:
1. Eavesdropping: All data encrypted in transit
2. Man-in-the-Middle: Certificate verification prevents interception
3. Downgrade Attack: TLS 1.0/1.1 rejected
4. Protocol Vulnerabilities: POODLE, BEAST, etc. not applicable

CERTIFICATE CHAIN:
┌─────────────────────────────────────────────────────────────┐
│ Root CA (Amazon Root CA 1)                                  │
│     └─ Intermediate CA (Amazon)                             │
│           └─ Server Certificate (*.execute-api.amazonaws.com)│
└─────────────────────────────────────────────────────────────┘
""",
            code_location="frontend/lib/shared/services/security_service.dart:verifyCertificatePinning()",
            cwe_reference="CWE-319: Cleartext Transmission of Sensitive Information",
            owasp_reference="A02:2021 – Cryptographic Failures"
        )
        
        # ============== REPLAY PROTECTION ==============
        
        self._features["replay_protection"] = SecurityFeature(
            id="replay_protection",
            name="Request Replay Protection",
            description="Cryptographic nonces prevent attackers from replaying captured requests.",
            enabled=True,
            category="Replay Protection",
            risk_if_disabled="Attackers can capture and replay requests to perform unauthorized actions.",
            fda_requirement="FDA Pre-market Guidance: Protect against unauthorized access including replay attacks.",
            educational_explanation="""
🔄 REQUEST REPLAY PROTECTION EXPLAINED:

WHAT IS A REPLAY ATTACK?
┌─────────────────────────────────────────────────────────────┐
│ 1. User sends: POST /transfer {"amount": 1000}              │
│ 2. Attacker captures the encrypted request                  │
│ 3. Attacker replays the exact same request                  │
│ 4. Without protection: Another $1000 transferred!           │
└─────────────────────────────────────────────────────────────┘

MeDUSA NONCE IMPLEMENTATION (replay_protection.py):

NONCE FORMAT:
timestamp.randomHex.signature
├── timestamp: Unix milliseconds
├── randomHex: 16 bytes of cryptographic randomness
└── signature: HMAC-SHA256 truncated to prevent tampering

VALIDATION STEPS:
1. Format Check: Correct structure (timestamp.random.signature)
2. Signature Verify: HMAC matches (tamper protection)
3. Timestamp Check: Within 5-minute window (freshness)
4. Uniqueness Check: Nonce not previously used (replay prevention)

NONCE LIFECYCLE:
┌──────────────────────────────────────────────────────────┐
│ CLIENT                         │ SERVER                  │
│                                │                         │
│ 1. GET /security/nonce ────────┼──▶ Generate nonce      │
│                                │    Store with TTL       │
│ ◀──────────────────────────────┼── Return nonce          │
│                                │                         │
│ 2. POST /api/action            │                         │
│    X-Request-Nonce: <nonce> ───┼──▶ Validate nonce       │
│                                │    Mark as used         │
│ ◀──────────────────────────────┼── Process request       │
│                                │                         │
│ 3. Replay same request ────────┼──▶ Nonce already used!  │
│ ◀──────────────────────────────┼── 400 Bad Request       │
└──────────────────────────────────────────────────────────┘

STORAGE:
- DynamoDB with TTL (automatic cleanup after 5 minutes)
- In-memory option for local development

ATTACK SCENARIOS PREVENTED:
1. Request Replay: Each nonce valid only once
2. Nonce Prediction: Cryptographic randomness unpredictable
3. Nonce Tampering: HMAC signature verification
4. Delayed Replay: Timestamp window limits attack window
""",
            code_location="backend/backend-py/replay_protection.py:NonceService",
            cwe_reference="CWE-294: Authentication Bypass by Capture-replay",
            owasp_reference="A07:2021 – Identification and Authentication Failures"
        )
        
        # ============== AUDIT & LOGGING ==============
        
        self._features["audit_logging"] = SecurityFeature(
            id="audit_logging",
            name="Security Audit Logging",
            description="Comprehensive logging of security events for compliance and forensics.",
            enabled=True,
            category="Audit & Logging",
            risk_if_disabled="Cannot detect security breaches, compliance violations, or perform forensic analysis.",
            fda_requirement="FDA Pre-market Guidance: Audit controls to record device activities for security monitoring.",
            educational_explanation="""
📋 SECURITY AUDIT LOGGING EXPLAINED:

WHY AUDIT LOGGING?
┌─────────────────────────────────────────────────────────────┐
│ 1. DETECTION: Identify security incidents in progress        │
│ 2. FORENSICS: Investigate breaches after they occur          │
│ 3. COMPLIANCE: FDA, HIPAA, ISO 27001 require audit trails    │
│ 4. ACCOUNTABILITY: Non-repudiation of user actions           │
└─────────────────────────────────────────────────────────────┘

MeDUSA AUDIT EVENT TYPES (audit_service.py):

AUTHENTICATION EVENTS:
- AUTH_LOGIN_SUCCESS / AUTH_LOGIN_FAILURE
- AUTH_MFA_CHALLENGE / AUTH_MFA_SUCCESS / AUTH_MFA_FAILURE
- AUTH_PASSWORD_CHANGE / AUTH_PASSWORD_RESET

AUTHORIZATION EVENTS:
- AUTHZ_ACCESS_GRANTED / AUTHZ_ACCESS_DENIED
- AUTHZ_ROLE_ESCALATION_ATTEMPT

DATA ACCESS EVENTS:
- DATA_READ / DATA_CREATE / DATA_UPDATE / DATA_DELETE
- PATIENT_DATA_ACCESS

SECURITY EVENTS:
- SECURITY_RATE_LIMIT_EXCEEDED
- SECURITY_INVALID_TOKEN
- SECURITY_SUSPICIOUS_ACTIVITY

AUDIT LOG STRUCTURE:
{
  "timestamp": "2026-02-06T12:00:00.000Z",
  "eventType": "AUTH_LOGIN_SUCCESS",
  "userId": "usr_123",
  "userRole": "doctor",
  "resourceType": "session",
  "action": "create",
  "sourceIp": "192.168.1.100",
  "userAgent": "MeDUSA-Flutter/1.0",
  "details": {...},
  "hash": "abc123..."  // Tamper-evident chain
}

PII PROTECTION:
┌──────────────────────────────────────────────────────────┐
│ BEFORE LOGGING:                                          │
│ {"email": "john.doe@example.com", "password": "secret"}  │
│                                                          │
│ AFTER MASKING:                                           │
│ {"email": "joh***e.com", "password": "***REDACTED***"}   │
└──────────────────────────────────────────────────────────┘

TAMPER-EVIDENT HASHING:
- Each log entry includes hash of previous entry
- Chain of hashes detects log tampering
""",
            code_location="backend/backend-py/audit_service.py:AuditService",
            cwe_reference="CWE-778: Insufficient Logging",
            owasp_reference="A09:2021 – Security Logging and Monitoring Failures"
        )
        
        # ============== INPUT VALIDATION ==============
        
        self._features["input_validation"] = SecurityFeature(
            id="input_validation",
            name="Input Validation (Pydantic)",
            description="All API inputs are validated using Pydantic schemas before processing.",
            enabled=True,
            category="Input Validation",
            risk_if_disabled="Injection attacks (SQL, NoSQL, command), buffer overflows, XSS.",
            fda_requirement="FDA Pre-market Guidance: Input validation to prevent unauthorized commands or data manipulation.",
            educational_explanation="""
✅ INPUT VALIDATION EXPLAINED:

WHY INPUT VALIDATION?
┌─────────────────────────────────────────────────────────────┐
│ "Never trust user input" - Fundamental security principle   │
│                                                             │
│ ALL external data is potentially malicious:                 │
│ - Form fields                                               │
│ - URL parameters                                            │
│ - HTTP headers                                              │
│ - File uploads                                              │
│ - API request bodies                                        │
└─────────────────────────────────────────────────────────────┘

MeDUSA PYDANTIC VALIDATION (models.py):

class LoginReq(BaseModel):
    email: EmailStr           # Validated email format
    password: str             # Required string
    mfaCode: Optional[str]    # Optional 6-digit code
    
    @validator('password')
    def password_not_empty(cls, v):
        if not v or len(v) < 1:
            raise ValueError('Password required')
        return v

VALIDATION TYPES:
| Type           | Example                    | Prevents              |
|----------------|----------------------------|-----------------------|
| Type checking  | int, str, bool             | Type confusion        |
| Format         | EmailStr, HttpUrl          | Malformed data        |
| Length limits  | max_length=100             | Buffer overflow, DoS  |
| Range          | ge=0, le=100               | Logic errors          |
| Regex          | regex=r'^[a-zA-Z]+$'       | Injection attacks     |
| Enum           | Literal["a", "b"]          | Invalid options       |

ATTACK SCENARIOS PREVENTED:
1. SQL Injection: Validated data types prevent query manipulation
2. NoSQL Injection: DynamoDB uses parameterized queries
3. XSS: Output encoding (handled by frontend)
4. Command Injection: No shell commands with user input
5. Buffer Overflow: Length limits on all strings

DEFENSE IN DEPTH:
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Client-side validation (UX only, not security)     │
│ Layer 2: API Gateway validation (schema)                    │
│ Layer 3: Pydantic validation (type, format, constraints)    │
│ Layer 4: Business logic validation (domain rules)           │
│ Layer 5: Database constraints (unique, foreign keys)        │
└─────────────────────────────────────────────────────────────┘
""",
            code_location="backend/backend-py/models.py",
            cwe_reference="CWE-20: Improper Input Validation",
            owasp_reference="A03:2021 – Injection"
        )
        
        # ============== SECURE STORAGE ==============
        
        self._features["secure_storage"] = SecurityFeature(
            id="secure_storage",
            name="Secure Credential Storage",
            description="Credentials stored using platform-specific secure storage (Keychain/Keystore).",
            enabled=True,
            category="Secure Storage",
            risk_if_disabled="Credentials stored in plaintext can be stolen by malware or physical access.",
            fda_requirement="FDA Pre-market Guidance: Protect stored credentials and sensitive data.",
            educational_explanation="""
🔒 SECURE CREDENTIAL STORAGE EXPLAINED:

PLATFORM-SPECIFIC IMPLEMENTATIONS:

iOS (Keychain):
┌─────────────────────────────────────────────────────────────┐
│ - Hardware-backed encryption (Secure Enclave on A7+)        │
│ - Access controlled by app entitlement                      │
│ - Survives app reinstall (configurable)                     │
│ - Biometric protection available                            │
│ - Encryption: AES-256-GCM                                   │
└─────────────────────────────────────────────────────────────┘

Android (Keystore):
┌─────────────────────────────────────────────────────────────┐
│ - Hardware-backed on devices with TEE/StrongBox             │
│ - Keys never leave secure hardware                          │
│ - EncryptedSharedPreferences for data                       │
│ - Biometric binding available                               │
│ - Encryption: AES-256-GCM                                   │
└─────────────────────────────────────────────────────────────┘

MeDUSA IMPLEMENTATION (security_service.dart):

FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,  // AES encryption
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
)

WHAT WE STORE SECURELY:
- JWT access tokens
- JWT refresh tokens
- MFA secrets
- Device fingerprint
- Encryption salt

WHAT WE DON'T STORE (security measures):
- Passwords (only sent to server, never stored locally)
- Unencrypted PII
- Session data in SharedPreferences

COMPARISON:
| Storage Method        | Encrypted | Hardware-Backed | Secure |
|-----------------------|-----------|-----------------|--------|
| SharedPreferences     | ❌        | ❌              | ❌     |
| SQLite                | ❌        | ❌              | ❌     |
| EncryptedSharedPrefs  | ✅        | ⚠️ Varies       | ✅     |
| Keychain/Keystore     | ✅        | ✅              | ✅     |
""",
            code_location="frontend/lib/shared/services/security_service.dart:_secureStorage",
            cwe_reference="CWE-312: Cleartext Storage of Sensitive Information",
            owasp_reference="A02:2021 – Cryptographic Failures"
        )
        
        # ============== RATE LIMITING ==============
        
        self._features["rate_limiting"] = SecurityFeature(
            id="rate_limiting",
            name="API Rate Limiting",
            description="Limits request frequency to prevent abuse and denial of service.",
            enabled=True,
            category="Rate Limiting",
            risk_if_disabled="Brute force attacks, denial of service, resource exhaustion.",
            fda_requirement="FDA Pre-market Guidance: Protect against denial of service conditions.",
            educational_explanation="""
⏱️ API RATE LIMITING EXPLAINED:

PURPOSE:
┌─────────────────────────────────────────────────────────────┐
│ 1. Prevent Brute Force: Limit login attempts                │
│ 2. Prevent DoS: Limit total requests per user/IP            │
│ 3. Fair Usage: Ensure resources available for all users     │
│ 4. Cost Control: Prevent runaway Lambda/DynamoDB costs      │
└─────────────────────────────────────────────────────────────┘

MeDUSA RATE LIMITS:

| Endpoint              | Limit           | Window  |
|-----------------------|-----------------|---------|
| /auth/login           | 5 requests      | 1 min   |
| /auth/register        | 3 requests      | 1 min   |
| /auth/reset-password  | 3 requests      | 5 min   |
| /api/* (general)      | 100 requests    | 1 min   |
| /api/v1/sensor-data   | 60 requests     | 1 min   |

IMPLEMENTATION LEVELS:

1. AWS API Gateway (First Line):
   - Throttling: 10,000 requests/second (burst)
   - Quota: Configurable per API key
   
2. Application Level (Backend):
   - Per-user rate limiting
   - Per-IP rate limiting for anonymous endpoints
   
3. DynamoDB (Automatic):
   - On-demand capacity handles spikes
   - Throttles at account limits

BRUTE FORCE PROTECTION:
┌──────────────────────────────────────────────────────────┐
│ LOGIN ATTEMPTS:                                          │
│ Attempt 1: ✅ Allowed                                    │
│ Attempt 2: ✅ Allowed                                    │
│ Attempt 3: ✅ Allowed                                    │
│ Attempt 4: ✅ Allowed                                    │
│ Attempt 5: ✅ Allowed (last chance)                      │
│ Attempt 6: ❌ 429 Too Many Requests (wait 60s)           │
│                                                          │
│ 8-char password with 5 attempts/min:                     │
│ Time to brute force: ~1.4 billion years                  │
└──────────────────────────────────────────────────────────┘

RESPONSE HEADERS:
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 3
X-RateLimit-Reset: 1707235260
Retry-After: 45
""",
            code_location="backend/template.yaml (API Gateway), main.py (application)",
            cwe_reference="CWE-307: Improper Restriction of Excessive Authentication Attempts",
            owasp_reference="A04:2021 – Insecure Design"
        )
    
    def _print_startup_banner(self):
        """Print security configuration banner at startup"""
        enabled_count = sum(1 for f in self._features.values() if f.enabled)
        total_count = len(self._features)
        
        banner = f"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MeDUSA SECURITY CONFIGURATION                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Mode: {self._mode.value.upper():12}                                                      ║
║  Security Features: {enabled_count}/{total_count} enabled                                            ║
║  Educational Logging: {'ON' if self._educational_logging else 'OFF':3}                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
"""
        
        if self._mode == SecurityMode.INSECURE:
            banner += """║  ⚠️  WARNING: INSECURE MODE - FOR EDUCATIONAL USE ONLY!                      ║
║  ⚠️  Some security features are DISABLED for demonstration.                  ║
"""
        elif self._mode == SecurityMode.EDUCATIONAL:
            banner += """║  📚 EDUCATIONAL MODE: Security enabled with verbose logging                  ║
║  📚 All security checks will output detailed explanations.                   ║
"""
        else:
            banner += """║  ✅ SECURE MODE: All security features are enabled.                          ║
║  ✅ Suitable for production deployment.                                      ║
"""
        
        banner += """╚══════════════════════════════════════════════════════════════════════════════╝
"""
        print(banner)
        
        if self._educational_logging:
            print("\n📋 SECURITY FEATURES STATUS:")
            for category in ["Authentication", "Authorization", "Transport Security", 
                           "Replay Protection", "Audit & Logging", "Input Validation",
                           "Secure Storage", "Rate Limiting"]:
                print(f"\n  [{category}]")
                for f in self._features.values():
                    if f.category == category:
                        status = "✅" if f.enabled else "❌"
                        print(f"    {status} {f.name}")
    
    @property
    def mode(self) -> SecurityMode:
        return self._mode
    
    @mode.setter
    def mode(self, new_mode: SecurityMode):
        """Allow runtime mode switching for educational purposes"""
        old_mode = self._mode
        self._mode = new_mode
        if self._educational_logging or new_mode == SecurityMode.EDUCATIONAL:
            print(f"\n🔄 SECURITY MODE CHANGED: {old_mode.value.upper()} → {new_mode.value.upper()}")
            if new_mode == SecurityMode.INSECURE:
                print("   ⚠️  WARNING: Insecure mode - security features can be disabled!")
            elif new_mode == SecurityMode.SECURE:
                print("   ✅ Secure mode - all features enforced, cannot be disabled")
                # Re-enable all features when switching to secure mode
                for feature in self._features.values():
                    feature.enabled = True
    
    @property
    def educational_logging(self) -> bool:
        return self._educational_logging
    
    @educational_logging.setter
    def educational_logging(self, enabled: bool):
        """Toggle educational logging at runtime"""
        self._educational_logging = enabled
        print(f"\n📚 Educational Logging: {'ENABLED' if enabled else 'DISABLED'}")
    
    def is_feature_enabled(self, feature_id: str) -> bool:
        """Check if a security feature is enabled"""
        feature = self._features.get(feature_id)
        return feature.enabled if feature else True
    
    def get_feature(self, feature_id: str) -> Optional[SecurityFeature]:
        """Get a security feature by ID"""
        return self._features.get(feature_id)
    
    def get_all_features(self) -> List[SecurityFeature]:
        """Get all security features"""
        return list(self._features.values())
    
    def get_features_by_category(self, category: str) -> List[SecurityFeature]:
        """Get all features in a category"""
        return [f for f in self._features.values() if f.category == category]
    
    def toggle_feature(self, feature_id: str, enabled: bool) -> bool:
        """Toggle a security feature (for educational mode)"""
        if self._mode == SecurityMode.SECURE:
            print(f"⚠️  Cannot toggle features in SECURE mode. Set SECURITY_MODE=insecure or SECURITY_MODE=educational")
            return False
        
        feature = self._features.get(feature_id)
        if feature:
            feature.enabled = enabled
            if self._educational_logging:
                status = "ENABLED ✅" if enabled else "DISABLED ❌"
                print(f"\n🔧 Security Feature Toggled: {feature.name} → {status}")
                if not enabled:
                    print(f"   ⚠️  RISK: {feature.risk_if_disabled}")
            return True
        return False
    
    def log_security_check(self, feature_id: str, passed: bool, details: str = ""):
        """Log a security check with educational output"""
        if not self._educational_logging:
            return
        
        feature = self._features.get(feature_id)
        if not feature:
            return
        
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"\n{'='*70}")
        print(f"🔐 SECURITY CHECK: {feature.name}")
        print(f"   Status: {status}")
        if details:
            print(f"   Details: {details}")
        if not passed:
            print(f"   Risk: {feature.risk_if_disabled}")
        print(f"   Code: {feature.code_location}")
        print(f"{'='*70}")
    
    def get_config_json(self) -> Dict[str, Any]:
        """Get full configuration as JSON (for API endpoint)"""
        return {
            "mode": self._mode.value,
            "educationalLogging": self._educational_logging,
            "features": [f.to_dict() for f in self._features.values()],
            "categories": list(set(f.category for f in self._features.values()))
        }


# Singleton instance
security_config = SecurityConfig()
