from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# ========================================
# Request Models (API v3 compliant)
# ========================================

class LoginReq(BaseModel):
    """Login request - API v3"""
    email: str = Field(..., max_length=255)
    password: str = Field(..., max_length=128)

class RegisterReq(BaseModel):
    """Register request - API v3"""
    email: str = Field(..., max_length=255)
    password: str = Field(..., max_length=128)
    role: str = Field("patient", max_length=20)  # API v3 requires role field

class RefreshReq(BaseModel):
    """Refresh request - API v3 uses camelCase"""
    refreshToken: str = Field(..., alias="refreshToken", max_length=2048)

class ResetPasswordReq(BaseModel):
    """Reset password request"""
    email: str = Field(..., max_length=255)
    newPassword: str = Field(..., max_length=128)

class SendVerificationCodeReq(BaseModel):
    """Send verification code request"""
    email: str = Field(..., max_length=255)
    code: str = Field(..., max_length=10)
    type: str = Field(..., max_length=20)  # 'registration' or 'password_reset'

class MfaSetupRes(BaseModel):
    """MFA Setup Response"""
    secret: str
    qrCodeUrl: str

class MfaVerifyReq(BaseModel):
    """MFA Verify Request"""
    code: str = Field(..., max_length=10)
    secret: Optional[str] = Field(None, max_length=64) # For setup verification

class MfaLoginReq(BaseModel):
    """MFA Login Request"""
    tempToken: str = Field(..., max_length=2048)
    code: str = Field(..., max_length=10)

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
    accessJwt: Optional[str] = None  # API v3 uses accessJwt
    refreshToken: Optional[str] = None
    expiresIn: Optional[int] = None  # API v3 uses camelCase
    user: Optional[dict] = None  # User information
    mfaRequired: bool = False
    tempToken: Optional[str] = None
    
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
    patientId: Optional[str] = Field(None, max_length=50)
    fileKey: str = Field(..., max_length=255)

class PresignReq(BaseModel):
    filename: str = Field(..., max_length=255)
    contentType: str = Field(..., max_length=100)
    scope: str = Field(..., max_length=20)  # "pose" | "report"
    patientId: Optional[str] = Field(None, max_length=50)

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
    macAddress: str = Field(..., max_length=17)
    name: str = Field(..., max_length=100)
    type: str = Field("tremor_sensor", max_length=50)
    firmwareVersion: str = Field("1.0.0", max_length=20)

class DeviceUpdateReq(BaseModel):
    """Update device request"""
    name: Optional[str] = Field(None, max_length=100)
    batteryLevel: Optional[int] = None
    status: Optional[str] = Field(None, max_length=20)
    firmwareVersion: Optional[str] = Field(None, max_length=20)

class DeviceBindReq(BaseModel):
    """Bind device request"""
    deviceId: str = Field(..., max_length=50)
    patientId: str = Field(..., max_length=50)

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
    userId: str = Field(..., max_length=50)
    doctorId: str = Field(..., max_length=50)
    diagnosis: Optional[str] = Field(None, max_length=500)
    severity: Optional[str] = Field("mild", max_length=20)  # mild, moderate, severe
    notes: Optional[str] = Field(None, max_length=2000)

class PatientProfileUpdateReq(BaseModel):
    """Update patient profile request"""
    diagnosis: Optional[str] = Field(None, max_length=500)
    severity: Optional[str] = Field(None, max_length=20)
    notes: Optional[str] = Field(None, max_length=2000)

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
    deviceId: str = Field(..., max_length=50)
    patientId: str = Field(..., max_length=50)
    notes: Optional[str] = Field(None, max_length=2000)

class SessionUpdateReq(BaseModel):
    """Update session request"""
    notes: Optional[str] = Field(None, max_length=2000)

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

# ========================================
# Tremor Analysis Models
# ========================================

class TremorDataPoint(BaseModel):
    patient_id: str
    timestamp: int
    device_id: Optional[str] = None
    tremor_index: Optional[float] = None
    tremor_score: Optional[float] = None
    dominant_frequency: Optional[float] = None
    is_parkinsonian: Optional[bool] = None
    rms_value: Optional[float] = None
    signal_quality: Optional[float] = None
    tremor_power: Optional[float] = None
    total_power: Optional[float] = None

class TremorResponse(BaseModel):
    success: bool
    data: List[TremorDataPoint]
    count: int

# ========================================
# Doctor Models
# ========================================

class AssignPatientReq(BaseModel):
    doctor_id: str = Field(..., max_length=50)
    patient_email: str = Field(..., max_length=255)

class DoctorPatientItem(BaseModel):
    patient_id: str
    email: str
    name: Optional[str] = None
    assigned_at: Optional[str] = None
    status: Optional[str] = None

class DoctorPatientsRes(BaseModel):
    success: bool
    patients: List[DoctorPatientItem]
    count: int
