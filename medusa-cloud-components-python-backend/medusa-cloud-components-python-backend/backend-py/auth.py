import os, time, bcrypt, jwt
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from typing import Dict, Any

JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret")
JWT_EXPIRE_SECONDS = int(os.environ.get("JWT_EXPIRE_SECONDS", "3600"))
REFRESH_TTL_SECONDS = int(os.environ.get("REFRESH_TTL_SECONDS", str(7*24*3600)))

def hash_pw(pw: str) -> str:
    return bcrypt.hashpw(pw.encode(), bcrypt.gensalt()).decode()

def verify_pw(pw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(pw.encode(), hashed.encode())
    except Exception:
        return False

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

OPEN_PATH_SUFFIXES = ["/admin/health", "/auth/login", "/auth/register", "/auth/refresh", "/auth/logout"]

async def auth_middleware(request: Request, call_next):
    path = request.url.path
    if any(path.endswith(suf) for suf in OPEN_PATH_SUFFIXES):
        return await call_next(request)
    bearer = request.headers.get("Authorization", "")
    if not bearer.startswith("Bearer "):
        return JSONResponse(status_code=401, content={"code":"AUTH_REQUIRED","message":"missing bearer token"})
    claims = verify_jwt(bearer.removeprefix("Bearer ").strip())
    request.state.claims = claims
    return await call_next(request)
