// DynamoDB service for all database operations
use aws_sdk_dynamodb::{Client, Error as DynamoError};
use aws_sdk_dynamodb::types::{AttributeValue, Select};
use std::collections::HashMap;
use uuid::Uuid;
use chrono::{DateTime, Utc};

use crate::{Result, AppError, Config};
use crate::models::*;

// Helper functions for manual DynamoDB serialization
fn user_to_item(user: &User) -> HashMap<String, AttributeValue> {
    let mut item = HashMap::new();
    item.insert("id".to_string(), AttributeValue::S(user.id.to_string()));
    item.insert("email".to_string(), AttributeValue::S(user.email.clone()));
    item.insert("first_name".to_string(), AttributeValue::S(user.first_name.clone()));
    item.insert("last_name".to_string(), AttributeValue::S(user.last_name.clone()));
    item.insert("password_hash".to_string(), AttributeValue::S(user.password_hash.clone()));
    item.insert("role".to_string(), AttributeValue::S(user.role.as_str().to_string()));
    item.insert("is_active".to_string(), AttributeValue::Bool(user.is_active));
    item.insert("is_verified".to_string(), AttributeValue::Bool(user.is_verified));
    item.insert("two_factor_enabled".to_string(), AttributeValue::Bool(user.two_factor_enabled));
    item.insert("created_at".to_string(), AttributeValue::S(user.created_at.to_rfc3339()));
    item.insert("updated_at".to_string(), AttributeValue::S(user.updated_at.to_rfc3339()));
    if let Some(last_login) = &user.last_login {
        item.insert("last_login".to_string(), AttributeValue::S(last_login.to_rfc3339()));
    }
    if let Some(two_factor_secret) = &user.two_factor_secret {
        item.insert("two_factor_secret".to_string(), AttributeValue::S(two_factor_secret.clone()));
    }
    if let Some(license_number) = &user.license_number {
        item.insert("license_number".to_string(), AttributeValue::S(license_number.clone()));
    }
    if let Some(department) = &user.department {
        item.insert("department".to_string(), AttributeValue::S(department.clone()));
    }
    if let Some(patient_id) = &user.patient_id {
        item.insert("patient_id".to_string(), AttributeValue::S(patient_id.clone()));
    }
    item
}

fn item_to_user(item: HashMap<String, AttributeValue>) -> Result<User> {
    let role_str = string_from_attr(&item, "role")?;
    let role = match role_str.as_str() {
        "admin" => UserRole::Admin,
        "doctor" => UserRole::Doctor,
        "patient" => UserRole::Patient,
        "technician" => UserRole::Technician,
        _ => return Err(AppError::Internal("Invalid role".to_string())),
    };
    
    Ok(User {
        id: uuid_from_attr(&item, "id")?,
        email: string_from_attr(&item, "email")?,
        first_name: string_from_attr(&item, "first_name")?,
        last_name: string_from_attr(&item, "last_name")?,
        password_hash: string_from_attr(&item, "password_hash")?,
        role,
        is_active: bool_from_attr(&item, "is_active")?,
        is_verified: bool_from_attr(&item, "is_verified").unwrap_or(false),
        two_factor_enabled: bool_from_attr(&item, "two_factor_enabled").unwrap_or(false),
        two_factor_secret: optional_string_from_attr(&item, "two_factor_secret")?,
        created_at: datetime_from_attr(&item, "created_at")?,
        updated_at: datetime_from_attr(&item, "updated_at")?,
        last_login: optional_datetime_from_attr(&item, "last_login")?,
        license_number: optional_string_from_attr(&item, "license_number")?,
        department: optional_string_from_attr(&item, "department")?,
        patient_id: optional_string_from_attr(&item, "patient_id")?,
    })
}

// Helper functions for AttributeValue conversion
fn string_from_attr(item: &HashMap<String, AttributeValue>, key: &str) -> Result<String> {
    match item.get(key) {
        Some(AttributeValue::S(s)) => Ok(s.clone()),
        _ => Err(AppError::Internal(format!("Missing or invalid string attribute: {}", key))),
    }
}

fn bool_from_attr(item: &HashMap<String, AttributeValue>, key: &str) -> Result<bool> {
    match item.get(key) {
        Some(AttributeValue::Bool(b)) => Ok(*b),
        _ => Err(AppError::Internal(format!("Missing or invalid bool attribute: {}", key))),
    }
}

fn uuid_from_attr(item: &HashMap<String, AttributeValue>, key: &str) -> Result<Uuid> {
    match item.get(key) {
        Some(AttributeValue::S(s)) => Uuid::parse_str(s).map_err(|e| AppError::Internal(format!("Invalid UUID: {}", e))),
        _ => Err(AppError::Internal(format!("Missing or invalid UUID attribute: {}", key))),
    }
}

fn datetime_from_attr(item: &HashMap<String, AttributeValue>, key: &str) -> Result<DateTime<Utc>> {
    match item.get(key) {
        Some(AttributeValue::S(s)) => DateTime::parse_from_rfc3339(s)
            .map(|dt| dt.with_timezone(&Utc))
            .map_err(|e| AppError::Internal(format!("Invalid datetime: {}", e))),
        _ => Err(AppError::Internal(format!("Missing or invalid datetime attribute: {}", key))),
    }
}

fn optional_datetime_from_attr(item: &HashMap<String, AttributeValue>, key: &str) -> Result<Option<DateTime<Utc>>> {
    match item.get(key) {
        Some(AttributeValue::S(s)) => Ok(Some(DateTime::parse_from_rfc3339(s)
            .map(|dt| dt.with_timezone(&Utc))
            .map_err(|e| AppError::Internal(format!("Invalid datetime: {}", e)))?)),
        _ => Ok(None),
    }
}

fn optional_string_from_attr(item: &HashMap<String, AttributeValue>, key: &str) -> Result<Option<String>> {
    match item.get(key) {
        Some(AttributeValue::S(s)) => Ok(Some(s.clone())),
        _ => Ok(None),
    }
}

// Generic placeholder functions for now - these would need proper implementation
fn patient_to_item(patient: &Patient) -> HashMap<String, AttributeValue> {
    let mut item = HashMap::new();
    item.insert("id".to_string(), AttributeValue::S(patient.id.to_string()));
    // Add other fields as needed
    item
}

fn item_to_patient(item: HashMap<String, AttributeValue>) -> Result<Patient> {
    // Placeholder - would need proper implementation
    Err(AppError::Internal("Patient deserialization not implemented".to_string()))
}

fn device_to_item(_device: &Device) -> HashMap<String, AttributeValue> {
    let mut item = HashMap::new();
    // Placeholder implementation
    item
}

fn item_to_device(_item: HashMap<String, AttributeValue>) -> Result<Device> {
    Err(AppError::Internal("Device deserialization not implemented".to_string()))
}

fn report_to_item(_report: &Report) -> HashMap<String, AttributeValue> {
    let mut item = HashMap::new();
    // Placeholder implementation
    item
}

fn item_to_report(_item: HashMap<String, AttributeValue>) -> Result<Report> {
    Err(AppError::Internal("Report deserialization not implemented".to_string()))
}

fn audit_log_to_item(_audit_log: &AuditLog) -> HashMap<String, AttributeValue> {
    let mut item = HashMap::new();
    // Placeholder implementation
    item
}

fn item_to_audit_log(_item: HashMap<String, AttributeValue>) -> Result<AuditLog> {
    Err(AppError::Internal("AuditLog deserialization not implemented".to_string()))
}

#[derive(Clone)]
pub struct DynamoDbService {
    client: Client,
    config: Config,
}

impl DynamoDbService {
    /// Create a new DynamoDB service instance
    pub fn new(client: Client, config: Config) -> Self {
        Self { client, config }
    }
    
    // User operations
    
    /// Create a new user
    pub async fn create_user(&self, user: &User) -> Result<()> {
        let item = user_to_item(user);
        
        self.client
            .put_item()
            .table_name(&self.config.users_table)
            .set_item(Some(item))
            .condition_expression("attribute_not_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to create user: {}", e)))?;
        
        Ok(())
    }
    
    /// Get user by ID
    pub async fn get_user(&self, user_id: Uuid) -> Result<Option<User>> {
        let result = self.client
            .get_item()
            .table_name(&self.config.users_table)
            .key("id", AttributeValue::S(user_id.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to get user: {}", e)))?;
        
        match result.item {
            Some(item) => {
                let user: User = item_to_user(item)?;
                Ok(Some(user))
            }
            None => Ok(None),
        }
    }
    
    /// Get user by email
    pub async fn get_user_by_email(&self, email: &str) -> Result<Option<User>> {
        let result = self.client
            .query()
            .table_name(&self.config.users_table)
            .index_name("email-index") // Assumes GSI on email
            .key_condition_expression("email = :email")
            .expression_attribute_values(":email", AttributeValue::S(email.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to query user by email: {}", e)))?;
        
        if let Some(items) = result.items {
            if let Some(item) = items.into_iter().next() {
                let user: User = item_to_user(item)?;
                return Ok(Some(user));
            }
        }
        
        Ok(None)
    }
    
    /// Update user
    pub async fn update_user(&self, user: &User) -> Result<()> {
        let item = user_to_item(user);
        
        self.client
            .put_item()
            .table_name(&self.config.users_table)
            .set_item(Some(item))
            .condition_expression("attribute_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to update user: {}", e)))?;
        
        Ok(())
    }
    
    /// Delete user (soft delete by setting is_active = false)
    pub async fn delete_user(&self, user_id: Uuid) -> Result<()> {
        self.client
            .update_item()
            .table_name(&self.config.users_table)
            .key("id", AttributeValue::S(user_id.to_string()))
            .update_expression("SET is_active = :inactive, updated_at = :now")
            .expression_attribute_values(":inactive", AttributeValue::Bool(false))
            .expression_attribute_values(":now", AttributeValue::S(Utc::now().to_rfc3339()))
            .condition_expression("attribute_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to delete user: {}", e)))?;
        
        Ok(())
    }
    
    // Patient operations
    
    /// Create a new patient
    pub async fn create_patient(&self, patient: &Patient) -> Result<()> {
        let item = patient_to_item(patient);
        
        self.client
            .put_item()
            .table_name(&self.config.patients_table)
            .set_item(Some(item))
            .condition_expression("attribute_not_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to create patient: {}", e)))?;
        
        Ok(())
    }
    
    /// Get patient by ID
    pub async fn get_patient(&self, patient_id: Uuid) -> Result<Option<Patient>> {
        let result = self.client
            .get_item()
            .table_name(&self.config.patients_table)
            .key("id", AttributeValue::S(patient_id.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to get patient: {}", e)))?;
        
        match result.item {
            Some(item) => {
                let patient: Patient = item_to_patient(item)?;
                Ok(Some(patient))
            }
            None => Ok(None),
        }
    }
    
    /// Get patients by doctor ID
    pub async fn get_patients_by_doctor(&self, doctor_id: Uuid) -> Result<Vec<Patient>> {
        let result = self.client
            .query()
            .table_name(&self.config.patients_table)
            .index_name("primary-doctor-index") // Assumes GSI on primary_doctor_id
            .key_condition_expression("primary_doctor_id = :doctor_id")
            .expression_attribute_values(":doctor_id", AttributeValue::S(doctor_id.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to query patients by doctor: {}", e)))?;
        
        let mut patients = Vec::new();
        if let Some(items) = result.items {
            for item in items {
                let patient: Patient = item_to_patient(item)?;
                patients.push(patient);
            }
        }
        
        Ok(patients)
    }
    
    /// Update patient
    pub async fn update_patient(&self, patient: &Patient) -> Result<()> {
        let item = patient_to_item(patient);
        
        self.client
            .put_item()
            .table_name(&self.config.patients_table)
            .set_item(Some(item))
            .condition_expression("attribute_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to update patient: {}", e)))?;
        
        Ok(())
    }
    
    // Device operations
    
    /// Create a new device
    pub async fn create_device(&self, device: &Device) -> Result<()> {
        let item = device_to_item(device);
        
        self.client
            .put_item()
            .table_name(&self.config.devices_table)
            .set_item(Some(item))
            .condition_expression("attribute_not_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to create device: {}", e)))?;
        
        Ok(())
    }
    
    /// Get device by ID
    pub async fn get_device(&self, device_id: Uuid) -> Result<Option<Device>> {
        let result = self.client
            .get_item()
            .table_name(&self.config.devices_table)
            .key("id", AttributeValue::S(device_id.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to get device: {}", e)))?;
        
        match result.item {
            Some(item) => {
                let device: Device = item_to_device(item)?;
                Ok(Some(device))
            }
            None => Ok(None),
        }
    }
    
    /// Get devices by patient ID
    pub async fn get_devices_by_patient(&self, patient_id: Uuid) -> Result<Vec<Device>> {
        let result = self.client
            .query()
            .table_name(&self.config.devices_table)
            .index_name("assigned-patient-index") // Assumes GSI on assigned_patient_id
            .key_condition_expression("assigned_patient_id = :patient_id")
            .expression_attribute_values(":patient_id", AttributeValue::S(patient_id.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to query devices by patient: {}", e)))?;
        
        let mut devices = Vec::new();
        if let Some(items) = result.items {
            for item in items {
                let device: Device = item_to_device(item)?;
                devices.push(device);
            }
        }
        
        Ok(devices)
    }
    
    /// Update device
    pub async fn update_device(&self, device: &Device) -> Result<()> {
        let item = device_to_item(device);
        
        self.client
            .put_item()
            .table_name(&self.config.devices_table)
            .set_item(Some(item))
            .condition_expression("attribute_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to update device: {}", e)))?;
        
        Ok(())
    }
    
    // Device reading operations (stored in devices table with sort key)
    
    /// Create a new device reading
    pub async fn create_device_reading(&self, reading: &DeviceReading) -> Result<()> {
        // Store readings in a separate partition with device_id as PK and timestamp as SK
        let mut item = HashMap::new();
        item.insert("pk".to_string(), AttributeValue::S(format!("DEVICE#{}", reading.device_id)));
        item.insert("sk".to_string(), AttributeValue::S(format!("READING#{}", reading.timestamp.timestamp_millis())));
        item.insert("id".to_string(), AttributeValue::S(reading.id.to_string()));
        item.insert("device_id".to_string(), AttributeValue::S(reading.device_id.to_string()));
        
        if let Some(patient_id) = reading.patient_id {
            item.insert("patient_id".to_string(), AttributeValue::S(patient_id.to_string()));
        }
        
        item.insert("reading_type".to_string(), AttributeValue::S(reading.reading_type.clone()));
        item.insert("unit".to_string(), AttributeValue::S(reading.unit.clone()));
        item.insert("timestamp".to_string(), AttributeValue::S(reading.timestamp.to_rfc3339()));
        item.insert("is_flagged".to_string(), AttributeValue::Bool(reading.is_flagged));
        item.insert("created_at".to_string(), AttributeValue::S(reading.created_at.to_rfc3339()));
        
        // Store values as a map
        let mut values_map = HashMap::new();
        for (key, value) in &reading.values {
            values_map.insert(key.clone(), AttributeValue::N(value.to_string()));
        }
        item.insert("values".to_string(), AttributeValue::M(values_map));
        
        if let Some(quality) = reading.quality_score {
            item.insert("quality_score".to_string(), AttributeValue::N(quality.to_string()));
        }
        
        if let Some(notes) = &reading.notes {
            item.insert("notes".to_string(), AttributeValue::S(notes.clone()));
        }
        
        self.client
            .put_item()
            .table_name(&self.config.devices_table)
            .set_item(Some(item))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to create device reading: {}", e)))?;
        
        Ok(())
    }
    
    /// Get device readings for a device within a time range
    pub async fn get_device_readings(
        &self, 
        device_id: Uuid, 
        start_time: Option<DateTime<Utc>>,
        end_time: Option<DateTime<Utc>>,
        limit: Option<i32>
    ) -> Result<Vec<DeviceReading>> {
        let mut query = self.client
            .query()
            .table_name(&self.config.devices_table)
            .key_condition_expression("pk = :pk");
        
        let mut expression_values = HashMap::new();
        expression_values.insert(":pk".to_string(), AttributeValue::S(format!("DEVICE#{}", device_id)));
        
        // Add time range conditions if provided
        if start_time.is_some() || end_time.is_some() {
            let mut condition = "pk = :pk".to_string();
            
            if let Some(start) = start_time {
                condition.push_str(" AND sk >= :start_time");
                expression_values.insert(":start_time".to_string(), 
                    AttributeValue::S(format!("READING#{}", start.timestamp_millis())));
            }
            
            if let Some(end) = end_time {
                condition.push_str(" AND sk <= :end_time");
                expression_values.insert(":end_time".to_string(), 
                    AttributeValue::S(format!("READING#{}", end.timestamp_millis())));
            }
            
            query = query.key_condition_expression(condition);
        }
        
        query = query.set_expression_attribute_values(Some(expression_values));
        
        if let Some(limit) = limit {
            query = query.limit(limit);
        }
        
        let result = query.send().await
            .map_err(|e| AppError::Database(format!("Failed to query device readings: {}", e)))?;
        
        let mut readings = Vec::new();
        if let Some(items) = result.items {
            for item in items {
                // Parse the DynamoDB item back to DeviceReading
                if let Ok(reading) = self.parse_device_reading_item(item) {
                    readings.push(reading);
                }
            }
        }
        
        Ok(readings)
    }
    
    // Report operations
    
    /// Create a new report
    pub async fn create_report(&self, report: &Report) -> Result<()> {
        let item = report_to_item(report);
        
        self.client
            .put_item()
            .table_name(&self.config.reports_table)
            .set_item(Some(item))
            .condition_expression("attribute_not_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to create report: {}", e)))?;
        
        Ok(())
    }
    
    /// Get report by ID
    pub async fn get_report(&self, report_id: Uuid) -> Result<Option<Report>> {
        let result = self.client
            .get_item()
            .table_name(&self.config.reports_table)
            .key("id", AttributeValue::S(report_id.to_string()))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to get report: {}", e)))?;
        
        match result.item {
            Some(item) => {
                let report: Report = item_to_report(item)?;
                Ok(Some(report))
            }
            None => Ok(None),
        }
    }
    
    /// Update report
    pub async fn update_report(&self, report: &Report) -> Result<()> {
        let item = report_to_item(report);
        
        self.client
            .put_item()
            .table_name(&self.config.reports_table)
            .set_item(Some(item))
            .condition_expression("attribute_exists(id)")
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to update report: {}", e)))?;
        
        Ok(())
    }
    
    // Audit log operations
    
    /// Create audit log entry
    pub async fn create_audit_log(&self, audit_log: &AuditLog) -> Result<()> {
        let item = audit_log_to_item(audit_log);
        
        self.client
            .put_item()
            .table_name(&self.config.audit_logs_table)
            .set_item(Some(item))
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to create audit log: {}", e)))?;
        
        Ok(())
    }
    
    /// Query audit logs with filters
    pub async fn query_audit_logs(&self, query: &AuditLogQuery) -> Result<Vec<AuditLog>> {
        // Implementation would depend on the audit logs table structure
        // This is a simplified version - in practice, you'd want more sophisticated querying
        
        let result = self.client
            .scan()
            .table_name(&self.config.audit_logs_table)
            .limit(query.limit.unwrap_or(100) as i32)
            .send()
            .await
            .map_err(|e| AppError::Database(format!("Failed to query audit logs: {}", e)))?;
        
        let mut logs = Vec::new();
        if let Some(items) = result.items {
            for item in items {
                let log: AuditLog = item_to_audit_log(item)?;
                logs.push(log);
            }
        }
        
        Ok(logs)
    }
    
    // Helper methods
    
    /// Parse DynamoDB item to DeviceReading
    fn parse_device_reading_item(&self, item: HashMap<String, AttributeValue>) -> Result<DeviceReading> {
        // This is a simplified parser - in practice, you'd want more robust error handling
        let id = match item.get("id") {
            Some(AttributeValue::S(s)) => Uuid::parse_str(s)?,
            _ => return Err(AppError::Database("Invalid reading ID".to_string())),
        };
        
        let device_id = match item.get("device_id") {
            Some(AttributeValue::S(s)) => Uuid::parse_str(s)?,
            _ => return Err(AppError::Database("Invalid device ID".to_string())),
        };
        
        let reading_type = match item.get("reading_type") {
            Some(AttributeValue::S(s)) => s.clone(),
            _ => return Err(AppError::Database("Invalid reading type".to_string())),
        };
        
        let unit = match item.get("unit") {
            Some(AttributeValue::S(s)) => s.clone(),
            _ => return Err(AppError::Database("Invalid unit".to_string())),
        };
        
        let timestamp = match item.get("timestamp") {
            Some(AttributeValue::S(s)) => DateTime::parse_from_rfc3339(s)?.with_timezone(&Utc),
            _ => return Err(AppError::Database("Invalid timestamp".to_string())),
        };
        
        let created_at = match item.get("created_at") {
            Some(AttributeValue::S(s)) => DateTime::parse_from_rfc3339(s)?.with_timezone(&Utc),
            _ => return Err(AppError::Database("Invalid created_at".to_string())),
        };
        
        let is_flagged = match item.get("is_flagged") {
            Some(AttributeValue::Bool(b)) => *b,
            _ => false,
        };
        
        let mut values = HashMap::new();
        if let Some(AttributeValue::M(map)) = item.get("values") {
            for (key, value) in map {
                if let AttributeValue::N(n) = value {
                    if let Ok(num) = n.parse::<f64>() {
                        values.insert(key.clone(), num);
                    }
                }
            }
        }
        
        let patient_id = item.get("patient_id")
            .and_then(|v| if let AttributeValue::S(s) = v { Uuid::parse_str(s).ok() } else { None });
        
        let quality_score = item.get("quality_score")
            .and_then(|v| if let AttributeValue::N(n) = v { n.parse::<f32>().ok() } else { None });
        
        let notes = item.get("notes")
            .and_then(|v| if let AttributeValue::S(s) = v { Some(s.clone()) } else { None });
        
        Ok(DeviceReading {
            id,
            device_id,
            patient_id,
            reading_type,
            values,
            unit,
            timestamp,
            quality_score,
            notes,
            is_flagged,
            created_at,
        })
    }
}
