// Patient model and related data structures
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc, NaiveDate};
use validator::Validate;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Gender {
    Male,
    Female,
    Other,
    PreferNotToSay,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum BloodType {
    #[serde(rename = "A+")]
    APositive,
    #[serde(rename = "A-")]
    ANegative,
    #[serde(rename = "B+")]
    BPositive,
    #[serde(rename = "B-")]
    BNegative,
    #[serde(rename = "AB+")]
    ABPositive,
    #[serde(rename = "AB-")]
    ABNegative,
    #[serde(rename = "O+")]
    OPositive,
    #[serde(rename = "O-")]
    ONegative,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Patient {
    pub id: Uuid,
    pub user_id: Option<Uuid>,       // Associated user account (if patient has login)
    pub patient_number: String,      // Hospital/clinic patient ID
    pub first_name: String,
    pub last_name: String,
    pub date_of_birth: NaiveDate,
    pub gender: Gender,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub address: Option<Address>,
    pub emergency_contact: Option<EmergencyContact>,
    
    // Medical information
    pub blood_type: Option<BloodType>,
    pub allergies: Vec<String>,
    pub medications: Vec<Medication>,
    pub medical_conditions: Vec<String>,
    pub height_cm: Option<f32>,
    pub weight_kg: Option<f32>,
    
    // Care team
    pub primary_doctor_id: Option<Uuid>,
    pub assigned_devices: Vec<Uuid>,
    
    // System fields
    pub is_active: bool,
    pub metadata: HashMap<String, serde_json::Value>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Address {
    pub street: String,
    pub city: String,
    pub state: String,
    pub postal_code: String,
    pub country: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmergencyContact {
    pub name: String,
    pub relationship: String,
    pub phone: String,
    pub email: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Medication {
    pub name: String,
    pub dosage: String,
    pub frequency: String,
    pub prescribing_doctor: Option<String>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub is_active: bool,
}

#[derive(Debug, Deserialize, Validate)]
pub struct CreatePatientRequest {
    #[validate(length(min = 1, max = 50))]
    pub patient_number: String,
    
    #[validate(length(min = 1, max = 100))]
    pub first_name: String,
    
    #[validate(length(min = 1, max = 100))]
    pub last_name: String,
    
    pub date_of_birth: NaiveDate,
    pub gender: Gender,
    
    #[validate(length(min = 10, max = 15))]
    pub phone: Option<String>,
    
    #[validate(email)]
    pub email: Option<String>,
    
    pub address: Option<Address>,
    pub emergency_contact: Option<EmergencyContact>,
    pub blood_type: Option<BloodType>,
    pub allergies: Option<Vec<String>>,
    pub medical_conditions: Option<Vec<String>>,
    pub height_cm: Option<f32>,
    pub weight_kg: Option<f32>,
    pub primary_doctor_id: Option<Uuid>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdatePatientRequest {
    #[validate(length(min = 1, max = 100))]
    pub first_name: Option<String>,
    
    #[validate(length(min = 1, max = 100))]
    pub last_name: Option<String>,
    
    #[validate(length(min = 10, max = 15))]
    pub phone: Option<String>,
    
    #[validate(email)]
    pub email: Option<String>,
    
    pub address: Option<Address>,
    pub emergency_contact: Option<EmergencyContact>,
    pub blood_type: Option<BloodType>,
    pub allergies: Option<Vec<String>>,
    pub medications: Option<Vec<Medication>>,
    pub medical_conditions: Option<Vec<String>>,
    pub height_cm: Option<f32>,
    pub weight_kg: Option<f32>,
    pub primary_doctor_id: Option<Uuid>,
    pub is_active: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PatientSummary {
    pub id: Uuid,
    pub patient_number: String,
    pub first_name: String,
    pub last_name: String,
    pub date_of_birth: NaiveDate,
    pub gender: Gender,
    pub primary_doctor_id: Option<Uuid>,
    pub is_active: bool,
    pub last_reading_date: Option<DateTime<Utc>>,
    pub device_count: usize,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PatientVitalSigns {
    pub patient_id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub blood_pressure: Option<BloodPressureReading>,
    pub heart_rate: Option<f32>,
    pub temperature: Option<f32>,
    pub oxygen_saturation: Option<f32>,
    pub glucose: Option<f32>,
    pub weight: Option<f32>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BloodPressureReading {
    pub systolic: f32,
    pub diastolic: f32,
    pub pulse: Option<f32>,
}

impl Patient {
    /// Create a new patient with default values
    pub fn new(
        patient_number: String,
        first_name: String,
        last_name: String,
        date_of_birth: NaiveDate,
        gender: Gender,
    ) -> Self {
        let now = Utc::now();
        Patient {
            id: Uuid::new_v4(),
            user_id: None,
            patient_number,
            first_name,
            last_name,
            date_of_birth,
            gender,
            phone: None,
            email: None,
            address: None,
            emergency_contact: None,
            blood_type: None,
            allergies: Vec::new(),
            medications: Vec::new(),
            medical_conditions: Vec::new(),
            height_cm: None,
            weight_kg: None,
            primary_doctor_id: None,
            assigned_devices: Vec::new(),
            is_active: true,
            metadata: HashMap::new(),
            created_at: now,
            updated_at: now,
        }
    }
    
    /// Get patient's full name
    pub fn full_name(&self) -> String {
        format!("{} {}", self.first_name, self.last_name)
    }
    
    /// Calculate patient's age in years
    pub fn age(&self) -> i32 {
        let today = Utc::now().date_naive();
        let years = today.years_since(self.date_of_birth).unwrap_or(0);
        years as i32
    }
    
    /// Calculate BMI if height and weight are available
    pub fn bmi(&self) -> Option<f32> {
        match (self.height_cm, self.weight_kg) {
            (Some(height), Some(weight)) => {
                let height_m = height / 100.0;
                Some(weight / (height_m * height_m))
            }
            _ => None,
        }
    }
    
    /// Get active medications
    pub fn active_medications(&self) -> Vec<&Medication> {
        self.medications.iter().filter(|m| m.is_active).collect()
    }
    
    /// Convert to summary view
    pub fn to_summary(&self) -> PatientSummary {
        PatientSummary {
            id: self.id,
            patient_number: self.patient_number.clone(),
            first_name: self.first_name.clone(),
            last_name: self.last_name.clone(),
            date_of_birth: self.date_of_birth,
            gender: self.gender.clone(),
            primary_doctor_id: self.primary_doctor_id,
            is_active: self.is_active,
            last_reading_date: None, // Would be populated from device readings
            device_count: self.assigned_devices.len(),
        }
    }
}
