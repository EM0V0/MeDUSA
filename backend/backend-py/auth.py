import os, time, jwt, pyotp
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from typing import Dict, Any

JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret")
JWT_EXPIRE_SECONDS = int(os.environ.get("JWT_EXPIRE_SECONDS", "3600"))
REFRESH_TTL_SECONDS = int(os.environ.get("REFRESH_TTL_SECONDS", str(7*24*3600)))
MFA_TEMP_TOKEN_SECONDS = 300  # 5 minutes for MFA challenge

# Initialize Argon2id hasher
ph = PasswordHasher()

def hash_pw(pw: str) -> str:
    return ph.hash(pw)

def verify_pw(pw: str, hashed: str) -> bool:
    try:
        return ph.verify(hashed, pw)
    except (VerifyMismatchError, Exception):
        return False

# ========== MFA (TOTP) Functions ==========

def generate_mfa_secret() -> str:
    """Generate a new TOTP secret for MFA setup."""
    return pyotp.random_base32()

def verify_mfa_code(secret: str, code: str) -> bool:
    """Verify a TOTP code against the user's MFA secret."""
    if not secret or not code:
        return False
    totp = pyotp.TOTP(secret)
    return totp.verify(code, valid_window=1)  # Allow 1 period tolerance

def get_mfa_provisioning_uri(email: str, secret: str) -> str:
    """Get the provisioning URI for QR code generation."""
    return pyotp.TOTP(secret).provisioning_uri(name=email, issuer_name="MeDUSA")

def issue_temp_token(sub: str, role: str) -> str:
    """
    Issue a short-lived temporary token for MFA challenge.
    This token can only be used to complete MFA verification.
    """
    now = int(time.time())
    return jwt.encode(
        {"sub": sub, "role": role, "exp": now + MFA_TEMP_TOKEN_SECONDS, "scope": "mfa_pending"},
        JWT_SECRET, algorithm="HS256"
    )

def verify_temp_token(token: str) -> Dict[str, Any]:
    """Verify a temporary MFA token and check scope."""
    try:
        claims = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        if claims.get("scope") != "mfa_pending":
            raise HTTPException(status_code=401, detail={"code": "AUTH_INVALID", "message": "invalid token scope"})
        return claims
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail={"code": "AUTH_EXPIRED", "message": "MFA token expired"})
    except Exception:
        raise HTTPException(status_code=401, detail={"code": "AUTH_INVALID", "message": "invalid MFA token"})

# ========== Token Functions ==========

def issue_tokens(sub: str, role: str) -> Dict[str, Any]:
    """
    Issue access and refresh tokens
    Returns dict with camelCase keys to match API v3 Documentation
    """
    now = int(time.time())
    access = jwt.encode(
        {"sub": sub, "role": role, "exp": now + JWT_EXPIRE_SECONDS},
        JWT_SECRET, algorithm="HS256"
    )
    refresh = jwt.encode(
        {"sub": sub, "role": role, "exp": now + REFRESH_TTL_SECONDS, "typ": "refresh"},
        JWT_SECRET, algorithm="HS256"
    )
    # API v3 uses camelCase: accessJwt, refreshToken, expiresIn
    return {
        "accessJwt": access,
        "refreshToken": refresh,
        "expiresIn": JWT_EXPIRE_SECONDS
    }

def verify_jwt(token: str) -> Dict[str, Any]:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail={"code":"AUTH_EXPIRED","message":"token expired"})
    except Exception:
        raise HTTPException(status_code=401, detail={"code":"AUTH_INVALID","message":"invalid token"})

OPEN_PATH_SUFFIXES = [
    "/admin/health", 
    "/auth/login", 
    "/auth/mfa/login",  # MFA login endpoint
    "/auth/register", 
    "/auth/refresh", 
    "/auth/logout", 
    "/auth/reset-password",
    "/auth/request-verification",  # Request verification code
    "/auth/send-verification-code",  # Legacy - keep for compatibility
    "/auth/send-password-reset-code",  # Legacy
    "/current-session",  # Allow Pi devices to poll for current session
    "/security/nonce"    # Nonce endpoint for replay protection
]

async def auth_middleware(request: Request, call_next):
    # Allow all OPTIONS requests for CORS preflight
    if request.method == "OPTIONS":
        return await call_next(request)
    
    path = request.url.path
    if any(path.endswith(suf) for suf in OPEN_PATH_SUFFIXES):
        return await call_next(request)
    bearer = request.headers.get("Authorization", "")
    if not bearer.startswith("Bearer "):
        return JSONResponse(status_code=401, content={"code":"AUTH_REQUIRED","message":"missing bearer token"})
    claims = verify_jwt(bearer.removeprefix("Bearer ").strip())
    request.state.claims = claims
    return await call_next(request)
