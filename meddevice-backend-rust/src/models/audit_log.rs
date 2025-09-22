// Audit log model for tracking all system activities
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditAction {
    // Authentication actions
    Login,
    Logout,
    LoginFailed,
    PasswordChanged,
    TwoFactorEnabled,
    TwoFactorDisabled,
    
    // User management
    UserCreated,
    UserUpdated,
    UserDeleted,
    UserActivated,
    UserDeactivated,
    
    // Patient management
    PatientCreated,
    PatientUpdated,
    PatientDeleted,
    PatientViewed,
    PatientAssignedToDevice,
    PatientUnassignedFromDevice,
    
    // Device management
    DeviceCreated,
    DeviceUpdated,
    DeviceDeleted,
    DeviceConnected,
    DeviceDisconnected,
    DeviceReadingReceived,
    DeviceCalibrated,
    
    // Report generation
    ReportGenerated,
    ReportViewed,
    ReportDownloaded,
    ReportShared,
    ReportDeleted,
    
    // System administration
    SystemSettingsChanged,
    BackupCreated,
    BackupRestored,
    MaintenanceModeEnabled,
    MaintenanceModeDisabled,
    
    // Data operations
    DataExported,
    DataImported,
    DataPurged,
    
    // Security events
    UnauthorizedAccess,
    SuspiciousActivity,
    SecurityPolicyViolation,
    
    // Custom actions
    Custom(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditSeverity {
    Info,
    Warning,
    Error,
    Critical,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditLog {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub action: AuditAction,
    pub severity: AuditSeverity,
    
    // Who performed the action
    pub user_id: Option<Uuid>,
    pub user_email: Option<String>,
    pub user_role: Option<String>,
    
    // What was affected
    pub resource_type: Option<String>,  // "patient", "device", "report", etc.
    pub resource_id: Option<Uuid>,
    pub resource_name: Option<String>,
    
    // Context information
    pub description: String,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub session_id: Option<String>,
    
    // Additional metadata
    pub metadata: HashMap<String, serde_json::Value>,
    
    // Changes (for update operations)
    pub old_values: Option<HashMap<String, serde_json::Value>>,
    pub new_values: Option<HashMap<String, serde_json::Value>>,
    
    // System info
    pub service_name: String,           // Which microservice/lambda generated this log
    pub request_id: Option<String>,     // For tracing requests across services
}

#[derive(Debug, Serialize)]
pub struct AuditLogSummary {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub action: AuditAction,
    pub severity: AuditSeverity,
    pub user_email: Option<String>,
    pub resource_type: Option<String>,
    pub description: String,
    pub ip_address: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AuditLogQuery {
    pub start_date: Option<DateTime<Utc>>,
    pub end_date: Option<DateTime<Utc>>,
    pub user_id: Option<Uuid>,
    pub actions: Option<Vec<AuditAction>>,
    pub severity: Option<AuditSeverity>,
    pub resource_type: Option<String>,
    pub resource_id: Option<Uuid>,
    pub ip_address: Option<String>,
    pub limit: Option<u32>,
    pub offset: Option<u32>,
}

impl AuditLog {
    /// Create a new audit log entry
    pub fn new(
        action: AuditAction,
        description: String,
        service_name: String,
    ) -> Self {
        AuditLog {
            id: Uuid::new_v4(),
            timestamp: Utc::now(),
            action,
            severity: AuditSeverity::Info,
            user_id: None,
            user_email: None,
            user_role: None,
            resource_type: None,
            resource_id: None,
            resource_name: None,
            description,
            ip_address: None,
            user_agent: None,
            session_id: None,
            metadata: HashMap::new(),
            old_values: None,
            new_values: None,
            service_name,
            request_id: None,
        }
    }
    
    /// Builder pattern methods for setting optional fields
    pub fn with_user(mut self, user_id: Uuid, email: String, role: String) -> Self {
        self.user_id = Some(user_id);
        self.user_email = Some(email);
        self.user_role = Some(role);
        self
    }
    
    pub fn with_resource(mut self, resource_type: String, resource_id: Uuid, name: Option<String>) -> Self {
        self.resource_type = Some(resource_type);
        self.resource_id = Some(resource_id);
        self.resource_name = name;
        self
    }
    
    pub fn with_severity(mut self, severity: AuditSeverity) -> Self {
        self.severity = severity;
        self
    }
    
    pub fn with_request_context(mut self, ip: String, user_agent: String, request_id: String) -> Self {
        self.ip_address = Some(ip);
        self.user_agent = Some(user_agent);
        self.request_id = Some(request_id);
        self
    }
    
    pub fn with_changes(
        mut self, 
        old_values: HashMap<String, serde_json::Value>,
        new_values: HashMap<String, serde_json::Value>
    ) -> Self {
        self.old_values = Some(old_values);
        self.new_values = Some(new_values);
        self
    }
    
    pub fn with_metadata(mut self, key: String, value: serde_json::Value) -> Self {
        self.metadata.insert(key, value);
        self
    }
    
    /// Convert to summary view for lists
    pub fn to_summary(&self) -> AuditLogSummary {
        AuditLogSummary {
            id: self.id,
            timestamp: self.timestamp,
            action: self.action.clone(),
            severity: self.severity.clone(),
            user_email: self.user_email.clone(),
            resource_type: self.resource_type.clone(),
            description: self.description.clone(),
            ip_address: self.ip_address.clone(),
        }
    }
}

// Helper functions for creating common audit log entries
impl AuditLog {
    /// Create audit log for user authentication
    pub fn user_login(user_id: Uuid, email: String, ip: String, success: bool) -> Self {
        let action = if success { AuditAction::Login } else { AuditAction::LoginFailed };
        let severity = if success { AuditSeverity::Info } else { AuditSeverity::Warning };
        let description = if success {
            format!("User {} logged in successfully", email)
        } else {
            format!("Failed login attempt for user {}", email)
        };
        
        AuditLog::new(action, description, "auth-service".to_string())
            .with_user(user_id, email, "".to_string())
            .with_severity(severity)
            .with_metadata("ip_address".to_string(), serde_json::Value::String(ip))
    }
    
    /// Create audit log for data access
    pub fn data_access(
        user_id: Uuid, 
        user_email: String, 
        resource_type: String, 
        resource_id: Uuid, 
        action: String
    ) -> Self {
        let description = format!("User {} {} {} {}", user_email, action, resource_type, resource_id);
        
        AuditLog::new(AuditAction::Custom(action), description, "api-service".to_string())
            .with_user(user_id, user_email, "".to_string())
            .with_resource(resource_type, resource_id, None)
    }
    
    /// Create audit log for security events
    pub fn security_event(description: String, ip: String, severity: AuditSeverity) -> Self {
        AuditLog::new(AuditAction::SuspiciousActivity, description, "security-service".to_string())
            .with_severity(severity)
            .with_metadata("ip_address".to_string(), serde_json::Value::String(ip))
    }
}
