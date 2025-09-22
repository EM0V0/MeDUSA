// User model and related data structures
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum UserRole {
    Admin,
    Doctor,
    Patient,
    Technician,
}

impl UserRole {
    pub fn as_str(&self) -> &'static str {
        match self {
            UserRole::Admin => "admin",
            UserRole::Doctor => "doctor",
            UserRole::Patient => "patient",
            UserRole::Technician => "technician",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub password_hash: String,
    pub first_name: String,
    pub last_name: String,
    pub role: UserRole,
    pub is_active: bool,
    pub is_verified: bool,
    pub two_factor_enabled: bool,
    pub two_factor_secret: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_login: Option<DateTime<Utc>>,
    
    // Role-specific fields
    pub license_number: Option<String>, // For doctors
    pub department: Option<String>,     // For doctors/technicians
    pub patient_id: Option<String>,     // For patients
}

#[derive(Debug, Deserialize, Validate)]
pub struct CreateUserRequest {
    #[validate(email)]
    pub email: String,
    
    #[validate(length(min = 8, max = 128))]
    pub password: String,
    
    #[validate(length(min = 1, max = 100))]
    pub first_name: String,
    
    #[validate(length(min = 1, max = 100))]
    pub last_name: String,
    
    pub role: UserRole,
    pub license_number: Option<String>,
    pub department: Option<String>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct LoginRequest {
    #[validate(email)]
    pub email: String,
    pub password: String,
    pub two_factor_code: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub user: UserProfile,
    pub expires_in: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UserProfile {
    pub id: Uuid,
    pub email: String,
    pub name: String,           // 前端兼容：合并的全名
    pub first_name: String,     // 后端详细信息
    pub last_name: String,      // 后端详细信息
    pub role: String,           // 前端兼容：字符串格式的角色
    #[serde(rename = "isActive")]
    pub is_active: bool,        // 前端兼容：驼峰命名
    pub is_verified: bool,
    pub two_factor_enabled: bool,
    pub created_at: DateTime<Utc>,
    #[serde(rename = "lastLogin")]
    pub last_login: Option<DateTime<Utc>>, // 前端兼容：驼峰命名
    pub license_number: Option<String>,
    pub department: Option<String>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateUserRequest {
    #[validate(length(min = 1, max = 100))]
    pub first_name: Option<String>,
    
    #[validate(length(min = 1, max = 100))]
    pub last_name: Option<String>,
    
    pub department: Option<String>,
    pub license_number: Option<String>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct ChangePasswordRequest {
    pub current_password: String,
    
    #[validate(length(min = 8, max = 128))]
    pub new_password: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct JwtClaims {
    pub sub: Uuid,      // Subject (user ID)
    pub email: String,  // User email
    pub role: UserRole, // User role
    pub exp: i64,       // Expiration time
    pub iat: i64,       // Issued at
}

impl User {
    /// Create a new user with default values
    pub fn new(
        email: String,
        password_hash: String,
        first_name: String,
        last_name: String,
        role: UserRole,
    ) -> Self {
        let now = Utc::now();
        User {
            id: Uuid::new_v4(),
            email,
            password_hash,
            first_name,
            last_name,
            role,
            is_active: true,
            is_verified: false,
            two_factor_enabled: false,
            two_factor_secret: None,
            created_at: now,
            updated_at: now,
            last_login: None,
            license_number: None,
            department: None,
            patient_id: None,
        }
    }
    
    /// Convert User to UserProfile (removes sensitive data and formats for frontend)
    pub fn to_profile(&self) -> UserProfile {
        UserProfile {
            id: self.id,
            email: self.email.clone(),
            name: self.full_name(),                    // 前端兼容：合并的全名
            first_name: self.first_name.clone(),      // 后端详细信息
            last_name: self.last_name.clone(),        // 后端详细信息
            role: self.role.as_str().to_string(),     // 前端兼容：字符串格式
            is_active: self.is_active,
            is_verified: self.is_verified,
            two_factor_enabled: self.two_factor_enabled,
            created_at: self.created_at,
            last_login: self.last_login,
            license_number: self.license_number.clone(),
            department: self.department.clone(),
        }
    }
    
    /// Get full name
    pub fn full_name(&self) -> String {
        format!("{} {}", self.first_name, self.last_name)
    }
}
