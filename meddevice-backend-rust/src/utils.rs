// Utility functions for the medical device backend
pub mod security;

use uuid::Uuid;
use chrono::{DateTime, Utc};
use lambda_http::{Request, RequestExt};
use std::collections::HashMap;
use serde_json::Value;

use crate::{Result, AppError};

/// Extract IP address from Lambda HTTP request
pub fn extract_ip_address(request: &Request) -> String {
    // Try to get IP from X-Forwarded-For header (from API Gateway)
    if let Some(forwarded_for) = request.headers().get("X-Forwarded-For") {
        if let Ok(ip_str) = forwarded_for.to_str() {
            // X-Forwarded-For can contain multiple IPs, take the first one
            if let Some(first_ip) = ip_str.split(',').next() {
                return first_ip.trim().to_string();
            }
        }
    }
    
    // Try X-Real-IP header
    if let Some(real_ip) = request.headers().get("X-Real-IP") {
        if let Ok(ip_str) = real_ip.to_str() {
            return ip_str.to_string();
        }
    }
    
    // Fallback to request context source IP
    // Note: lambda_http 0.8 may have different API structure
    // Simplified for now - can be enhanced based on actual request context structure
    
    // Default fallback
    "unknown".to_string()
}

/// Extract User-Agent from request headers
pub fn extract_user_agent(request: &Request) -> String {
    request.headers()
        .get("User-Agent")
        .and_then(|ua| ua.to_str().ok())
        .unwrap_or("unknown")
        .to_string()
}

/// Extract request ID for tracing
pub fn extract_request_id(request: &Request) -> String {
    // Try AWS request ID first
    if let Some(request_id) = request.headers().get("X-Amzn-RequestId") {
        if let Ok(id_str) = request_id.to_str() {
            return id_str.to_string();
        }
    }
    
    // Try trace ID
    if let Some(trace_id) = request.headers().get("X-Amzn-Trace-Id") {
        if let Ok(id_str) = trace_id.to_str() {
            return id_str.to_string();
        }
    }
    
    // Generate a new UUID if no request ID found
    Uuid::new_v4().to_string()
}

/// Parse query parameters from request
pub fn parse_query_params(request: &Request) -> HashMap<String, String> {
    let mut params = HashMap::new();
    
    let query_string_params = request.query_string_parameters();
    for (key, value) in query_string_params.iter() {
        params.insert(key.to_string(), value.to_string());
    }
    
    params
}

/// Parse path parameters from request
pub fn parse_path_params(request: &Request) -> HashMap<String, String> {
    let mut params = HashMap::new();
    
    let path_params = request.path_parameters();
    for (key, value) in path_params.iter() {
        params.insert(key.to_string(), value.to_string());
    }
    
    params
}

/// Extract UUID from path parameter
pub fn extract_uuid_param(path_params: &HashMap<String, String>, param_name: &str) -> Result<Uuid> {
    let param_value = path_params.get(param_name)
        .ok_or_else(|| AppError::BadRequest(format!("Missing path parameter: {}", param_name)))?;
    
    Uuid::parse_str(param_value)
        .map_err(|_| AppError::BadRequest(format!("Invalid UUID format for parameter: {}", param_name)))
}

/// Parse pagination parameters
pub struct PaginationParams {
    pub limit: u32,
    pub offset: u32,
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self {
            limit: 20,
            offset: 0,
        }
    }
}

pub fn parse_pagination_params(query_params: &HashMap<String, String>) -> PaginationParams {
    let limit = query_params.get("limit")
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(20)
        .min(100); // Cap at 100
    
    let offset = query_params.get("offset")
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(0);
    
    PaginationParams { limit, offset }
}

/// Parse date range parameters
pub struct DateRangeParams {
    pub start_date: Option<DateTime<Utc>>,
    pub end_date: Option<DateTime<Utc>>,
}

pub fn parse_date_range_params(query_params: &HashMap<String, String>) -> Result<DateRangeParams> {
    let start_date = if let Some(start_str) = query_params.get("start_date") {
        Some(DateTime::parse_from_rfc3339(start_str)
            .map_err(|_| AppError::BadRequest("Invalid start_date format. Use RFC3339".to_string()))?
            .with_timezone(&Utc))
    } else {
        None
    };
    
    let end_date = if let Some(end_str) = query_params.get("end_date") {
        Some(DateTime::parse_from_rfc3339(end_str)
            .map_err(|_| AppError::BadRequest("Invalid end_date format. Use RFC3339".to_string()))?
            .with_timezone(&Utc))
    } else {
        None
    };
    
    Ok(DateRangeParams { start_date, end_date })
}

/// Validate email format
pub fn is_valid_email(email: &str) -> bool {
    email.contains('@') && email.len() > 3 && email.len() < 255
}

/// Validate password strength
pub struct PasswordValidation {
    pub is_valid: bool,
    pub errors: Vec<String>,
}

pub fn validate_password(password: &str) -> PasswordValidation {
    let mut errors = Vec::new();
    
    if password.len() < 8 {
        errors.push("Password must be at least 8 characters long".to_string());
    }
    
    if password.len() > 128 {
        errors.push("Password must be no more than 128 characters long".to_string());
    }
    
    if !password.chars().any(|c| c.is_ascii_lowercase()) {
        errors.push("Password must contain at least one lowercase letter".to_string());
    }
    
    if !password.chars().any(|c| c.is_ascii_uppercase()) {
        errors.push("Password must contain at least one uppercase letter".to_string());
    }
    
    if !password.chars().any(|c| c.is_ascii_digit()) {
        errors.push("Password must contain at least one digit".to_string());
    }
    
    if !password.chars().any(|c| "!@#$%^&*()_+-=[]{}|;:,.<>?".contains(c)) {
        errors.push("Password must contain at least one special character".to_string());
    }
    
    PasswordValidation {
        is_valid: errors.is_empty(),
        errors,
    }
}

/// Generate a secure random string
pub fn generate_secure_random_string(length: usize) -> String {
    use rand::Rng;
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    let mut rng = rand::thread_rng();
    
    (0..length)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect()
}

/// Sanitize input string to prevent injection attacks
pub fn sanitize_input(input: &str) -> String {
    input
        .trim()
        .replace(['<', '>', '"', '\'', '&'], "")
        .chars()
        .filter(|c| c.is_ascii_graphic() || c.is_ascii_whitespace())
        .collect()
}

/// Convert HashMap to JSON Value
pub fn hashmap_to_json(map: HashMap<String, String>) -> Value {
    let mut json_map = serde_json::Map::new();
    for (key, value) in map {
        json_map.insert(key, Value::String(value));
    }
    Value::Object(json_map)
}

/// Format file size in human readable format
pub fn format_file_size(size_bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = size_bytes as f64;
    let mut unit_index = 0;
    
    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }
    
    if unit_index == 0 {
        format!("{} {}", size_bytes, UNITS[unit_index])
    } else {
        format!("{:.1} {}", size, UNITS[unit_index])
    }
}

/// Calculate age from date of birth
pub fn calculate_age(date_of_birth: &chrono::NaiveDate) -> i32 {
    let today = Utc::now().date_naive();
    today.years_since(*date_of_birth).unwrap_or(0) as i32
}

/// Mask sensitive data for logging
pub fn mask_sensitive_data(data: &str, mask_char: char, visible_chars: usize) -> String {
    if data.len() <= visible_chars * 2 {
        mask_char.to_string().repeat(data.len().min(8))
    } else {
        let start = &data[..visible_chars];
        let end = &data[data.len() - visible_chars..];
        let masked_middle = mask_char.to_string().repeat(data.len() - visible_chars * 2);
        format!("{}{}{}", start, masked_middle, end)
    }
}

/// Validate and parse JSON from request body
pub fn parse_json_body<T>(body: &str) -> Result<T> 
where
    T: serde::de::DeserializeOwned,
{
    if body.is_empty() {
        return Err(AppError::BadRequest("Request body is empty".to_string()));
    }
    
    serde_json::from_str(body)
        .map_err(|e| AppError::BadRequest(format!("Invalid JSON format: {}", e)))
}

/// Create standardized error response
pub fn create_error_response(error: &AppError, request_id: &str) -> serde_json::Value {
    serde_json::json!({
        "error": {
            "code": error.status_code().as_u16(),
            "message": error.to_string(),
            "type": match error {
                AppError::Database(_) => "DATABASE_ERROR",
                AppError::Storage(_) => "STORAGE_ERROR",
                AppError::Authentication(_) => "AUTHENTICATION_ERROR",
                AppError::Authorization(_) => "AUTHORIZATION_ERROR",
                AppError::Validation(_) => "VALIDATION_ERROR",
                AppError::NotFound(_) => "NOT_FOUND",
                AppError::Conflict(_) => "CONFLICT",
                AppError::Internal(_) => "INTERNAL_ERROR",
                AppError::BadRequest(_) => "BAD_REQUEST",
                AppError::ExternalService(_) => "EXTERNAL_SERVICE_ERROR",
            },
            "request_id": request_id,
            "timestamp": Utc::now().to_rfc3339(),
        }
    })
}

/// Create standardized success response
pub fn create_success_response<T>(data: T, message: Option<&str>) -> serde_json::Value 
where
    T: serde::Serialize,
{
    let mut response = serde_json::json!({
        "success": true,
        "data": data,
        "timestamp": Utc::now().to_rfc3339(),
    });
    
    if let Some(msg) = message {
        response["message"] = serde_json::Value::String(msg.to_string());
    }
    
    response
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_validate_password() {
        let weak_password = validate_password("weak");
        assert!(!weak_password.is_valid);
        assert!(!weak_password.errors.is_empty());
        
        let strong_password = validate_password("StrongP@ssw0rd123");
        assert!(strong_password.is_valid);
        assert!(strong_password.errors.is_empty());
    }
    
    #[test]
    fn test_is_valid_email() {
        assert!(is_valid_email("user@example.com"));
        assert!(is_valid_email("test.email+tag@domain.co.uk"));
        assert!(!is_valid_email("invalid-email"));
        assert!(!is_valid_email("@domain.com"));
        assert!(!is_valid_email("user@"));
    }
    
    #[test]
    fn test_format_file_size() {
        assert_eq!(format_file_size(500), "500 B");
        assert_eq!(format_file_size(1024), "1.0 KB");
        assert_eq!(format_file_size(1536), "1.5 KB");
        assert_eq!(format_file_size(1048576), "1.0 MB");
    }
    
    #[test]
    fn test_mask_sensitive_data() {
        assert_eq!(mask_sensitive_data("1234567890", '*', 2), "12******90");
        assert_eq!(mask_sensitive_data("short", '*', 2), "*****");
    }
}
