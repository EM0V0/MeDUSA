// Authentication service for JWT and user authentication
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};
// use bcrypt::{hash, verify, DEFAULT_COST}; // Replaced with Argon2
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier};
use argon2::password_hash::{rand_core::OsRng, SaltString};
use uuid::Uuid;
use chrono::{DateTime, Utc, Duration};
use base64::{Engine as _, engine::general_purpose};
use std::collections::HashMap;

use crate::{Result, AppError, Config};
use crate::models::{User, UserRole, JwtClaims, LoginRequest, LoginResponse};
use crate::services::CryptoService;

pub struct AuthService {
    config: Config,
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
}

#[derive(Debug, Clone)]
pub struct TokenPair {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_in: u64,
}

#[derive(Debug, Clone)]
pub struct AuthContext {
    pub user_id: Uuid,
    pub email: String,
    pub role: UserRole,
    pub is_verified: bool,
    pub permissions: Vec<String>,
}

impl AuthService {
    /// Create a new authentication service with security validation
    pub fn new(config: Config) -> Result<Self> {
        // Validate JWT secret strength
        CryptoService::validate_jwt_secret(&config.jwt_secret)?;
        
        let secret = config.jwt_secret.as_bytes();
        let encoding_key = EncodingKey::from_secret(secret);
        let decoding_key = DecodingKey::from_secret(secret);
        
        Ok(Self {
            config,
            encoding_key,
            decoding_key,
        })
    }
    
    /// Hash a password using medical-grade Argon2id
    pub fn hash_password(&self, password: &str) -> Result<String> {
        CryptoService::hash_password_medical_grade(password)
    }
    
    /// Verify a password against medical-grade Argon2 hash
    pub fn verify_password(&self, password: &str, hash: &str) -> Result<bool> {
        CryptoService::verify_password_medical_grade(password, hash)
    }
    
    /// Generate JWT tokens for a user
    pub fn generate_tokens(&self, user: &User) -> Result<TokenPair> {
        let now = Utc::now();
        let expires_in = self.config.jwt_expiration_hours * 3600; // Convert to seconds
        let exp = now + Duration::seconds(expires_in as i64);
        
        // Access token claims
        let access_claims = JwtClaims {
            sub: user.id,
            email: user.email.clone(),
            role: user.role.clone(),
            exp: exp.timestamp(),
            iat: now.timestamp(),
        };
        
        // Generate access token
        let access_token = encode(&Header::default(), &access_claims, &self.encoding_key)
            .map_err(|e| AppError::Authentication(format!("Failed to generate access token: {}", e)))?;
        
        // Refresh token (configurable expiration)
        let refresh_exp = now + Duration::days(self.config.jwt_refresh_expiration_days as i64);
        let refresh_claims = JwtClaims {
            sub: user.id,
            email: user.email.clone(),
            role: user.role.clone(),
            exp: refresh_exp.timestamp(),
            iat: now.timestamp(),
        };
        
        let refresh_token = encode(&Header::default(), &refresh_claims, &self.encoding_key)
            .map_err(|e| AppError::Authentication(format!("Failed to generate refresh token: {}", e)))?;
        
        Ok(TokenPair {
            access_token,
            refresh_token,
            expires_in,
        })
    }
    
    /// Validate and decode a JWT token
    pub fn validate_token(&self, token: &str) -> Result<JwtClaims> {
        let validation = Validation::new(Algorithm::HS256);
        
        let token_data = decode::<JwtClaims>(token, &self.decoding_key, &validation)
            .map_err(|e| AppError::Authentication(format!("Invalid token: {}", e)))?;
        
        // Check if token is expired
        let now = Utc::now().timestamp();
        if token_data.claims.exp < now {
            return Err(AppError::Authentication("Token has expired".to_string()));
        }
        
        Ok(token_data.claims)
    }
    
    /// Extract token from Authorization header
    pub fn extract_token_from_header(&self, auth_header: &str) -> Result<String> {
        if !auth_header.starts_with("Bearer ") {
            return Err(AppError::Authentication("Invalid authorization header format".to_string()));
        }
        
        let token = auth_header.strip_prefix("Bearer ").unwrap_or("");
        if token.is_empty() {
            return Err(AppError::Authentication("No token provided".to_string()));
        }
        
        Ok(token.to_string())
    }
    
    /// Create authentication context from token
    pub fn create_auth_context(&self, claims: &JwtClaims) -> AuthContext {
        let permissions = self.get_role_permissions(&claims.role);
        
        AuthContext {
            user_id: claims.sub,
            email: claims.email.clone(),
            role: claims.role.clone(),
            is_verified: true, // Would check user verification status in real implementation
            permissions,
        }
    }
    
    /// Get permissions for a user role
    pub fn get_role_permissions(&self, role: &UserRole) -> Vec<String> {
        match role {
            UserRole::Admin => vec![
                "user:create".to_string(),
                "user:read".to_string(),
                "user:update".to_string(),
                "user:delete".to_string(),
                "patient:create".to_string(),
                "patient:read".to_string(),
                "patient:update".to_string(),
                "patient:delete".to_string(),
                "device:create".to_string(),
                "device:read".to_string(),
                "device:update".to_string(),
                "device:delete".to_string(),
                "report:create".to_string(),
                "report:read".to_string(),
                "report:delete".to_string(),
                "audit:read".to_string(),
                "system:manage".to_string(),
            ],
            UserRole::Doctor => vec![
                "patient:read".to_string(),
                "patient:update".to_string(),
                "device:read".to_string(),
                "device:update".to_string(),
                "report:create".to_string(),
                "report:read".to_string(),
                "reading:read".to_string(),
            ],
            UserRole::Patient => vec![
                "patient:read_own".to_string(),
                "patient:update_own".to_string(),
                "device:read_own".to_string(),
                "reading:read_own".to_string(),
                "report:read_own".to_string(),
            ],
            UserRole::Technician => vec![
                "device:read".to_string(),
                "device:update".to_string(),
                "device:create".to_string(),
                "reading:create".to_string(),
                "reading:read".to_string(),
            ],
        }
    }
    
    /// Check if user has specific permission
    pub fn has_permission(&self, auth_context: &AuthContext, permission: &str) -> bool {
        auth_context.permissions.contains(&permission.to_string())
    }
    
    /// Check if user can access resource
    pub fn can_access_resource(
        &self,
        auth_context: &AuthContext,
        resource_type: &str,
        resource_owner_id: Option<Uuid>,
        action: &str,
    ) -> bool {
        // Admin can access everything
        if matches!(auth_context.role, UserRole::Admin) {
            return true;
        }
        
        let permission = format!("{}:{}", resource_type, action);
        
        // Check general permission
        if self.has_permission(auth_context, &permission) {
            return true;
        }
        
        // Check owner-specific permission
        if let Some(owner_id) = resource_owner_id {
            if owner_id == auth_context.user_id {
                let own_permission = format!("{}:{}_own", resource_type, action);
                return self.has_permission(auth_context, &own_permission);
            }
        }
        
        false
    }
    
    /// Generate two-factor authentication secret
    pub fn generate_2fa_secret(&self) -> String {
        use rand::Rng;
        let mut rng = rand::thread_rng();
        let secret: Vec<u8> = (0..20).map(|_| rng.gen()).collect();
        general_purpose::STANDARD.encode(secret)
    }
    
    /// Verify two-factor authentication code
    pub fn verify_2fa_code(&self, secret: &str, code: &str) -> Result<bool> {
        // In a real implementation, you would use a TOTP library like `totp-lite`
        // This is a simplified version for demonstration
        
        // Decode the secret
        let secret_bytes = general_purpose::STANDARD.decode(secret)
            .map_err(|e| AppError::Authentication(format!("Invalid 2FA secret: {}", e)))?;
        
        // In practice, you would generate the expected TOTP code and compare
        // For now, we'll just check if the code is 6 digits
        if code.len() == 6 && code.chars().all(|c| c.is_ascii_digit()) {
            // This is a placeholder - implement proper TOTP verification
            Ok(true)
        } else {
            Ok(false)
        }
    }
    
    /// Create login response
    pub fn create_login_response(&self, user: &User, tokens: TokenPair) -> LoginResponse {
        LoginResponse {
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            user: user.to_profile(),
            expires_in: tokens.expires_in,
        }
    }
    
    /// Validate login request
    pub fn validate_login_request(&self, request: &LoginRequest) -> Result<()> {
        if request.email.is_empty() {
            return Err(AppError::Validation("Email is required".to_string()));
        }
        
        if request.password.is_empty() {
            return Err(AppError::Validation("Password is required".to_string()));
        }
        
        if !request.email.contains('@') {
            return Err(AppError::Validation("Invalid email format".to_string()));
        }
        
        Ok(())
    }
    
    /// Generate password reset token
    pub fn generate_password_reset_token(&self, user_id: Uuid) -> Result<String> {
        let now = Utc::now();
        let exp = now + Duration::hours(1); // 1 hour expiration
        
        let claims = serde_json::json!({
            "sub": user_id.to_string(),
            "type": "password_reset",
            "exp": exp.timestamp(),
            "iat": now.timestamp(),
        });
        
        encode(&Header::default(), &claims, &self.encoding_key)
            .map_err(|e| AppError::Authentication(format!("Failed to generate reset token: {}", e)))
    }
    
    /// Validate password reset token
    pub fn validate_password_reset_token(&self, token: &str) -> Result<Uuid> {
        let validation = Validation::new(Algorithm::HS256);
        
        let token_data = decode::<serde_json::Value>(token, &self.decoding_key, &validation)
            .map_err(|e| AppError::Authentication(format!("Invalid reset token: {}", e)))?;
        
        // Check token type
        if token_data.claims.get("type").and_then(|v| v.as_str()) != Some("password_reset") {
            return Err(AppError::Authentication("Invalid token type".to_string()));
        }
        
        // Check expiration
        let exp = token_data.claims.get("exp").and_then(|v| v.as_i64()).unwrap_or(0);
        if exp < Utc::now().timestamp() {
            return Err(AppError::Authentication("Reset token has expired".to_string()));
        }
        
        // Extract user ID
        let user_id_str = token_data.claims.get("sub").and_then(|v| v.as_str())
            .ok_or_else(|| AppError::Authentication("Invalid token format".to_string()))?;
        
        Uuid::parse_str(user_id_str)
            .map_err(|_| AppError::Authentication("Invalid user ID in token".to_string()))
    }
}
