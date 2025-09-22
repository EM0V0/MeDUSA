// Configuration management for AWS services and application settings
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    // DynamoDB table names
    pub users_table: String,
    pub devices_table: String,
    pub patients_table: String,
    pub reports_table: String,
    pub audit_logs_table: String,
    
    // S3 bucket names
    pub reports_bucket: String,
    pub device_data_bucket: String,
    pub backup_bucket: String,
    
    // JWT configuration - Enhanced security
    pub jwt_secret: String,
    pub jwt_expiration_hours: u64,
    pub jwt_refresh_expiration_days: u64,
    pub jwt_algorithm: String,
    
    // AWS region
    pub aws_region: String,
    
    // Application settings
    pub environment: String,
    pub log_level: String,
}

impl Config {
    /// Load configuration from environment variables
    pub fn from_env() -> Self {
        Config {
            // DynamoDB tables
            users_table: env::var("USERS_TABLE")
                .unwrap_or_else(|_| "meddevice-users".to_string()),
            devices_table: env::var("DEVICES_TABLE")
                .unwrap_or_else(|_| "meddevice-devices".to_string()),
            patients_table: env::var("PATIENTS_TABLE")
                .unwrap_or_else(|_| "meddevice-patients".to_string()),
            reports_table: env::var("REPORTS_TABLE")
                .unwrap_or_else(|_| "meddevice-reports".to_string()),
            audit_logs_table: env::var("AUDIT_LOGS_TABLE")
                .unwrap_or_else(|_| "meddevice-audit-logs".to_string()),
            
            // S3 buckets
            reports_bucket: env::var("REPORTS_BUCKET")
                .unwrap_or_else(|_| "meddevice-reports".to_string()),
            device_data_bucket: env::var("DEVICE_DATA_BUCKET")
                .unwrap_or_else(|_| "meddevice-device-data".to_string()),
            backup_bucket: env::var("BACKUP_BUCKET")
                .unwrap_or_else(|_| "meddevice-backups".to_string()),
            
            // JWT settings - Enhanced configuration
            jwt_secret: env::var("JWT_SECRET")
                .unwrap_or_else(|_| "your-super-secret-jwt-key-change-in-production-min-64-chars-required".to_string()),
            jwt_expiration_hours: env::var("JWT_EXPIRATION_HOURS")
                .unwrap_or_else(|_| "1".to_string())  // Reduced to 1 hour for enhanced security
                .parse()
                .unwrap_or(1),
            jwt_refresh_expiration_days: env::var("JWT_REFRESH_EXPIRATION_DAYS")
                .unwrap_or_else(|_| "7".to_string())  // Refresh tokens valid for 7 days
                .parse()
                .unwrap_or(7),
            jwt_algorithm: env::var("JWT_ALGORITHM")
                .unwrap_or_else(|_| "HS256".to_string()), // Keep HS256 for performance
            
            // AWS region
            aws_region: env::var("AWS_REGION")
                .unwrap_or_else(|_| "us-east-1".to_string()),
            
            // Application settings
            environment: env::var("ENVIRONMENT")
                .unwrap_or_else(|_| "development".to_string()),
            log_level: env::var("LOG_LEVEL")
                .unwrap_or_else(|_| "info".to_string()),
        }
    }
    
    /// Check if running in production environment
    pub fn is_production(&self) -> bool {
        self.environment.to_lowercase() == "production"
    }
    
    /// Check if running in development environment
    pub fn is_development(&self) -> bool {
        self.environment.to_lowercase() == "development"
    }
}
