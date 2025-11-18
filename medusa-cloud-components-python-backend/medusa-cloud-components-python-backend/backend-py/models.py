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

class ResetPasswordReq(BaseModel):
    """Reset password request"""
    email: str
    newPassword: str

class SendVerificationCodeReq(BaseModel):
    """Send verification code request"""
    email: str
    code: str
    type: str  # 'registration' or 'password_reset'

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
    user: dict  # User information
    
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

# ========================================
# Device Models
# ========================================

class DeviceRegisterReq(BaseModel):
    """Register device request"""
    macAddress: str
    name: str
    type: str = "tremor_sensor"
    firmwareVersion: str = "1.0.0"

class DeviceUpdateReq(BaseModel):
    """Update device request"""
    name: Optional[str] = None
    batteryLevel: Optional[int] = None
    status: Optional[str] = None
    firmwareVersion: Optional[str] = None

class Device(BaseModel):
    """Device model"""
    id: str
    macAddress: str
    name: str
    type: str
    patientId: Optional[str] = None  # For personal devices only
    currentSessionId: Optional[str] = None  # Current active session
    status: str  # online, offline, error
    batteryLevel: int
    firmwareVersion: str
    lastSeen: datetime
    createdAt: datetime
    updatedAt: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class DevicePage(BaseModel):
    """Device list response"""
    items: List[Device]
    nextToken: Optional[str] = None

# ========================================
# Patient Profile Models
# ========================================

class PatientProfileCreateReq(BaseModel):
    """Create patient profile request (for admin/doctor)"""
    userId: str
    doctorId: str
    diagnosis: Optional[str] = None
    severity: Optional[str] = "mild"  # mild, moderate, severe
    notes: Optional[str] = None

class PatientProfileUpdateReq(BaseModel):
    """Update patient profile request"""
    diagnosis: Optional[str] = None
    severity: Optional[str] = None
    notes: Optional[str] = None

class PatientProfile(BaseModel):
    """Patient profile model"""
    userId: str
    doctorId: str
    diagnosis: Optional[str] = None
    severity: str  # mild, moderate, severe
    notes: Optional[str] = None
    createdAt: datetime
    updatedAt: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class PatientWithProfile(BaseModel):
    """Patient with profile and user info"""
    userId: str
    email: str
    name: Optional[str] = None
    role: str
    diagnosis: Optional[str] = None
    severity: str
    notes: Optional[str] = None
    createdAt: datetime
    updatedAt: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class PatientPage(BaseModel):
    """Patient list response"""
    items: List[PatientWithProfile]
    nextToken: Optional[str] = None

# ========================================
# Session Models (Device-Patient Dynamic Binding)
# ========================================

class SessionCreateReq(BaseModel):
    """Create measurement session request"""
    deviceId: str
    patientId: str
    notes: Optional[str] = None

class SessionUpdateReq(BaseModel):
    """Update session request"""
    notes: Optional[str] = None

class Session(BaseModel):
    """Measurement session model"""
    sessionId: str
    deviceId: str
    patientId: str
    doctorId: Optional[str] = None  # Who created the session
    status: str  # active, completed, cancelled
    notes: Optional[str] = None
    startTime: datetime
    endTime: Optional[datetime] = None
    createdAt: datetime
    updatedAt: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class SessionWithDetails(BaseModel):
    """Session with device and patient details"""
    sessionId: str
    deviceId: str
    deviceName: str
    deviceMacAddress: str
    patientId: str
    patientName: Optional[str] = None
    patientEmail: str
    doctorId: Optional[str] = None
    status: str
    notes: Optional[str] = None
    startTime: datetime
    endTime: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class SessionPage(BaseModel):
    """Session list response"""
    items: List[SessionWithDetails]
    nextToken: Optional[str] = None
