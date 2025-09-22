// Audit service for logging all system activities
use uuid::Uuid;
use chrono::Utc;
use std::collections::HashMap;
use serde_json::Value;

use crate::{Result, AppError};
use crate::models::{AuditLog, AuditAction, AuditSeverity, AuditLogQuery};
use crate::services::DynamoDbService;

pub struct AuditService {
    db_service: DynamoDbService,
}

impl AuditService {
    /// Create a new audit service
    pub fn new(db_service: DynamoDbService) -> Self {
        Self { db_service }
    }
    
    /// Log an audit event
    pub async fn log(
        &self,
        action: AuditAction,
        description: String,
        service_name: String,
    ) -> Result<()> {
        let audit_log = AuditLog::new(action, description, service_name);
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log user authentication event
    pub async fn log_authentication(
        &self,
        user_id: Option<Uuid>,
        email: String,
        ip_address: String,
        user_agent: String,
        success: bool,
        error_message: Option<String>,
    ) -> Result<()> {
        let action = if success {
            AuditAction::Login
        } else {
            AuditAction::LoginFailed
        };
        
        let severity = if success {
            AuditSeverity::Info
        } else {
            AuditSeverity::Warning
        };
        
        let description = if success {
            format!("User {} logged in successfully", email)
        } else {
            format!("Failed login attempt for user {}: {}", 
                email, error_message.unwrap_or_else(|| "Unknown error".to_string()))
        };
        
        let mut audit_log = AuditLog::new(action, description, "auth-service".to_string())
            .with_severity(severity)
            .with_request_context(ip_address, user_agent, Uuid::new_v4().to_string());
        
        if let Some(uid) = user_id {
            audit_log = audit_log.with_user(uid, email, "".to_string());
        }
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log user management actions
    pub async fn log_user_management(
        &self,
        acting_user_id: Uuid,
        acting_user_email: String,
        acting_user_role: String,
        action: AuditAction,
        target_user_id: Uuid,
        target_user_email: String,
        ip_address: String,
        changes: Option<(HashMap<String, Value>, HashMap<String, Value>)>,
    ) -> Result<()> {
        let description = match action {
            AuditAction::UserCreated => format!("Created user account for {}", target_user_email),
            AuditAction::UserUpdated => format!("Updated user account for {}", target_user_email),
            AuditAction::UserDeleted => format!("Deleted user account for {}", target_user_email),
            AuditAction::UserActivated => format!("Activated user account for {}", target_user_email),
            AuditAction::UserDeactivated => format!("Deactivated user account for {}", target_user_email),
            _ => format!("Performed action on user account for {}", target_user_email),
        };
        
        let mut audit_log = AuditLog::new(action, description, "user-service".to_string())
            .with_user(acting_user_id, acting_user_email, acting_user_role)
            .with_resource("user".to_string(), target_user_id, Some(target_user_email))
            .with_metadata("ip_address".to_string(), Value::String(ip_address));
        
        if let Some((old_values, new_values)) = changes {
            audit_log = audit_log.with_changes(old_values, new_values);
        }
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log patient management actions
    pub async fn log_patient_management(
        &self,
        acting_user_id: Uuid,
        acting_user_email: String,
        acting_user_role: String,
        action: AuditAction,
        patient_id: Uuid,
        patient_name: String,
        ip_address: String,
    ) -> Result<()> {
        let description = match action {
            AuditAction::PatientCreated => format!("Created patient record for {}", patient_name),
            AuditAction::PatientUpdated => format!("Updated patient record for {}", patient_name),
            AuditAction::PatientDeleted => format!("Deleted patient record for {}", patient_name),
            AuditAction::PatientViewed => format!("Viewed patient record for {}", patient_name),
            _ => format!("Performed action on patient record for {}", patient_name),
        };
        
        let audit_log = AuditLog::new(action, description, "patient-service".to_string())
            .with_user(acting_user_id, acting_user_email, acting_user_role)
            .with_resource("patient".to_string(), patient_id, Some(patient_name))
            .with_metadata("ip_address".to_string(), Value::String(ip_address));
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log device management actions
    pub async fn log_device_management(
        &self,
        acting_user_id: Uuid,
        acting_user_email: String,
        acting_user_role: String,
        action: AuditAction,
        device_id: Uuid,
        device_name: String,
        ip_address: String,
        additional_metadata: Option<HashMap<String, Value>>,
    ) -> Result<()> {
        let description = match action {
            AuditAction::DeviceCreated => format!("Created device {}", device_name),
            AuditAction::DeviceUpdated => format!("Updated device {}", device_name),
            AuditAction::DeviceDeleted => format!("Deleted device {}", device_name),
            AuditAction::DeviceConnected => format!("Connected device {}", device_name),
            AuditAction::DeviceDisconnected => format!("Disconnected device {}", device_name),
            AuditAction::DeviceReadingReceived => format!("Received reading from device {}", device_name),
            AuditAction::DeviceCalibrated => format!("Calibrated device {}", device_name),
            _ => format!("Performed action on device {}", device_name),
        };
        
        let mut audit_log = AuditLog::new(action, description, "device-service".to_string())
            .with_user(acting_user_id, acting_user_email, acting_user_role)
            .with_resource("device".to_string(), device_id, Some(device_name))
            .with_metadata("ip_address".to_string(), Value::String(ip_address));
        
        // Add additional metadata if provided
        if let Some(metadata) = additional_metadata {
            for (key, value) in metadata {
                audit_log = audit_log.with_metadata(key, value);
            }
        }
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log report generation and access
    pub async fn log_report_activity(
        &self,
        acting_user_id: Uuid,
        acting_user_email: String,
        acting_user_role: String,
        action: AuditAction,
        report_id: Uuid,
        report_title: String,
        ip_address: String,
    ) -> Result<()> {
        let description = match action {
            AuditAction::ReportGenerated => format!("Generated report: {}", report_title),
            AuditAction::ReportViewed => format!("Viewed report: {}", report_title),
            AuditAction::ReportDownloaded => format!("Downloaded report: {}", report_title),
            AuditAction::ReportShared => format!("Shared report: {}", report_title),
            AuditAction::ReportDeleted => format!("Deleted report: {}", report_title),
            _ => format!("Performed action on report: {}", report_title),
        };
        
        let audit_log = AuditLog::new(action, description, "report-service".to_string())
            .with_user(acting_user_id, acting_user_email, acting_user_role)
            .with_resource("report".to_string(), report_id, Some(report_title))
            .with_metadata("ip_address".to_string(), Value::String(ip_address));
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log data operations
    pub async fn log_data_operation(
        &self,
        acting_user_id: Uuid,
        acting_user_email: String,
        acting_user_role: String,
        action: AuditAction,
        description: String,
        ip_address: String,
        metadata: HashMap<String, Value>,
    ) -> Result<()> {
        let mut audit_log = AuditLog::new(action, description, "data-service".to_string())
            .with_user(acting_user_id, acting_user_email, acting_user_role)
            .with_metadata("ip_address".to_string(), Value::String(ip_address));
        
        // Add all provided metadata
        for (key, value) in metadata {
            audit_log = audit_log.with_metadata(key, value);
        }
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log security events
    pub async fn log_security_event(
        &self,
        event_type: AuditAction,
        description: String,
        severity: AuditSeverity,
        ip_address: Option<String>,
        user_id: Option<Uuid>,
        user_email: Option<String>,
        additional_context: Option<HashMap<String, Value>>,
    ) -> Result<()> {
        let mut audit_log = AuditLog::new(event_type, description, "security-service".to_string())
            .with_severity(severity);
        
        if let (Some(uid), Some(email)) = (user_id, user_email) {
            audit_log = audit_log.with_user(uid, email, "".to_string());
        }
        
        if let Some(ip) = ip_address {
            audit_log = audit_log.with_metadata("ip_address".to_string(), Value::String(ip));
        }
        
        // Add additional context
        if let Some(context) = additional_context {
            for (key, value) in context {
                audit_log = audit_log.with_metadata(key, value);
            }
        }
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Log system administration actions
    pub async fn log_system_admin(
        &self,
        acting_user_id: Uuid,
        acting_user_email: String,
        action: AuditAction,
        description: String,
        ip_address: String,
        severity: AuditSeverity,
    ) -> Result<()> {
        let audit_log = AuditLog::new(action, description, "admin-service".to_string())
            .with_user(acting_user_id, acting_user_email, "admin".to_string())
            .with_severity(severity)
            .with_metadata("ip_address".to_string(), Value::String(ip_address));
        
        self.db_service.create_audit_log(&audit_log).await
    }
    
    /// Query audit logs with filters
    pub async fn query_logs(&self, query: AuditLogQuery) -> Result<Vec<AuditLog>> {
        self.db_service.query_audit_logs(&query).await
    }
    
    /// Get recent audit logs for a user
    pub async fn get_user_activity(&self, user_id: Uuid, limit: Option<u32>) -> Result<Vec<AuditLog>> {
        let query = AuditLogQuery {
            user_id: Some(user_id),
            limit,
            ..Default::default()
        };
        
        self.query_logs(query).await
    }
    
    /// Get audit logs for a specific resource
    pub async fn get_resource_activity(
        &self,
        resource_type: String,
        resource_id: Uuid,
        limit: Option<u32>,
    ) -> Result<Vec<AuditLog>> {
        let query = AuditLogQuery {
            resource_type: Some(resource_type),
            resource_id: Some(resource_id),
            limit,
            ..Default::default()
        };
        
        self.query_logs(query).await
    }
    
    /// Get security-related audit logs
    pub async fn get_security_logs(&self, limit: Option<u32>) -> Result<Vec<AuditLog>> {
        let security_actions = vec![
            AuditAction::UnauthorizedAccess,
            AuditAction::SuspiciousActivity,
            AuditAction::SecurityPolicyViolation,
            AuditAction::LoginFailed,
        ];
        
        let query = AuditLogQuery {
            actions: Some(security_actions),
            limit,
            ..Default::default()
        };
        
        self.query_logs(query).await
    }
}

// Default implementation for AuditLogQuery
impl Default for AuditLogQuery {
    fn default() -> Self {
        AuditLogQuery {
            start_date: None,
            end_date: None,
            user_id: None,
            actions: None,
            severity: None,
            resource_type: None,
            resource_id: None,
            ip_address: None,
            limit: Some(100),
            offset: Some(0),
        }
    }
}
