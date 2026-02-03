import os, sys, uuid, time, secrets
from datetime import datetime, timezone
from typing import Optional

# Set UTF-8 encoding for Lambda environment
os.environ['PYTHONIOENCODING'] = 'utf-8'

# Allow Lambda bundle to include dependencies under ./python (same layout as Layers)
_here = os.path.dirname(__file__)
_vendored = os.path.join(_here, "python")
if os.path.isdir(_vendored) and _vendored not in sys.path:
    sys.path.insert(0, _vendored)

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from mangum import Mangum
from pydantic import BaseModel

from models import (
    LoginReq, LoginRes, RegisterReq, RegisterRes, 
    RefreshReq, RefreshRes, ResetPasswordReq, SendVerificationCodeReq,
    RequestVerificationReq,
    UserOut, PoseCreateReq, PresignReq, PresignRes,
    Pose, PosePage, Report, ReportPage,
    DeviceRegisterReq, DeviceUpdateReq, Device, DevicePage, DeviceBindReq,
    PatientProfileCreateReq, PatientProfileUpdateReq, PatientProfile, PatientWithProfile, PatientPage,
    SessionCreateReq, SessionUpdateReq, Session, SessionWithDetails, SessionPage,
    TremorResponse, AssignPatientReq, DoctorPatientsRes
)
from auth import (
    auth_middleware, issue_tokens, verify_pw, hash_pw,
    generate_mfa_secret, verify_mfa_code, get_mfa_provisioning_uri,
    issue_temp_token, verify_temp_token
)
from password_validator import PasswordValidator
from email_service import EmailService
from rbac import require_role, get_user_id, get_user_role
from audit_service import audit_service, AuditEventType
from replay_protection import nonce_service, require_nonce, get_nonce_endpoint
import db
import storage

app = FastAPI(title="MeDUSA Python API (Single Lambda)")

# Initialize email service
email_service = EmailService()

# CORS - properly configured for web clients
# Strict CORS: Allow specific origins from environment variable, default to * for dev
allowed_origins = os.environ.get("ALLOWED_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=[
        "Content-Type", 
        "Authorization", 
        "Accept",
        "Origin",
        "X-Requested-With",
        "Access-Control-Request-Method",
        "Access-Control-Request-Headers",
        "X-Request-Nonce",
        "X-Request-Timestamp",
        "X-Request-Signature"
    ],
    allow_credentials=True, # Allow cookies/auth headers
    max_age=600  # Cache preflight for 10 minutes
)

@app.middleware("http")
async def _auth_mw(request: Request, call_next):
    return await auth_middleware(request, call_next)

# -------- CORS Preflight Handler
@app.options("/{path:path}")
async def options_handler(path: str):
    """Handle CORS preflight requests explicitly"""
    return {"ok": True}

# -------- Admin
@app.get("/api/v1/admin/health")
def health():
    return {"ok": True, "ts": int(time.time()), "security": {"replayProtection": True, "nonceEnabled": True}}

@app.post("/api/v1/admin/test-email")
def test_email(email: str):
    """
    Test email sending endpoint (for debugging)
    Sends a test email to the specified address.
    """
    test_code = "123456"
    result = email_service.send_verification_code(
        email=email,
        code=test_code,
        code_type="registration"
    )
    return {
        "success": result,
        "email": email,
        "code": test_code,
        "use_ses": email_service.use_ses,
        "has_ses_client": email_service.ses_client is not None
    }

# -------- Security - Nonce Endpoint
@app.get("/api/v1/security/nonce")
def get_nonce():
    """
    Get a fresh nonce for replay protection.
    
    Clients should include this nonce in the X-Request-Nonce header
    for endpoints that require replay protection.
    """
    return get_nonce_endpoint()

# -------- Auth

@app.post("/api/v1/auth/request-verification", status_code=200)
def request_verification(req: RequestVerificationReq):
    """
    Request a verification code to be sent to the email.
    
    For registration: checks that email is not already registered.
    For password_reset: checks that email exists.
    
    The backend generates the code and sends it via email.
    """
    email = req.email.lower().strip()
    code_type = req.type.lower()
    
    if code_type == "registration":
        # Check if email is already registered
        existing = db.get_user_by_email(email)
        if existing:
            raise HTTPException(409, detail={"code": "EMAIL_TAKEN", "message": "Email is already registered"})
    elif code_type == "password_reset":
        # Check if email exists for password reset
        existing = db.get_user_by_email(email)
        if not existing:
            # Don't reveal if email exists - just return success
            # But log internally for security monitoring
            audit_service.log_event(
                event_type=AuditEventType.AUTH_PASSWORD_RESET,
                details={"email": email, "status": "email_not_found"}
            )
            return {"success": True, "message": "If the email exists, a verification code has been sent"}
    else:
        raise HTTPException(400, detail={"code": "INVALID_TYPE", "message": "Type must be 'registration' or 'password_reset'"})
    
    # Check for rate limiting (don't send too many codes within 60 seconds)
    # Allow new request if previous code expired or is older than 60 seconds
    if db.has_pending_verification(email, code_type, min_age_seconds=60):
        raise HTTPException(429, detail={"code": "TOO_MANY_REQUESTS", "message": "Please wait 60 seconds before requesting another code"})
    
    # Generate and store verification code
    code = db.generate_verification_code()
    if not db.save_verification_code(email, code, code_type):
        raise HTTPException(500, detail={"code": "INTERNAL_ERROR", "message": "Failed to generate verification code"})
    
    # Send email with verification code
    email_sent = email_service.send_verification_code(
        email=email,
        code=code,
        code_type=code_type
    )
    
    if not email_sent:
        raise HTTPException(500, detail={"code": "EMAIL_FAILED", "message": "Failed to send verification email"})
    
    # Log verification code request
    audit_service.log_event(
        event_type=AuditEventType.DATA_CREATE,
        details={"action": "verification_code_sent", "email": email, "type": code_type}
    )
    
    return {"success": True, "message": "Verification code sent to email", "expiresIn": 600}


@app.post("/api/v1/auth/register", response_model=RegisterRes, status_code=201)
def register(req: RegisterReq):
    """
    Register new user - requires email verification code.
    
    Flow:
    1. Call /auth/request-verification first to receive code via email
    2. Submit registration with the verification code
    """
    email = req.email.lower().strip()
    
    # Verify the email verification code
    if not db.verify_and_consume_code(email, req.verificationCode, "registration"):
        raise HTTPException(400, detail={"code": "INVALID_CODE", "message": "Invalid or expired verification code"})
    
    # Double-check email is not taken (race condition protection)
    existing = db.get_user_by_email(email)
    if existing:
        raise HTTPException(409, detail={"code": "EMAIL_TAKEN", "message": "Email is already registered"})
    
    # Validate password strength
    is_valid, error_msg = PasswordValidator.validate(req.password)
    if not is_valid:
        raise HTTPException(400, detail={"code": "INVALID_PASSWORD", "message": error_msg})
    
    uid = f"usr_{uuid.uuid4().hex[:8]}"
    
    # API v3: role is required in request, default to patient if not provided
    role = req.role.lower() if req.role else "patient"
    
    # Generate MFA secret at registration time (mandatory for medical system)
    mfa_secret = generate_mfa_secret()
    
    user = {
        "id": uid,
        "email": email,
        "role": role,
        "name": email.split('@')[0],  # Generate name from email
        "password": hash_pw(req.password),
        "emailVerified": True,  # Email is verified through the code
        "mfaSecret": mfa_secret,  # MFA is enabled from the start
        "mfaEnabled": True,
        "createdAt": datetime.now(timezone.utc).isoformat()
    }
    db.put_user(user)
    
    # Send welcome email with MFA secret
    try:
        email_service.send_welcome_with_mfa(email, mfa_secret, role)
        print(f"[Register] Welcome email with MFA sent to {email}")
    except Exception as e:
        print(f"[Register] Warning: Failed to send welcome email: {e}")
        # Don't fail registration if email fails - user can still use the MFA secret from response
    
    # Generate tokens
    tokens = issue_tokens(uid, user["role"])
    db.save_refresh(
        tokens["refreshToken"],  # API v3 uses camelCase
        {
            "userId": uid, 
            "role": user["role"], 
            "expiresAt": int(time.time()) + int(os.environ.get("REFRESH_TTL_SECONDS", "604800"))
        }
    )
    
    # Log successful registration with MFA enabled
    audit_service.log_event(
        event_type=AuditEventType.DATA_CREATE,
        user_id=uid,
        details={"action": "user_registered", "email": email, "role": role, "mfa_enabled": True}
    )
    
    # API v3: Return flat response with userId, accessJwt, refreshToken, and mfaSecret
    return RegisterRes(
        userId=uid,
        accessJwt=tokens["accessJwt"],
        refreshToken=tokens["refreshToken"],
        mfaSecret=mfa_secret  # Include MFA secret in response for immediate setup
    )

@app.post("/api/v1/auth/login")
def login(req: LoginReq, request: Request):
    """
    Login user - API v3 compliant
    
    If MFA is enabled, returns mfaRequired=true with tempToken.
    Otherwise, returns flat response with accessJwt, refreshToken, expiresIn, and user info.
    """
    # Extract client info for audit logging
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    u = db.get_user_by_email(req.email)
    if not u or not verify_pw(req.password, u["password"]):
        # Log failed login attempt
        audit_service.log_login_failure(
            email=req.email,
            reason="invalid_credentials",
            ip_address=client_ip,
            user_agent=user_agent
        )
        raise HTTPException(401, detail={"code":"AUTH_INVALID","message":"invalid credentials"})
    
    # Check if MFA is enabled for this user
    if u.get("mfaEnabled") and u.get("mfaSecret"):
        # Generate temporary token for MFA challenge
        temp_token = issue_temp_token(u["id"], u["role"])
        
        # Log MFA challenge issued
        audit_service.log_event(
            event_type=AuditEventType.MFA_CHALLENGE,
            user_id=u["id"],
            details={"ip_address": client_ip}
        )
        
        return {
            "mfaRequired": True,
            "tempToken": temp_token,
            "message": "MFA verification required"
        }
    
    # No MFA - generate tokens directly
    tokens = issue_tokens(u["id"], u["role"])
    db.save_refresh(
        tokens["refreshToken"],  # API v3 uses camelCase
        {
            "userId": u["id"], 
            "role": u["role"], 
            "expiresAt": int(time.time()) + int(os.environ.get("REFRESH_TTL_SECONDS","604800"))
        }
    )
    
    # Log successful login
    audit_service.log_login_success(
        user_id=u["id"],
        user_role=u["role"],
        ip_address=client_ip,
        user_agent=user_agent
    )
    
    # API v3: Return flat response with accessJwt, refreshToken, expiresIn, and user info
    return LoginRes(
        accessJwt=tokens["accessJwt"],
        refreshToken=tokens["refreshToken"],
        expiresIn=tokens["expiresIn"],
        user={
            "id": u["id"],
            "email": u["email"],
            "role": u["role"],
            "name": u.get("name", u["email"].split("@")[0])
        }
    )


# ========== MFA Endpoints ==========

class MfaLoginReq(BaseModel):
    tempToken: str
    code: str

class MfaSetupRes(BaseModel):
    secret: str
    provisioningUri: str
    message: str

class MfaVerifyReq(BaseModel):
    code: str

@app.post("/api/v1/auth/mfa/login", response_model=LoginRes)
def mfa_login(req: MfaLoginReq, request: Request):
    """
    Complete MFA login with TOTP code.
    
    Requires tempToken from initial login and the 6-digit code from authenticator app.
    """
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    # Verify temp token
    claims = verify_temp_token(req.tempToken)
    user_id = claims["sub"]
    
    # Get user and verify MFA code
    u = db.get_user(user_id)
    if not u:
        raise HTTPException(401, detail={"code": "AUTH_INVALID", "message": "user not found"})
    
    mfa_secret = u.get("mfaSecret")
    if not mfa_secret:
        raise HTTPException(400, detail={"code": "MFA_NOT_ENABLED", "message": "MFA not enabled for this user"})
    
    if not verify_mfa_code(mfa_secret, req.code):
        # Log failed MFA attempt
        audit_service.log_event(
            event_type=AuditEventType.MFA_FAILURE,
            user_id=user_id,
            details={"ip_address": client_ip, "reason": "invalid_code"}
        )
        raise HTTPException(401, detail={"code": "MFA_INVALID", "message": "invalid MFA code"})
    
    # MFA verified - issue full tokens
    tokens = issue_tokens(u["id"], u["role"])
    db.save_refresh(
        tokens["refreshToken"],
        {
            "userId": u["id"], 
            "role": u["role"], 
            "expiresAt": int(time.time()) + int(os.environ.get("REFRESH_TTL_SECONDS","604800"))
        }
    )
    
    # Log successful MFA login
    audit_service.log_event(
        event_type=AuditEventType.MFA_SUCCESS,
        user_id=u["id"],
        details={"ip_address": client_ip}
    )
    audit_service.log_login_success(
        user_id=u["id"],
        user_role=u["role"],
        ip_address=client_ip,
        user_agent=user_agent
    )
    
    return LoginRes(
        accessJwt=tokens["accessJwt"],
        refreshToken=tokens["refreshToken"],
        expiresIn=tokens["expiresIn"],
        user={
            "id": u["id"],
            "email": u["email"],
            "role": u["role"],
            "name": u.get("name", u["email"].split("@")[0])
        }
    )


@app.post("/api/v1/auth/mfa/setup", response_model=MfaSetupRes)
def mfa_setup(request: Request):
    """
    Initialize MFA setup for the current user.
    
    Returns a secret and provisioning URI for QR code generation.
    User must verify with a code before MFA is fully enabled.
    """
    user_id = get_user_id(request)
    u = db.get_user(user_id)
    if not u:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND", "message": "user not found"})
    
    # Check if MFA is already enabled
    if u.get("mfaEnabled"):
        raise HTTPException(400, detail={"code": "MFA_ALREADY_ENABLED", "message": "MFA is already enabled"})
    
    # Generate new MFA secret
    secret = generate_mfa_secret()
    
    # Store pending secret (not enabled yet)
    db.update_user(user_id, {"mfaPendingSecret": secret})
    
    # Generate provisioning URI for QR code
    provisioning_uri = get_mfa_provisioning_uri(u["email"], secret)
    
    # Log MFA setup initiated
    audit_service.log_event(
        event_type=AuditEventType.MFA_SETUP_INITIATED,
        user_id=user_id,
        details={}
    )
    
    return MfaSetupRes(
        secret=secret,
        provisioningUri=provisioning_uri,
        message="Scan QR code with authenticator app, then verify with a code"
    )


@app.post("/api/v1/auth/mfa/verify")
def mfa_verify(req: MfaVerifyReq, request: Request):
    """
    Verify and enable MFA for the current user.
    
    Requires the 6-digit code from authenticator app to confirm setup.
    """
    user_id = get_user_id(request)
    u = db.get_user(user_id)
    if not u:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND", "message": "user not found"})
    
    pending_secret = u.get("mfaPendingSecret")
    if not pending_secret:
        raise HTTPException(400, detail={"code": "MFA_NOT_SETUP", "message": "MFA setup not initiated"})
    
    # Verify the code
    if not verify_mfa_code(pending_secret, req.code):
        raise HTTPException(400, detail={"code": "MFA_INVALID", "message": "invalid MFA code"})
    
    # Enable MFA - move pending secret to active secret
    db.update_user(user_id, {
        "mfaSecret": pending_secret,
        "mfaEnabled": True,
        "mfaPendingSecret": None  # Clear pending
    })
    
    # Log MFA enabled
    audit_service.log_event(
        event_type=AuditEventType.MFA_ENABLED,
        user_id=user_id,
        details={}
    )
    
    return {"success": True, "message": "MFA enabled successfully"}


@app.delete("/api/v1/auth/mfa")
def mfa_disable(request: Request):
    """
    Disable MFA for the current user.
    
    Requires authentication. For security, consider requiring password re-entry.
    """
    user_id = get_user_id(request)
    u = db.get_user(user_id)
    if not u:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND", "message": "user not found"})
    
    if not u.get("mfaEnabled"):
        raise HTTPException(400, detail={"code": "MFA_NOT_ENABLED", "message": "MFA is not enabled"})
    
    # Disable MFA
    db.update_user(user_id, {
        "mfaSecret": None,
        "mfaEnabled": False,
        "mfaPendingSecret": None
    })
    
    # Log MFA disabled
    audit_service.log_event(
        event_type=AuditEventType.MFA_DISABLED,
        user_id=user_id,
        details={}
    )
    
    return {"success": True, "message": "MFA disabled successfully"}


@app.get("/api/v1/auth/mfa/status")
def mfa_status(request: Request):
    """
    Get MFA status for the current user.
    """
    user_id = get_user_id(request)
    u = db.get_user(user_id)
    if not u:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND", "message": "user not found"})
    
    return {
        "mfaEnabled": u.get("mfaEnabled", False),
        "hasPendingSetup": bool(u.get("mfaPendingSecret"))
    }

@app.post("/api/v1/auth/refresh", response_model=RefreshRes)
def refresh(req: RefreshReq):
    """
    Refresh access token - API v3 compliant
    Returns flat response with accessJwt and refreshToken
    """
    # API v3 uses camelCase for refreshToken in request
    refresh_token = req.refreshToken
    sess = db.take_refresh(refresh_token)
    if not sess or sess.get("expiresAt",0) < int(time.time()):
        raise HTTPException(401, detail={"code":"AUTH_INVALID","message":"refresh token invalid"})
    
    # Generate new tokens
    tokens = issue_tokens(sess["userId"], sess["role"])
    db.save_refresh(
        tokens["refreshToken"],  # API v3 uses camelCase
        {
            "userId": sess["userId"], 
            "role": sess["role"], 
            "expiresAt": int(time.time()) + int(os.environ.get("REFRESH_TTL_SECONDS","604800"))
        }
    )
    
    # API v3: Return flat response with accessJwt and refreshToken
    return RefreshRes(
        accessJwt=tokens["accessJwt"],
        refreshToken=tokens["refreshToken"]
    )

@app.post("/api/v1/auth/logout", status_code=200)
def logout(req: RefreshReq):
    """
    Logout user - API v3 compliant (204/200)
    Revokes refresh token
    """
    # API v3 uses camelCase
    _ = db.take_refresh(req.refreshToken)
    # API v3 doc shows 204, but returning 200 with success message
    return {"success": True, "message": "Successfully logged out"}

@app.post("/api/v1/auth/reset-password", status_code=200)
def reset_password(req: ResetPasswordReq):
    """
    Reset user password - requires verification code.
    
    Flow:
    1. Call /auth/request-verification with type="password_reset"
    2. Receive code via email
    3. Submit new password with the verification code
    """
    email = req.email.lower().strip()
    
    # Verify the password reset code
    if not db.verify_and_consume_code(email, req.verificationCode, "password_reset"):
        raise HTTPException(400, detail={"code": "INVALID_CODE", "message": "Invalid or expired verification code"})
    
    # Find user by email
    user = db.get_user_by_email(email)
    if not user:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND", "message": "Account not found"})
    
    # Validate password strength (enhanced validation)
    is_valid, error_msg = PasswordValidator.validate(req.newPassword)
    if not is_valid:
        raise HTTPException(400, detail={"code": "INVALID_PASSWORD", "message": error_msg})
    
    # Update password
    user["password"] = hash_pw(req.newPassword)
    db.put_user(user)
    
    # Log password reset
    audit_service.log_event(
        event_type=AuditEventType.AUTH_PASSWORD_RESET,
        user_id=user["id"],
        details={"email": email, "status": "success"}
    )
    
    return {"success": True, "message": "Password reset successful"}

@app.post("/api/v1/auth/send-verification-code", status_code=200)
def send_verification_code(req: SendVerificationCodeReq):
    """
    Send verification code via email
    Supports both registration and password reset flows
    """
    try:
        # Send email with verification code
        success = email_service.send_verification_code(
            email=req.email,
            code=req.code,
            code_type=req.type
        )
        
        if success:
            return {"success": True, "message": "Verification code sent successfully"}
        else:
            raise HTTPException(500, detail={"code":"EMAIL_SEND_FAILED","message":"Failed to send verification code"})
    except Exception as e:
        raise HTTPException(500, detail={"code":"EMAIL_SEND_FAILED","message":str(e)})

@app.post("/api/v1/auth/send-password-reset-code", status_code=200)
def send_password_reset_code(req: SendVerificationCodeReq):
    """
    Send password reset code via email
    Alias for send_verification_code with type=password_reset
    """
    try:
        # Send email with password reset code
        success = email_service.send_verification_code(
            email=req.email,
            code=req.code,
            code_type="password_reset"
        )
        
        if success:
            return {"success": True, "message": "Password reset code sent successfully"}
        else:
            raise HTTPException(500, detail={"code":"EMAIL_SEND_FAILED","message":"Failed to send password reset code"})
    except Exception as e:
        raise HTTPException(500, detail={"code":"EMAIL_SEND_FAILED","message":str(e)})

# -------- Me
@app.get("/api/v1/me", response_model=UserOut)
def me(request: Request):
    claims = getattr(request.state, "claims", None) or {}
    uid = claims.get("sub")
    u = db.get_user(uid)
    if not u:
        raise HTTPException(404, detail={"code":"USER_NOT_FOUND","message":"user not found"})
    return UserOut(
        id=u["id"], email=u["email"], role=u["role"],
        name=u.get("name"), createdAt=datetime.fromisoformat(u["createdAt"])
    )

# -------- Files (S3)
@app.post("/api/v1/files/presign", response_model=PresignRes)
def files_presign(req: PresignReq, request: Request):
    if req.scope not in ("pose","report"):
        raise HTTPException(400, detail={"code":"SCOPE_INVALID","message":"scope must be pose or report"})
    claims = getattr(request.state, "claims", {})
    owner = req.patientId or claims.get("sub")
    key = storage.make_file_key(req.scope, owner, req.filename)
    post = storage.presign_upload(key, req.contentType, ttl_sec=900)
    # Return a simple shape (compatible with your FE): uploadUrl + key
    return PresignRes(uploadUrl=post["url"], fileKey=key, expiresIn=900)

@app.get("/api/v1/files/{fileKey:path}")
def files_get(fileKey: str):
    url = storage.presign_download(fileKey, ttl_sec=300)
    return RedirectResponse(url)

# -------- Poses
@app.get("/api/v1/poses", response_model=PosePage)
@require_role("admin", "doctor", "patient")
async def poses_list(patientId: str, request: Request, nextToken: Optional[str] = None):
    try:
        # RBAC: Check ownership
        user_id = get_user_id(request)
        user_role = get_user_role(request)
        
        if user_role == "patient" and patientId != user_id:
             raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied: You can only view your own poses"})
        
        if user_role == "doctor":
             # Check if patient belongs to doctor
             profile = db.get_patient_profile(patientId)
             if profile and profile.get("doctorId") != user_id:
                 raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied: Patient not assigned to you"})

        items, nt = db.list_poses_by_patient(patientId, next_token=nextToken)
        # Create Pose models properly without duplicating createdAt
        poses = [
            Pose(
                id=i["id"],
                patientId=i["patientId"],
                fileKey=i["fileKey"],
                createdAt=datetime.fromisoformat(i["createdAt"])
            ) for i in items
        ]
        return PosePage(items=poses, nextToken=nt["id"] if isinstance(nt, dict) and "id" in nt else None)
    except Exception as e:
        import traceback
        print(f"[ERROR] poses_list failed: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(500, detail={"code":"POSE_LIST_FAILED","message":str(e)})

@app.post("/api/v1/poses", response_model=PosePage)
@require_role("admin", "doctor", "patient")
async def poses_create(body: PoseCreateReq, request: Request):
    """
    Create pose data - API v3 compliant
    Returns list with single created pose
    """
    try:
        claims = getattr(request.state, "claims", {})
        user_id = claims.get("sub")
        user_role = claims.get("role")
        
        pid = body.patientId or user_id
        
        # RBAC: Patient can only create poses for themselves
        if user_role == "patient" and pid != user_id:
             raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied: You can only create poses for yourself"})
             
        created_time = datetime.now(timezone.utc)
        rec = {
            "id": f"pose_{uuid.uuid4().hex[:8]}",
            "patientId": pid,
            "fileKey": body.fileKey,
            "createdAt": created_time.isoformat()
        }
        db.create_pose(rec)
        # Create Pose model with datetime object (not string)
        pose = Pose(
            id=rec["id"],
            patientId=rec["patientId"],
            fileKey=rec["fileKey"],
            createdAt=created_time
        )
        return PosePage(items=[pose], nextToken=None)
    except Exception as e:
        import traceback
        print(f"[ERROR] poses_create failed: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(500, detail={"code":"POSE_CREATE_FAILED","message":str(e)})

@app.get("/api/v1/poses/{poseId}", response_model=Pose)
def pose_get(poseId: str):
    # TODO: Implement get-by-id according to your DDB schema
    raise HTTPException(501, detail={"code":"NOT_IMPLEMENTED","message":"pose_get to be implemented"})

@app.get("/api/v1/patients/{userId}/poses", response_model=PosePage)
@require_role("admin", "doctor", "patient")
async def patient_pose_list(userId: str, request: Request):
    # RBAC: Check ownership
    current_user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    if user_role == "patient" and userId != current_user_id:
            raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
            
    if user_role == "doctor":
            profile = db.get_patient_profile(userId)
            if profile and profile.get("doctorId") != current_user_id:
                raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})

    items, _ = db.list_poses_by_patient(userId)
    # Create Pose models properly
    poses = [
        Pose(
            id=i["id"],
            patientId=i["patientId"],
            fileKey=i["fileKey"],
            createdAt=datetime.fromisoformat(i["createdAt"])
        ) for i in items
    ]
    return PosePage(items=poses, nextToken=None)

# -------- Devices
@app.post("/api/v1/devices", response_model=Device, status_code=201)
@require_role("admin", "doctor")
async def register_device(body: DeviceRegisterReq, request: Request):
    """
    Register a new device (Admin, Doctor only)
    Device is added to the shared pool (not bound to any patient)
    Use sessions to bind devices to patients dynamically
    """
    user_id = get_user_id(request)
    
    # Check if device already exists (by MAC address)
    existing = db.get_device_by_mac(body.macAddress)
    if existing:
        raise HTTPException(
            409, 
            detail={"code": "DEVICE_EXISTS", "message": "Device with this MAC address already registered"}
        )
    
    # Create device (no patient binding)
    device_id = f"dev_{uuid.uuid4().hex[:8]}"
    now = datetime.now(timezone.utc)
    
    device_data = {
        "id": device_id,
        "macAddress": body.macAddress,
        "name": body.name,
        "type": body.type,
        "patientId": None,  # No patient binding - shared pool
        "currentSessionId": None,  # No active session
        "status": "offline",
        "batteryLevel": 100,
        "firmwareVersion": body.firmwareVersion,
        "lastSeen": now.isoformat(),
        "createdAt": now.isoformat(),
        "updatedAt": now.isoformat()
    }
    
    db.create_device(device_data)
    
    return Device(
        id=device_data["id"],
        macAddress=device_data["macAddress"],
        name=device_data["name"],
        type=device_data["type"],
        patientId=device_data.get("patientId"),
        currentSessionId=device_data.get("currentSessionId"),
        status=device_data["status"],
        batteryLevel=device_data["batteryLevel"],
        firmwareVersion=device_data["firmwareVersion"],
        lastSeen=now,
        createdAt=now,
        updatedAt=now
    )

@app.get("/api/v1/devices/my", response_model=DevicePage)
@require_role("patient")
async def get_my_devices(request: Request):
    """
    Get my devices (Patient only)
    Returns all devices bound to the current patient
    """
    user_id = get_user_id(request)
    devices_data = db.get_devices_by_patient(user_id)
    
    devices = [
        Device(
            id=d["id"],
            macAddress=d["macAddress"],
            name=d["name"],
            type=d["type"],
            patientId=d.get("patientId"),
            currentSessionId=d.get("currentSessionId"),
            status=d["status"],
            batteryLevel=d["batteryLevel"],
            firmwareVersion=d["firmwareVersion"],
            lastSeen=datetime.fromisoformat(d["lastSeen"]),
            createdAt=datetime.fromisoformat(d["createdAt"]),
            updatedAt=datetime.fromisoformat(d["updatedAt"])
        ) for d in devices_data
    ]
    
    return DevicePage(items=devices, nextToken=None)

@app.get("/api/v1/devices", response_model=DevicePage)
@require_role("doctor", "admin")
async def get_all_devices_endpoint(request: Request):
    """
    Get all devices (Doctor, Admin only)
    """
    devices_data = db.get_all_devices()
    
    devices = [
        Device(
            id=d["id"],
            macAddress=d["macAddress"],
            name=d["name"],
            type=d["type"],
            patientId=d.get("patientId"),
            currentSessionId=d.get("currentSessionId"),
            status=d["status"],
            batteryLevel=d["batteryLevel"],
            firmwareVersion=d["firmwareVersion"],
            lastSeen=datetime.fromisoformat(d["lastSeen"]),
            createdAt=datetime.fromisoformat(d["createdAt"]),
            updatedAt=datetime.fromisoformat(d["updatedAt"])
        ) for d in devices_data
    ]
    
    return DevicePage(items=devices, nextToken=None)

@app.get("/api/v1/devices/{device_id}", response_model=Device)
@require_role("patient", "doctor", "admin")
async def get_device_endpoint(device_id: str, request: Request):
    """
    Get device by ID
    - Patient: Can only view their own devices
    - Doctor/Admin: Can view all devices
    """
    user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    device_data = db.get_device(device_id)
    if not device_data:
        raise HTTPException(404, detail={"code": "DEVICE_NOT_FOUND", "message": "Device not found"})
    
    # RBAC: Patient can only view their own devices
    if user_role == "patient" and device_data.get("patientId") != user_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    return Device(
        id=device_data["id"],
        macAddress=device_data["macAddress"],
        name=device_data["name"],
        type=device_data["type"],
        patientId=device_data.get("patientId"),
        currentSessionId=device_data.get("currentSessionId"),
        status=device_data["status"],
        batteryLevel=device_data["batteryLevel"],
        firmwareVersion=device_data["firmwareVersion"],
        lastSeen=datetime.fromisoformat(device_data["lastSeen"]),
        createdAt=datetime.fromisoformat(device_data["createdAt"]),
        updatedAt=datetime.fromisoformat(device_data["updatedAt"])
    )

@app.put("/api/v1/devices/{device_id}", response_model=Device)
@require_role("patient")
async def update_device_endpoint(device_id: str, body: DeviceUpdateReq, request: Request):
    """
    Update device (Patient only)
    Can only update own devices
    """
    user_id = get_user_id(request)
    
    device_data = db.get_device(device_id)
    if not device_data:
        raise HTTPException(404, detail={"code": "DEVICE_NOT_FOUND", "message": "Device not found"})
    
    # RBAC: Patient can only update their own devices
    if device_data.get("patientId") != user_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    # Build updates
    updates = {"updatedAt": datetime.now(timezone.utc).isoformat()}
    if body.name is not None:
        updates["name"] = body.name
    if body.batteryLevel is not None:
        updates["batteryLevel"] = body.batteryLevel
    if body.status is not None:
        updates["status"] = body.status
    if body.firmwareVersion is not None:
        updates["firmwareVersion"] = body.firmwareVersion
    
    # Update last seen time
    updates["lastSeen"] = datetime.now(timezone.utc).isoformat()
    
    db.update_device(device_id, updates)
    
    # Get updated device
    updated_device = db.get_device(device_id)
    
    return Device(
        id=updated_device["id"],
        macAddress=updated_device["macAddress"],
        name=updated_device["name"],
        type=updated_device["type"],
        patientId=updated_device.get("patientId"),
        currentSessionId=updated_device.get("currentSessionId"),
        status=updated_device["status"],
        batteryLevel=updated_device["batteryLevel"],
        firmwareVersion=updated_device["firmwareVersion"],
        lastSeen=datetime.fromisoformat(updated_device["lastSeen"]),
        createdAt=datetime.fromisoformat(updated_device["createdAt"]),
        updatedAt=datetime.fromisoformat(updated_device["updatedAt"])
    )

@app.delete("/api/v1/devices/{device_id}", status_code=200)
@require_role("patient", "admin")
async def delete_device_endpoint(device_id: str, request: Request):
    """
    Delete device (Patient can delete own devices, Admin can delete any)
    """
    user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    device_data = db.get_device(device_id)
    if not device_data:
        raise HTTPException(404, detail={"code": "DEVICE_NOT_FOUND", "message": "Device not found"})
    
    # RBAC: Patient can only delete their own devices
    if user_role == "patient" and device_data.get("patientId") != user_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    db.delete_device(device_id)
    
    return {"success": True, "message": "Device deleted successfully"}

@app.get("/api/v1/patients/{patient_id}/devices", response_model=DevicePage)
@require_role("doctor", "admin")
async def get_patient_devices(patient_id: str, request: Request):
    """
    Get devices for a specific patient (Doctor, Admin only)
    """
    devices_data = db.get_devices_by_patient(patient_id)
    
    devices = [
        Device(
            id=d["id"],
            macAddress=d["macAddress"],
            name=d["name"],
            type=d["type"],
            patientId=d.get("patientId"),
            status=d["status"],
            batteryLevel=d["batteryLevel"],
            firmwareVersion=d["firmwareVersion"],
            lastSeen=datetime.fromisoformat(d["lastSeen"]),
            createdAt=datetime.fromisoformat(d["createdAt"]),
            updatedAt=datetime.fromisoformat(d["updatedAt"])
        ) for d in devices_data
    ]
    
    return DevicePage(items=devices, nextToken=None)

# -------- Patients
@app.get("/api/v1/patients", response_model=PatientPage)
@require_role("doctor", "admin")
async def get_patients(request: Request):
    """
    Get patients list (Doctor, Admin only)
    - Doctor: Returns only their patients
    - Admin: Returns all patients
    """
    user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    # Get patient profiles
    if user_role == "doctor":
        profiles = db.get_patients_by_doctor(user_id)
    else:  # admin
        profiles = db.get_all_patient_profiles()
    
    # Enrich with user data
    patients = []
    for profile in profiles:
        user = db.get_user(profile["userId"])
        if user:
            patients.append(PatientWithProfile(
                userId=user["id"],
                email=user["email"],
                name=user.get("name"),
                role=user["role"],
                diagnosis=profile.get("diagnosis"),
                severity=profile.get("severity", "mild"),
                notes=profile.get("notes"),
                createdAt=datetime.fromisoformat(profile["createdAt"]),
                updatedAt=datetime.fromisoformat(profile["updatedAt"])
            ))
    
    return PatientPage(items=patients, nextToken=None)

@app.get("/api/v1/patients/{user_id}", response_model=PatientWithProfile)
@require_role("doctor", "admin")
async def get_patient_detail(user_id: str, request: Request):
    """
    Get patient details (Doctor, Admin only)
    - Doctor: Can only view their own patients
    - Admin: Can view all patients
    """
    current_user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    # Get patient profile
    profile = db.get_patient_profile(user_id)
    if not profile:
        raise HTTPException(404, detail={"code": "PATIENT_NOT_FOUND", "message": "Patient profile not found"})
    
    # RBAC: Doctor can only view their own patients
    if user_role == "doctor" and profile.get("doctorId") != current_user_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    # Get user data
    user = db.get_user(user_id)
    if not user:
        raise HTTPException(404, detail={"code": "USER_NOT_FOUND", "message": "User not found"})
    
    return PatientWithProfile(
        userId=user["id"],
        email=user["email"],
        name=user.get("name"),
        role=user["role"],
        diagnosis=profile.get("diagnosis"),
        severity=profile.get("severity", "mild"),
        notes=profile.get("notes"),
        createdAt=datetime.fromisoformat(profile["createdAt"]),
        updatedAt=datetime.fromisoformat(profile["updatedAt"])
    )

@app.put("/api/v1/patients/{user_id}/notes", response_model=PatientProfile)
@require_role("doctor")
async def update_patient_notes(user_id: str, body: PatientProfileUpdateReq, request: Request):
    """
    Update patient notes (Doctor only)
    Doctor can only update notes for their own patients
    """
    doctor_id = get_user_id(request)
    
    # Get patient profile
    profile = db.get_patient_profile(user_id)
    if not profile:
        raise HTTPException(404, detail={"code": "PATIENT_NOT_FOUND", "message": "Patient profile not found"})
    
    # RBAC: Doctor can only update their own patients
    if profile.get("doctorId") != doctor_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    # Build updates
    updates = {"updatedAt": datetime.now(timezone.utc).isoformat()}
    if body.diagnosis is not None:
        updates["diagnosis"] = body.diagnosis
    if body.severity is not None:
        updates["severity"] = body.severity
    if body.notes is not None:
        updates["notes"] = body.notes
    
    db.update_patient_profile(user_id, updates)
    
    # Get updated profile
    updated_profile = db.get_patient_profile(user_id)
    
    return PatientProfile(
        userId=updated_profile["userId"],
        doctorId=updated_profile["doctorId"],
        diagnosis=updated_profile.get("diagnosis"),
        severity=updated_profile.get("severity", "mild"),
        notes=updated_profile.get("notes"),
        createdAt=datetime.fromisoformat(updated_profile["createdAt"]),
        updatedAt=datetime.fromisoformat(updated_profile["updatedAt"])
    )

@app.get("/api/v1/me/profile", response_model=PatientProfile)
@require_role("patient")
async def get_my_profile(request: Request):
    """
    Get my patient profile (Patient only)
    """
    user_id = get_user_id(request)
    
    profile = db.get_patient_profile(user_id)
    if not profile:
        raise HTTPException(404, detail={"code": "PROFILE_NOT_FOUND", "message": "Patient profile not found"})
    
    return PatientProfile(
        userId=profile["userId"],
        doctorId=profile["doctorId"],
        diagnosis=profile.get("diagnosis"),
        severity=profile.get("severity", "mild"),
        notes=profile.get("notes"),
        createdAt=datetime.fromisoformat(profile["createdAt"]),
        updatedAt=datetime.fromisoformat(profile["updatedAt"])
    )

# -------- Sessions (Device-Patient Dynamic Binding)
@app.post("/api/v1/sessions", response_model=Session)
@require_role("doctor", "admin")
async def create_measurement_session(body: SessionCreateReq, request: Request):
    """
    Create a measurement session (Doctor, Admin only)
    - Binds a device to a patient for data collection
    - Checks if device is already in use
    """
    doctor_id = get_user_id(request)
    user_role = get_user_role(request)
    
    # Check if device exists
    device = db.get_device(body.deviceId)
    if not device:
        raise HTTPException(404, detail={"code": "DEVICE_NOT_FOUND", "message": "Device not found"})
    
    # Check if device is already in an active session
    active_session = db.get_active_session_by_device(body.deviceId)
    if active_session:
        raise HTTPException(409, detail={"code": "DEVICE_IN_USE", "message": "Device is already in an active session"})
    
    # Check if patient exists
    patient = db.get_user(body.patientId)
    if not patient or patient.get("role") != "patient":
        raise HTTPException(404, detail={"code": "PATIENT_NOT_FOUND", "message": "Patient not found"})
    
    # RBAC: Doctor can only create sessions for their own patients
    if user_role == "doctor":
        profile = db.get_patient_profile(body.patientId)
        if not profile:
            # Patient profile doesn't exist yet - this is OK for testing
            # In production, you might want to create it automatically
            pass
        elif profile.get("doctorId") != doctor_id:
            raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    # Create session
    session_id = f"sess_{secrets.token_hex(8)}"
    now = datetime.now(timezone.utc)
    session_data = {
        "sessionId": session_id,
        "deviceId": body.deviceId,
        "patientId": body.patientId,
        "doctorId": doctor_id,
        "status": "active",
        "notes": body.notes,
        "startTime": now.isoformat(),
        "endTime": None,
        "createdAt": now.isoformat(),
        "updatedAt": now.isoformat()
    }
    
    db.create_session(session_data)
    
    # Update device with current session
    db.update_device(body.deviceId, {
        "currentSessionId": session_id,
        "updatedAt": now.isoformat()
    })
    
    # Audit log: session creation
    audit_service.log_session_event(
        event_type=AuditEventType.SESSION_CREATE,
        user_id=doctor_id,
        user_role=user_role,
        session_id=session_id,
        device_id=body.deviceId,
        patient_id=body.patientId,
        action="create_measurement_session"
    )
    
    return Session(
        sessionId=session_data["sessionId"],
        deviceId=session_data["deviceId"],
        patientId=session_data["patientId"],
        doctorId=session_data.get("doctorId"),
        status=session_data["status"],
        notes=session_data.get("notes"),
        startTime=now,
        endTime=None,
        createdAt=now,
        updatedAt=now
    )

@app.get("/api/v1/sessions/{session_id}", response_model=SessionWithDetails)
@require_role("doctor", "admin", "patient")
async def get_session_detail(session_id: str, request: Request):
    """
    Get session details
    - Patient: Can view their own sessions
    - Doctor: Can view their patients' sessions
    - Admin: Can view all sessions
    """
    user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    session = db.get_session(session_id)
    if not session:
        raise HTTPException(404, detail={"code": "SESSION_NOT_FOUND", "message": "Session not found"})
    
    # RBAC checks
    if user_role == "patient" and session.get("patientId") != user_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    if user_role == "doctor":
        profile = db.get_patient_profile(session.get("patientId"))
        if not profile or profile.get("doctorId") != user_id:
            raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    # Get device and patient details
    device = db.get_device(session["deviceId"])
    patient = db.get_user(session["patientId"])
    
    return SessionWithDetails(
        sessionId=session["sessionId"],
        deviceId=session["deviceId"],
        deviceName=device.get("name", "Unknown") if device else "Unknown",
        deviceMacAddress=device.get("macAddress", "Unknown") if device else "Unknown",
        patientId=session["patientId"],
        patientName=patient.get("name") if patient else None,
        patientEmail=patient.get("email", "Unknown") if patient else "Unknown",
        doctorId=session.get("doctorId"),
        status=session["status"],
        notes=session.get("notes"),
        startTime=datetime.fromisoformat(session["startTime"]),
        endTime=datetime.fromisoformat(session["endTime"]) if session.get("endTime") else None
    )

@app.post("/api/v1/sessions/{session_id}/end", response_model=Session)
@require_role("doctor", "admin")
async def end_measurement_session(session_id: str, request: Request):
    """
    End a measurement session (Doctor, Admin only)
    - Marks session as completed
    - Frees up the device
    """
    doctor_id = get_user_id(request)
    user_role = get_user_role(request)
    
    session = db.get_session(session_id)
    if not session:
        raise HTTPException(404, detail={"code": "SESSION_NOT_FOUND", "message": "Session not found"})
    
    if session.get("status") != "active":
        raise HTTPException(400, detail={"code": "SESSION_NOT_ACTIVE", "message": "Session is not active"})
    
    # RBAC: Doctor can only end their own sessions
    if user_role == "doctor" and session.get("doctorId") != doctor_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Access denied"})
    
    # End session
    now = datetime.now(timezone.utc)
    updates = {
        "status": "completed",
        "endTime": now.isoformat(),
        "updatedAt": now.isoformat()
    }
    db.update_session(session_id, updates)
    
    # Clear device's current session
    db.update_device(session["deviceId"], {
        "currentSessionId": None,
        "updatedAt": now.isoformat()
    })
    
    # Get updated session
    updated_session = db.get_session(session_id)
    return Session(
        sessionId=updated_session["sessionId"],
        deviceId=updated_session["deviceId"],
        patientId=updated_session["patientId"],
        doctorId=updated_session.get("doctorId"),
        status=updated_session["status"],
        notes=updated_session.get("notes"),
        startTime=datetime.fromisoformat(updated_session["startTime"]),
        endTime=datetime.fromisoformat(updated_session["endTime"]) if updated_session.get("endTime") else None,
        createdAt=datetime.fromisoformat(updated_session["createdAt"]),
        updatedAt=datetime.fromisoformat(updated_session["updatedAt"])
    )

@app.get("/api/v1/devices/{device_id}/current-session", response_model=Session)
async def get_device_current_session(device_id: str):
    """
    Get current active session for a device (Public endpoint for Pi devices)
    - Pi devices poll this to know which patient to collect data for
    """
    active_session = db.get_active_session_by_device(device_id)
    if not active_session:
        raise HTTPException(404, detail={"code": "NO_ACTIVE_SESSION", "message": "No active session for this device"})
    
    return Session(
        sessionId=active_session["sessionId"],
        deviceId=active_session["deviceId"],
        patientId=active_session["patientId"],
        doctorId=active_session.get("doctorId"),
        status=active_session["status"],
        notes=active_session.get("notes"),
        startTime=datetime.fromisoformat(active_session["startTime"]),
        endTime=datetime.fromisoformat(active_session["endTime"]) if active_session.get("endTime") else None,
        createdAt=datetime.fromisoformat(active_session["createdAt"]),
        updatedAt=datetime.fromisoformat(active_session["updatedAt"])
    )

@app.get("/api/v1/sessions", response_model=SessionPage)
@require_role("doctor", "admin")
async def get_sessions(request: Request, status: Optional[str] = None):
    """
    Get sessions list (Doctor, Admin only)
    - Doctor: Returns sessions for their patients
    - Admin: Returns all sessions
    """
    user_id = get_user_id(request)
    user_role = get_user_role(request)
    
    if user_role == "doctor":
        # Get doctor's patients
        profiles = db.get_patients_by_doctor(user_id)
        patient_ids = [p["userId"] for p in profiles]
        
        # Get sessions for these patients
        all_sessions = []
        for patient_id in patient_ids:
            sessions = db.get_sessions_by_patient(patient_id)
            all_sessions.extend(sessions)
    else:  # admin
        if status == "active":
            all_sessions = db.get_active_sessions()
        else:
            # For admin, we'd need a scan operation (expensive)
            # For now, just return active sessions
            all_sessions = db.get_active_sessions()
    
    # Filter by status if specified
    if status:
        all_sessions = [s for s in all_sessions if s.get("status") == status]
    
    # Enrich with details
    sessions_with_details = []
    for session in all_sessions:
        device = db.get_device(session["deviceId"])
        patient = db.get_user(session["patientId"])
        
        sessions_with_details.append(SessionWithDetails(
            sessionId=session["sessionId"],
            deviceId=session["deviceId"],
            deviceName=device.get("name", "Unknown") if device else "Unknown",
            deviceMacAddress=device.get("macAddress", "Unknown") if device else "Unknown",
            patientId=session["patientId"],
            patientName=patient.get("name") if patient else None,
            patientEmail=patient.get("email", "Unknown") if patient else "Unknown",
            doctorId=session.get("doctorId"),
            status=session["status"],
            notes=session.get("notes"),
            startTime=datetime.fromisoformat(session["startTime"]),
            endTime=datetime.fromisoformat(session["endTime"]) if session.get("endTime") else None
        ))
    
    return SessionPage(items=sessions_with_details, nextToken=None)

# -------- Device Binding
@app.post("/api/v1/devices/bind")
@require_role("patient")
async def bind_device(body: DeviceBindReq, request: Request):
    """
    Bind a device to a patient (Patient only)
    """
    user_id = get_user_id(request)
    
    if body.patientId != user_id:
        raise HTTPException(403, detail={"code": "FORBIDDEN", "message": "Cannot bind device to another patient"})
    
    device_data = db.get_device(body.deviceId)
    if not device_data:
        raise HTTPException(404, detail={"code": "DEVICE_NOT_FOUND", "message": "Device not found"})
        
    db.update_device(body.deviceId, {"patientId": user_id, "updatedAt": datetime.now(timezone.utc).isoformat()})
    
    return {"success": True, "message": "Device bound to patient successfully"}

# -------- Doctor Endpoints
@app.get("/api/v1/doctor/patients", response_model=DoctorPatientsRes)
@require_role("doctor")
async def get_doctor_patients(request: Request, doctor_id: str):
    """Get patients assigned to a doctor"""
    user_id = get_user_id(request)
    if user_id != doctor_id:
        raise HTTPException(403, detail="Access denied")
        
    profiles = db.get_patients_by_doctor(doctor_id)
    
    patients = []
    for p in profiles:
        pid = p.get("userId")
        user = db.get_user(pid)
        if user:
            patients.append({
                "patient_id": pid,
                "email": user.get("email"),
                "name": user.get("name"),
                "assigned_at": p.get("assignedAt"),
                "status": p.get("status", "active")
            })
            
    return {
        "success": True,
        "patients": patients,
        "count": len(patients)
    }

@app.post("/api/v1/doctor/assign-patient")
@require_role("doctor")
async def assign_patient(request: Request, body: AssignPatientReq):
    """Assign a patient to a doctor"""
    try:
        user_id = get_user_id(request)
        if user_id != body.doctor_id:
            raise HTTPException(403, detail="Access denied")
            
        print(f"Assigning patient {body.patient_email} to doctor {body.doctor_id}")
        
        # Find patient by email
        patient = db.get_user_by_email(body.patient_email)
        if not patient:
            print(f"Patient not found: {body.patient_email}")
            raise HTTPException(404, detail="Patient not found")
            
        print(f"Found patient: {patient['id']}")
            
        # Create profile
        profile = {
            "userId": patient["id"],
            "doctorId": body.doctor_id,
            "assignedAt": datetime.now(timezone.utc).isoformat(),
            "status": "active"
        }
        print(f"Creating profile: {profile}")
        db.create_patient_profile(profile)
        
        return {"success": True, "message": "Patient assigned successfully"}
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        print(f"Error assigning patient: {str(e)}")
        print(traceback.format_exc())
        # Return the actual error for debugging
        raise HTTPException(500, detail=f"Internal Server Error: {str(e)}")

# -------- Tremor Analysis
@app.get("/api/v1/tremor/analysis", response_model=TremorResponse)
def get_tremor_analysis(
    request: Request,
    patient_id: str,
    start_time: Optional[int] = None,
    end_time: Optional[int] = None,
    limit: int = 100
):
    """
    Query tremor analysis data
    """
    # Auth check
    user_id = get_user_id(request)
    role = get_user_role(request)
    
    # Access control
    # Patients can only access their own data
    if role == 'patient' and user_id != patient_id:
        # Log access denied
        audit_service.log_access_denied(
            user_id=user_id,
            user_role=role,
            resource_type="tremor_data",
            resource_id=patient_id,
            required_role="patient (self) or doctor/admin"
        )
        raise HTTPException(403, detail="Access denied")
    
    items, count = db.get_tremor_analysis(patient_id, start_time, end_time, limit)
    
    # Log patient data access
    audit_service.log_patient_data_access(
        user_id=user_id,
        user_role=role,
        patient_id=patient_id,
        data_type="tremor_analysis",
        action="query"
    )
    
    return {
        "success": True,
        "data": items,
        "count": count
    }

# Lambda handler
handler = Mangum(app)
