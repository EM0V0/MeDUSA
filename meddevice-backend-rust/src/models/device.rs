// Device model and related data structures
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use validator::Validate;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceType {
    BloodPressureMonitor,
    GlucoseMeter,
    Thermometer,
    PulseOximeter,
    ECGMonitor,
    WeightScale,
    Other(String),
}

impl DeviceType {
    pub fn as_str(&self) -> &str {
        match self {
            DeviceType::BloodPressureMonitor => "blood_pressure_monitor",
            DeviceType::GlucoseMeter => "glucose_meter",
            DeviceType::Thermometer => "thermometer",
            DeviceType::PulseOximeter => "pulse_oximeter",
            DeviceType::ECGMonitor => "ecg_monitor",
            DeviceType::WeightScale => "weight_scale",
            DeviceType::Other(name) => name,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeviceStatus {
    Active,
    Inactive,
    Maintenance,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Device {
    pub id: Uuid,
    pub device_id: String,           // Physical device identifier
    pub name: String,                // Human-readable device name
    pub device_type: DeviceType,
    pub manufacturer: String,
    pub model: String,
    pub serial_number: String,
    pub firmware_version: Option<String>,
    pub status: DeviceStatus,
    pub is_approved: bool,           // Regulatory approval status
    pub owner_id: Option<Uuid>,      // User who owns this device
    pub assigned_patient_id: Option<Uuid>, // Patient currently assigned to device
    pub location: Option<String>,    // Physical location
    pub metadata: HashMap<String, serde_json::Value>, // Additional device-specific data
    pub last_seen: Option<DateTime<Utc>>,
    pub last_data_sync: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct CreateDeviceRequest {
    #[validate(length(min = 1, max = 100))]
    pub device_id: String,
    
    #[validate(length(min = 1, max = 200))]
    pub name: String,
    
    pub device_type: DeviceType,
    
    #[validate(length(min = 1, max = 100))]
    pub manufacturer: String,
    
    #[validate(length(min = 1, max = 100))]
    pub model: String,
    
    #[validate(length(min = 1, max = 100))]
    pub serial_number: String,
    
    pub firmware_version: Option<String>,
    pub location: Option<String>,
    pub metadata: Option<HashMap<String, serde_json::Value>>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateDeviceRequest {
    #[validate(length(min = 1, max = 200))]
    pub name: Option<String>,
    
    pub status: Option<DeviceStatus>,
    pub firmware_version: Option<String>,
    pub location: Option<String>,
    pub assigned_patient_id: Option<Uuid>,
    pub metadata: Option<HashMap<String, serde_json::Value>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceReading {
    pub id: Uuid,
    pub device_id: Uuid,
    pub patient_id: Option<Uuid>,
    pub reading_type: String,        // e.g., "blood_pressure", "glucose", "temperature"
    pub values: HashMap<String, f64>, // e.g., {"systolic": 120.0, "diastolic": 80.0}
    pub unit: String,                // e.g., "mmHg", "mg/dL", "°C"
    pub timestamp: DateTime<Utc>,
    pub quality_score: Option<f32>,  // Reading quality/confidence (0.0-1.0)
    pub notes: Option<String>,
    pub is_flagged: bool,           // Flagged for review
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct CreateReadingRequest {
    pub device_id: Uuid,
    pub patient_id: Option<Uuid>,
    
    #[validate(length(min = 1, max = 50))]
    pub reading_type: String,
    
    pub values: HashMap<String, f64>,
    
    #[validate(length(min = 1, max = 20))]
    pub unit: String,
    
    pub timestamp: Option<DateTime<Utc>>,
    pub quality_score: Option<f32>,
    pub notes: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceConnectionInfo {
    pub device_id: Uuid,
    pub connection_type: String,     // "bluetooth", "wifi", "usb", etc.
    pub connection_status: String,   // "connected", "disconnected", "pairing"
    pub signal_strength: Option<i32>, // For wireless connections
    pub last_connected: Option<DateTime<Utc>>,
    pub connection_metadata: HashMap<String, serde_json::Value>,
}

impl Device {
    /// Create a new device with default values
    pub fn new(
        device_id: String,
        name: String,
        device_type: DeviceType,
        manufacturer: String,
        model: String,
        serial_number: String,
    ) -> Self {
        let now = Utc::now();
        Device {
            id: Uuid::new_v4(),
            device_id,
            name,
            device_type,
            manufacturer,
            model,
            serial_number,
            firmware_version: None,
            status: DeviceStatus::Inactive,
            is_approved: false,
            owner_id: None,
            assigned_patient_id: None,
            location: None,
            metadata: HashMap::new(),
            last_seen: None,
            last_data_sync: None,
            created_at: now,
            updated_at: now,
        }
    }
    
    /// Check if device is currently active
    pub fn is_active(&self) -> bool {
        matches!(self.status, DeviceStatus::Active)
    }
    
    /// Check if device needs maintenance
    pub fn needs_maintenance(&self) -> bool {
        matches!(self.status, DeviceStatus::Maintenance | DeviceStatus::Error)
    }
    
    /// Update last seen timestamp
    pub fn update_last_seen(&mut self) {
        self.last_seen = Some(Utc::now());
        self.updated_at = Utc::now();
    }
}

impl DeviceReading {
    /// Create a new device reading
    pub fn new(
        device_id: Uuid,
        reading_type: String,
        values: HashMap<String, f64>,
        unit: String,
    ) -> Self {
        let now = Utc::now();
        DeviceReading {
            id: Uuid::new_v4(),
            device_id,
            patient_id: None,
            reading_type,
            values,
            unit,
            timestamp: now,
            quality_score: None,
            notes: None,
            is_flagged: false,
            created_at: now,
        }
    }
    
    /// Check if reading is within normal range (device-specific logic)
    pub fn is_normal(&self) -> Option<bool> {
        match self.reading_type.as_str() {
            "blood_pressure" => {
                if let (Some(&systolic), Some(&diastolic)) = 
                    (self.values.get("systolic"), self.values.get("diastolic")) {
                    Some(systolic < 140.0 && diastolic < 90.0 && systolic > 90.0 && diastolic > 60.0)
                } else {
                    None
                }
            }
            "glucose" => {
                if let Some(&glucose) = self.values.get("glucose") {
                    Some(glucose >= 70.0 && glucose <= 140.0) // mg/dL fasting
                } else {
                    None
                }
            }
            "temperature" => {
                if let Some(&temp) = self.values.get("temperature") {
                    Some(temp >= 36.1 && temp <= 37.2) // Celsius
                } else {
                    None
                }
            }
            _ => None,
        }
    }
}
