from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# ========================================
# Request Models (API v3 compliant)
# ========================================

class LoginReq(BaseModel):
    """Login request - API v3"""
    email: str
    password: str

class RegisterReq(BaseModel):
    """Register request - API v3"""
    email: str
    password: str
    role: str = "patient"  # API v3 requires role field

class RefreshReq(BaseModel):
    """Refresh request - API v3 uses camelCase"""
    refreshToken: str = Field(alias="refreshToken")

# ========================================
# Auth Response Models (API v3 - flat, no data wrapper)
# ========================================

class RegisterRes(BaseModel):
    """Register response - API v3 format (201)"""
    userId: str
    accessJwt: str  # API v3 uses accessJwt (camelCase)
    refreshToken: str
    
    class Config:
        # Allow both camelCase and snake_case input
        populate_by_name = True

class LoginRes(BaseModel):
    """Login response - API v3 format (200)"""
    accessJwt: str  # API v3 uses accessJwt
    refreshToken: str
    expiresIn: int  # API v3 uses camelCase
    
    class Config:
        populate_by_name = True

class RefreshRes(BaseModel):
    """Refresh response - API v3 format (200)"""
    accessJwt: str
    refreshToken: str
    
    class Config:
        populate_by_name = True

# ========================================
# User Model (for internal use or other endpoints)
# ========================================

class UserOut(BaseModel):
    """User object - internal use"""
    id: str
    email: str
    role: str
    name: Optional[str] = None
    createdAt: datetime

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class PoseCreateReq(BaseModel):
    """Request model for creating a pose"""
    patientId: Optional[str] = None
    fileKey: str

class PresignReq(BaseModel):
    filename: str
    contentType: str
    scope: str  # "pose" | "report"
    patientId: Optional[str] = None

class PresignRes(BaseModel):
    uploadUrl: str
    fileKey: str
    expiresIn: int

class Pose(BaseModel):
    id: str
    patientId: str
    fileKey: str
    createdAt: datetime

class PosePage(BaseModel):
    items: List[Pose]
    nextToken: Optional[str] = None

class Report(BaseModel):
    id: str
    patientId: str
    fileKey: str
    createdAt: datetime

class ReportPage(BaseModel):
    items: List[Report]
    nextToken: Optional[str] = None
