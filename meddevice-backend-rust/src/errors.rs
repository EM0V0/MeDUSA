// Comprehensive error handling for the medical device backend
use std::fmt;
use lambda_http::{http::StatusCode, Response, Body};
use serde_json::json;

pub type Result<T> = std::result::Result<T, AppError>;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(String),
    
    #[error("S3 storage error: {0}")]
    Storage(String),
    
    #[error("Authentication error: {0}")]
    Authentication(String),
    
    #[error("Authorization error: {0}")]
    Authorization(String),
    
    #[error("Validation error: {0}")]
    Validation(String),
    
    #[error("Not found: {0}")]
    NotFound(String),
    
    #[error("Conflict: {0}")]
    Conflict(String),
    
    #[error("Internal server error: {0}")]
    Internal(String),
    
    #[error("Bad request: {0}")]
    BadRequest(String),
    
    #[error("External service error: {0}")]
    ExternalService(String),
}

impl AppError {
    /// Convert AppError to HTTP status code
    pub fn status_code(&self) -> StatusCode {
        match self {
            AppError::Database(_) => StatusCode::INTERNAL_SERVER_ERROR,
            AppError::Storage(_) => StatusCode::INTERNAL_SERVER_ERROR,
            AppError::Authentication(_) => StatusCode::UNAUTHORIZED,
            AppError::Authorization(_) => StatusCode::FORBIDDEN,
            AppError::Validation(_) => StatusCode::BAD_REQUEST,
            AppError::NotFound(_) => StatusCode::NOT_FOUND,
            AppError::Conflict(_) => StatusCode::CONFLICT,
            AppError::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
            AppError::BadRequest(_) => StatusCode::BAD_REQUEST,
            AppError::ExternalService(_) => StatusCode::BAD_GATEWAY,
        }
    }
    
    /// Convert AppError to JSON error response
    pub fn to_response(&self) -> Response<Body> {
        let status = self.status_code();
        let body = json!({
            "error": {
                "code": status.as_u16(),
                "message": self.to_string(),
                "type": match self {
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
                }
            }
        });
        
        Response::builder()
            .status(status)
            .header("Content-Type", "application/json")
            .body(body.to_string().into())
            .unwrap()
    }
}

// Convert from various error types
impl From<aws_sdk_dynamodb::Error> for AppError {
    fn from(err: aws_sdk_dynamodb::Error) -> Self {
        AppError::Database(err.to_string())
    }
}

impl From<aws_sdk_s3::Error> for AppError {
    fn from(err: aws_sdk_s3::Error) -> Self {
        AppError::Storage(err.to_string())
    }
}

impl From<serde_json::Error> for AppError {
    fn from(err: serde_json::Error) -> Self {
        AppError::BadRequest(format!("JSON parsing error: {}", err))
    }
}

impl From<validator::ValidationErrors> for AppError {
    fn from(err: validator::ValidationErrors) -> Self {
        AppError::Validation(err.to_string())
    }
}

impl From<jsonwebtoken::errors::Error> for AppError {
    fn from(err: jsonwebtoken::errors::Error) -> Self {
        AppError::Authentication(format!("JWT error: {}", err))
    }
}
