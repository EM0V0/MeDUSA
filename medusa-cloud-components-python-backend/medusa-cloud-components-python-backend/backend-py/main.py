import os, sys, uuid, time
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

from models import *
from auth import auth_middleware, issue_tokens, verify_pw, hash_pw
import db
import storage

app = FastAPI(title="MeDUSA Python API (Single Lambda)")

# CORS - align to API GW config; tighten in prod if needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False
)

@app.middleware("http")
async def _auth_mw(request: Request, call_next):
    return await auth_middleware(request, call_next)

# -------- Admin
@app.get("/api/v1/admin/health")
def health():
    return {"ok": True, "ts": int(time.time())}

# -------- Auth
@app.post("/api/v1/auth/register", response_model=RegisterRes, status_code=201)
def register(req: RegisterReq):
    """
    Register new user - API v3 compliant
    Returns flat response with userId only (no data wrapper)
    """
    existing = db.get_user_by_email(req.email)
    if existing:
        raise HTTPException(409, detail={"code":"EMAIL_TAKEN","message":"email already registered"})
    
    uid = f"usr_{uuid.uuid4().hex[:8]}"
    
    # API v3: role is required in request, default to patient if not provided
    role = req.role.lower() if req.role else "patient"
    
    user = {
        "id": uid,
        "email": req.email,
        "role": role,
        "name": req.email.split('@')[0],  # Generate name from email
        "password": hash_pw(req.password),
        "createdAt": datetime.now(timezone.utc).isoformat()
    }
    db.put_user(user)
    
    # Generate tokens
    tokens = issue_tokens(uid, user["role"])
    db.save_refresh(
        tokens["refreshToken"],  # API v3 uses camelCase
        {
            "userId": uid, 
            "role": user["role"], 
            "expiresAt": int(time.time()) + int(os.environ.get("REFRESH_TTL_SECONDS","604800"))
        }
    )
    
    # API v3: Return flat response with userId, accessJwt, refreshToken
    return RegisterRes(
        userId=uid,
        accessJwt=tokens["accessJwt"],
        refreshToken=tokens["refreshToken"]
    )

@app.post("/api/v1/auth/login", response_model=LoginRes)
def login(req: LoginReq):
    """
    Login user - API v3 compliant
    Returns flat response with accessJwt, refreshToken, expiresIn
    """
    u = db.get_user_by_email(req.email)
    if not u or not verify_pw(req.password, u["password"]):
        raise HTTPException(401, detail={"code":"AUTH_INVALID","message":"invalid credentials"})
    
    # Generate tokens
    tokens = issue_tokens(u["id"], u["role"])
    db.save_refresh(
        tokens["refreshToken"],  # API v3 uses camelCase
        {
            "userId": u["id"], 
            "role": u["role"], 
            "expiresAt": int(time.time()) + int(os.environ.get("REFRESH_TTL_SECONDS","604800"))
        }
    )
    
    # API v3: Return flat response with accessJwt, refreshToken, expiresIn
    return LoginRes(
        accessJwt=tokens["accessJwt"],
        refreshToken=tokens["refreshToken"],
        expiresIn=tokens["expiresIn"]
    )

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
def poses_list(patientId: str, nextToken: Optional[str] = None):
    try:
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
def poses_create(body: PoseCreateReq, request: Request):
    """
    Create pose data - API v3 compliant
    Returns list with single created pose
    """
    try:
        claims = getattr(request.state, "claims", {})
        pid = body.patientId or claims.get("sub")
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
def patient_pose_list(userId: str):
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

# Lambda handler
handler = Mangum(app)
