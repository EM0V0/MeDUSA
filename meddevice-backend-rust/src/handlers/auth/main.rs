// Authentication Lambda handler
// Handles user login, registration, password reset, and token validation

use lambda_http::{run, service_fn, Error, Request, RequestExt, Response, Body};
use lambda_runtime::tracing;
use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoClient;
use serde_json::json;
use std::collections::HashMap;
use validator::Validate;

// Import from the main library
use meddevice_backend::{
    Config, Result, AppError,
    models::{CreateUserRequest, LoginRequest, ChangePasswordRequest, User, UserRole},
    services::{DynamoDbService, AuthService, AuditService},
    utils::*,
};

/// Main Lambda function entry point
async fn function_handler(event: Request) -> Result<Response<Body>, Error> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_target(false)
        .without_time()
        .init();
    
    // Load configuration
    let config = Config::from_env();
    
    // Initialize AWS clients
    let aws_config = aws_config::load_defaults(BehaviorVersion::latest()).await;
    let dynamo_client = DynamoClient::new(&aws_config);
    
    // Initialize services
    let db_service = DynamoDbService::new(dynamo_client, config.clone());
    let auth_service = AuthService::new(config.clone())?;  // 现在返回Result
    let audit_service = AuditService::new(db_service.clone());
    
    // Extract request information
    let method = event.method().as_str();
    let path = event.uri().path();
    let request_id = extract_request_id(&event);
    let ip_address = extract_ip_address(&event);
    let user_agent = extract_user_agent(&event);
    
    tracing::info!("Processing {} {} - Request ID: {}", method, path, request_id);
    
    // Route the request
    let result = match (method, path) {
        ("POST", "/auth/register") => handle_register(event, &db_service, &auth_service, &audit_service).await,
        ("POST", "/auth/login") => handle_login(event, &db_service, &auth_service, &audit_service).await,
        ("POST", "/auth/logout") => handle_logout(event, &auth_service, &audit_service).await,
        ("POST", "/auth/refresh") => handle_refresh_token(event, &db_service, &auth_service).await,
        ("POST", "/auth/change-password") => handle_change_password(event, &db_service, &auth_service, &audit_service).await,
        ("POST", "/auth/forgot-password") => handle_forgot_password(event, &db_service, &auth_service).await,
        ("POST", "/auth/reset-password") => handle_reset_password(event, &db_service, &auth_service).await,
        ("GET", "/auth/me") => handle_get_current_user(event, &db_service, &auth_service).await,
        ("POST", "/auth/verify-token") => handle_verify_token(event, &auth_service).await,
        _ => Err(AppError::NotFound("Endpoint not found".to_string())),
    };
    
    // Handle the result and create response
    match result {
        Ok(response) => {
            tracing::info!("Request completed successfully - Request ID: {}", request_id);
            Ok(response)
        }
        Err(error) => {
            tracing::error!("Request failed: {} - Request ID: {}", error, request_id);
            
            // Log security events for authentication failures
            if matches!(error, AppError::Authentication(_)) {
                let _ = audit_service.log_security_event(
                    crate::models::AuditAction::SuspiciousActivity,
                    format!("Authentication failure: {}", error),
                    crate::models::AuditSeverity::Warning,
                    Some(ip_address),
                    None,
                    None,
                    Some(HashMap::from([
                        ("user_agent".to_string(), json!(user_agent)),
                        ("endpoint".to_string(), json!(format!("{} {}", method, path))),
                    ])),
                ).await;
            }
            
            Ok(error.to_response())
        }
    }
}

/// Handle user registration
async fn handle_register(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
    audit_service: &AuditService,
) -> Result<Response<Body>> {
    let body = std::str::from_utf8(event.body()).unwrap_or("");
    let request: CreateUserRequest = parse_json_body(body)?;
    
    // Validate request
    request.validate()?;
    
    // Check if user already exists
    if let Some(_existing_user) = db_service.get_user_by_email(&request.email).await? {
        return Err(AppError::Conflict("User with this email already exists".to_string()));
    }
    
    // Hash password
    let password_hash = auth_service.hash_password(&request.password)?;
    
    // Create user
    let user = User::new(
        request.email.clone(),
        password_hash,
        request.first_name.clone(),
        request.last_name.clone(),
        request.role.clone(),
    );
    
    // Save to database
    db_service.create_user(&user).await?;
    
    // Generate tokens
    let tokens = auth_service.generate_tokens(&user)?;
    let response = auth_service.create_login_response(&user, tokens);
    
    // Log audit event
    let ip_address = extract_ip_address(&event);
    let user_agent = extract_user_agent(&event);
    audit_service.log_user_management(
        user.id,
        user.email.clone(),
        user.role.as_str().to_string(),
        crate::models::AuditAction::UserCreated,
        user.id,
        user.email.clone(),
        ip_address,
        None,
    ).await?;
    
    let response_body = create_success_response(response, Some("User registered successfully"));
    
    Ok(Response::builder()
        .status(201)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle user login
async fn handle_login(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
    audit_service: &AuditService,
) -> Result<Response<Body>> {
    let body = std::str::from_utf8(event.body()).unwrap_or("");
    let request: LoginRequest = parse_json_body(body)?;
    
    // Validate request
    auth_service.validate_login_request(&request)?;
    
    let ip_address = extract_ip_address(&event);
    let user_agent = extract_user_agent(&event);
    
    // Get user by email
    let user = match db_service.get_user_by_email(&request.email).await? {
        Some(user) => user,
        None => {
            // Log failed login attempt
            audit_service.log_authentication(
                None,
                request.email.clone(),
                ip_address,
                user_agent,
                false,
                Some("User not found".to_string()),
            ).await?;
            
            return Err(AppError::Authentication("Invalid email or password".to_string()));
        }
    };
    
    // Check if user is active
    if !user.is_active {
        audit_service.log_authentication(
            Some(user.id),
            user.email.clone(),
            ip_address,
            user_agent,
            false,
            Some("Account is deactivated".to_string()),
        ).await?;
        
        return Err(AppError::Authentication("Account is deactivated".to_string()));
    }
    
    // Verify password
    if !auth_service.verify_password(&request.password, &user.password_hash)? {
        audit_service.log_authentication(
            Some(user.id),
            user.email.clone(),
            ip_address,
            user_agent,
            false,
            Some("Invalid password".to_string()),
        ).await?;
        
        return Err(AppError::Authentication("Invalid email or password".to_string()));
    }
    
    // Check 2FA if enabled
    if user.two_factor_enabled {
        if let Some(code) = &request.two_factor_code {
            if let Some(secret) = &user.two_factor_secret {
                if !auth_service.verify_2fa_code(secret, code)? {
                    audit_service.log_authentication(
                        Some(user.id),
                        user.email.clone(),
                        ip_address,
                        user_agent,
                        false,
                        Some("Invalid 2FA code".to_string()),
                    ).await?;
                    
                    return Err(AppError::Authentication("Invalid two-factor authentication code".to_string()));
                }
            } else {
                return Err(AppError::Internal("2FA enabled but no secret found".to_string()));
            }
        } else {
            return Err(AppError::Authentication("Two-factor authentication code required".to_string()));
        }
    }
    
    // Update last login time
    let mut updated_user = user.clone();
    updated_user.last_login = Some(chrono::Utc::now());
    updated_user.updated_at = chrono::Utc::now();
    db_service.update_user(&updated_user).await?;
    
    // Generate tokens
    let tokens = auth_service.generate_tokens(&updated_user)?;
    let response = auth_service.create_login_response(&updated_user, tokens);
    
    // Log successful login
    audit_service.log_authentication(
        Some(user.id),
        user.email.clone(),
        ip_address,
        user_agent,
        true,
        None,
    ).await?;
    
    let response_body = create_success_response(response, Some("Login successful"));
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle user logout
async fn handle_logout(
    event: Request,
    auth_service: &AuthService,
    audit_service: &AuditService,
) -> Result<Response<Body>> {
    // Extract and validate token
    let auth_header = event.headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok())
        .ok_or_else(|| AppError::Authentication("Authorization header required".to_string()))?;
    
    let token = auth_service.extract_token_from_header(auth_header)?;
    let claims = auth_service.validate_token(&token)?;
    
    // Log logout
    let ip_address = extract_ip_address(&event);
    let user_agent = extract_user_agent(&event);
    
    let audit_log = crate::models::AuditLog::new(
        crate::models::AuditAction::Logout,
        format!("User {} logged out", claims.email),
        "auth-service".to_string(),
    )
    .with_user(claims.sub, claims.email, claims.role.as_str().to_string())
    .with_request_context(ip_address, user_agent, extract_request_id(&event));
    
    // Note: In a production system, you would add the token to a blacklist
    // For now, we just log the logout event
    
    let response_body = create_success_response(json!({}), Some("Logout successful"));
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle token refresh
async fn handle_refresh_token(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
) -> Result<Response<Body>> {
    let body = std::str::from_utf8(event.body()).unwrap_or("");
    let request: serde_json::Value = parse_json_body(body)?;
    
    let refresh_token = request.get("refresh_token")
        .and_then(|t| t.as_str())
        .ok_or_else(|| AppError::BadRequest("Refresh token required".to_string()))?;
    
    // Validate refresh token
    let claims = auth_service.validate_token(refresh_token)?;
    
    // Get current user data
    let user = db_service.get_user(claims.sub).await?
        .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;
    
    // Check if user is still active
    if !user.is_active {
        return Err(AppError::Authentication("Account is deactivated".to_string()));
    }
    
    // Generate new tokens
    let tokens = auth_service.generate_tokens(&user)?;
    let response = auth_service.create_login_response(&user, tokens);
    
    let response_body = create_success_response(response, Some("Token refreshed successfully"));
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle password change
async fn handle_change_password(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
    audit_service: &AuditService,
) -> Result<Response<Body>> {
    // Extract and validate token
    let auth_header = event.headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok())
        .ok_or_else(|| AppError::Authentication("Authorization header required".to_string()))?;
    
    let token = auth_service.extract_token_from_header(auth_header)?;
    let claims = auth_service.validate_token(&token)?;
    
    // Parse request body
    let body = std::str::from_utf8(event.body()).unwrap_or("");
    let request: ChangePasswordRequest = parse_json_body(body)?;
    request.validate()?;
    
    // Get user
    let user = db_service.get_user(claims.sub).await?
        .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;
    
    // Verify current password
    if !auth_service.verify_password(&request.current_password, &user.password_hash)? {
        return Err(AppError::Authentication("Current password is incorrect".to_string()));
    }
    
    // Hash new password
    let new_password_hash = auth_service.hash_password(&request.new_password)?;
    
    // Update user
    let mut updated_user = user.clone();
    updated_user.password_hash = new_password_hash;
    updated_user.updated_at = chrono::Utc::now();
    db_service.update_user(&updated_user).await?;
    
    // Log password change
    let ip_address = extract_ip_address(&event);
    let user_agent = extract_user_agent(&event);
    
    let audit_log = crate::models::AuditLog::new(
        crate::models::AuditAction::PasswordChanged,
        format!("User {} changed password", user.email),
        "auth-service".to_string(),
    )
    .with_user(user.id, user.email, user.role.as_str().to_string())
    .with_request_context(ip_address, user_agent, extract_request_id(&event));
    
    let response_body = create_success_response(json!({}), Some("Password changed successfully"));
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle forgot password
async fn handle_forgot_password(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
) -> Result<Response<Body>> {
    let body = std::str::from_utf8(event.body()).unwrap_or("");
    let request: serde_json::Value = parse_json_body(body)?;
    
    let email = request.get("email")
        .and_then(|e| e.as_str())
        .ok_or_else(|| AppError::BadRequest("Email is required".to_string()))?;
    
    // Check if user exists (but don't reveal if they don't)
    if let Some(user) = db_service.get_user_by_email(email).await? {
        // Generate password reset token
        let reset_token = auth_service.generate_password_reset_token(user.id)?;
        
        // In a real application, you would send this token via email
        // For now, we'll just return success
        tracing::info!("Password reset token generated for user {}: {}", email, reset_token);
    }
    
    // Always return success to prevent email enumeration
    let response_body = create_success_response(
        json!({}), 
        Some("If an account with that email exists, a password reset link has been sent")
    );
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle password reset
async fn handle_reset_password(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
) -> Result<Response<Body>> {
    let body = std::str::from_utf8(event.body()).unwrap_or("");
    let request: serde_json::Value = parse_json_body(body)?;
    
    let reset_token = request.get("reset_token")
        .and_then(|t| t.as_str())
        .ok_or_else(|| AppError::BadRequest("Reset token is required".to_string()))?;
    
    let new_password = request.get("new_password")
        .and_then(|p| p.as_str())
        .ok_or_else(|| AppError::BadRequest("New password is required".to_string()))?;
    
    // Validate password strength
    let password_validation = validate_password(new_password);
    if !password_validation.is_valid {
        return Err(AppError::Validation(password_validation.errors.join(", ")));
    }
    
    // Validate reset token
    let user_id = auth_service.validate_password_reset_token(reset_token)?;
    
    // Get user
    let user = db_service.get_user(user_id).await?
        .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;
    
    // Hash new password
    let password_hash = auth_service.hash_password(new_password)?;
    
    // Update user
    let mut updated_user = user.clone();
    updated_user.password_hash = password_hash;
    updated_user.updated_at = chrono::Utc::now();
    db_service.update_user(&updated_user).await?;
    
    let response_body = create_success_response(json!({}), Some("Password reset successfully"));
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle get current user
async fn handle_get_current_user(
    event: Request,
    db_service: &DynamoDbService,
    auth_service: &AuthService,
) -> Result<Response<Body>> {
    // Extract and validate token
    let auth_header = event.headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok())
        .ok_or_else(|| AppError::Authentication("Authorization header required".to_string()))?;
    
    let token = auth_service.extract_token_from_header(auth_header)?;
    let claims = auth_service.validate_token(&token)?;
    
    // Get current user data
    let user = db_service.get_user(claims.sub).await?
        .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;
    
    let response_body = create_success_response(user.to_profile(), None);
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

/// Handle token verification
async fn handle_verify_token(
    event: Request,
    auth_service: &AuthService,
) -> Result<Response<Body>> {
    // Extract and validate token
    let auth_header = event.headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok())
        .ok_or_else(|| AppError::Authentication("Authorization header required".to_string()))?;
    
    let token = auth_service.extract_token_from_header(auth_header)?;
    let claims = auth_service.validate_token(&token)?;
    
    let auth_context = auth_service.create_auth_context(&claims);
    
    let response_body = create_success_response(json!({
        "valid": true,
        "user_id": auth_context.user_id,
        "email": auth_context.email,
        "role": auth_context.role,
        "permissions": auth_context.permissions,
    }), Some("Token is valid"));
    
    Ok(Response::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(response_body.to_string().into())?)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    run(service_fn(function_handler)).await
}
