// Report model and related data structures
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use validator::Validate;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ReportType {
    PatientSummary,
    DeviceReadings,
    ComplianceReport,
    AuditReport,
    TrendAnalysis,
    AlertSummary,
    Custom(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ReportStatus {
    Pending,
    Processing,
    Completed,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ReportFormat {
    PDF,
    Excel,
    CSV,
    JSON,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Report {
    pub id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub report_type: ReportType,
    pub format: ReportFormat,
    pub status: ReportStatus,
    
    // Report parameters
    pub parameters: ReportParameters,
    
    // Generated content
    pub file_url: Option<String>,       // S3 URL for the generated report file
    pub file_size: Option<u64>,         // File size in bytes
    pub page_count: Option<u32>,        // For PDF reports
    
    // Access control
    pub created_by: Uuid,               // User who created the report
    pub shared_with: Vec<Uuid>,         // Users who have access to this report
    pub is_public: bool,                // Whether report is accessible to all users with permission
    
    // Processing info
    pub processing_started_at: Option<DateTime<Utc>>,
    pub processing_completed_at: Option<DateTime<Utc>>,
    pub error_message: Option<String>,
    
    // System fields
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>, // When the report should be automatically deleted
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReportParameters {
    // Time range
    pub start_date: Option<DateTime<Utc>>,
    pub end_date: Option<DateTime<Utc>>,
    
    // Filters
    pub patient_ids: Option<Vec<Uuid>>,
    pub device_ids: Option<Vec<Uuid>>,
    pub doctor_ids: Option<Vec<Uuid>>,
    pub device_types: Option<Vec<String>>,
    pub reading_types: Option<Vec<String>>,
    
    // Report-specific options
    pub include_charts: bool,
    pub include_raw_data: bool,
    pub group_by: Option<String>,       // "patient", "device", "date", etc.
    pub aggregation: Option<String>,    // "daily", "weekly", "monthly"
    
    // Custom parameters
    pub custom_parameters: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct CreateReportRequest {
    #[validate(length(min = 1, max = 200))]
    pub title: String,
    
    pub description: Option<String>,
    pub report_type: ReportType,
    pub format: ReportFormat,
    pub parameters: ReportParameters,
    pub shared_with: Option<Vec<Uuid>>,
    pub is_public: Option<bool>,
    pub expires_in_days: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct ReportSummary {
    pub id: Uuid,
    pub title: String,
    pub report_type: ReportType,
    pub format: ReportFormat,
    pub status: ReportStatus,
    pub created_by: Uuid,
    pub created_at: DateTime<Utc>,
    pub processing_completed_at: Option<DateTime<Utc>>,
    pub file_size: Option<u64>,
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ReportData {
    pub metadata: ReportMetadata,
    pub data: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ReportMetadata {
    pub report_id: Uuid,
    pub title: String,
    pub generated_at: DateTime<Utc>,
    pub generated_by: String,           // User name
    pub parameters: ReportParameters,
    pub record_count: usize,
    pub data_sources: Vec<String>,      // Tables/sources used
}

// Specific report data structures
#[derive(Debug, Serialize, Deserialize)]
pub struct PatientSummaryData {
    pub patient: crate::models::Patient,
    pub recent_readings: Vec<crate::models::DeviceReading>,
    pub assigned_devices: Vec<crate::models::Device>,
    pub vital_trends: VitalTrends,
    pub alerts: Vec<Alert>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct VitalTrends {
    pub blood_pressure_trend: Option<TrendData>,
    pub glucose_trend: Option<TrendData>,
    pub weight_trend: Option<TrendData>,
    pub temperature_trend: Option<TrendData>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TrendData {
    pub values: Vec<TrendPoint>,
    pub trend_direction: TrendDirection, // "improving", "stable", "declining"
    pub average: f64,
    pub min: f64,
    pub max: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TrendPoint {
    pub timestamp: DateTime<Utc>,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrendDirection {
    Improving,
    Stable,
    Declining,
    Insufficient, // Not enough data
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Alert {
    pub id: Uuid,
    pub alert_type: String,
    pub severity: AlertSeverity,
    pub message: String,
    pub timestamp: DateTime<Utc>,
    pub is_acknowledged: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AlertSeverity {
    Low,
    Medium,
    High,
    Critical,
}

impl Report {
    /// Create a new report with default values
    pub fn new(
        title: String,
        report_type: ReportType,
        format: ReportFormat,
        parameters: ReportParameters,
        created_by: Uuid,
    ) -> Self {
        let now = Utc::now();
        Report {
            id: Uuid::new_v4(),
            title,
            description: None,
            report_type,
            format,
            status: ReportStatus::Pending,
            parameters,
            file_url: None,
            file_size: None,
            page_count: None,
            created_by,
            shared_with: Vec::new(),
            is_public: false,
            processing_started_at: None,
            processing_completed_at: None,
            error_message: None,
            created_at: now,
            updated_at: now,
            expires_at: None,
        }
    }
    
    /// Mark report as processing
    pub fn start_processing(&mut self) {
        self.status = ReportStatus::Processing;
        self.processing_started_at = Some(Utc::now());
        self.updated_at = Utc::now();
    }
    
    /// Mark report as completed
    pub fn complete_processing(&mut self, file_url: String, file_size: u64) {
        self.status = ReportStatus::Completed;
        self.file_url = Some(file_url);
        self.file_size = Some(file_size);
        self.processing_completed_at = Some(Utc::now());
        self.updated_at = Utc::now();
    }
    
    /// Mark report as failed
    pub fn fail_processing(&mut self, error: String) {
        self.status = ReportStatus::Failed;
        self.error_message = Some(error);
        self.updated_at = Utc::now();
    }
    
    /// Check if report is accessible by user
    pub fn is_accessible_by(&self, user_id: Uuid) -> bool {
        self.created_by == user_id || 
        self.shared_with.contains(&user_id) || 
        self.is_public
    }
    
    /// Check if report has expired
    pub fn is_expired(&self) -> bool {
        match self.expires_at {
            Some(expires_at) => Utc::now() > expires_at,
            None => false,
        }
    }
    
    /// Convert to summary view
    pub fn to_summary(&self) -> ReportSummary {
        ReportSummary {
            id: self.id,
            title: self.title.clone(),
            report_type: self.report_type.clone(),
            format: self.format.clone(),
            status: self.status.clone(),
            created_by: self.created_by,
            created_at: self.created_at,
            processing_completed_at: self.processing_completed_at,
            file_size: self.file_size,
            expires_at: self.expires_at,
        }
    }
}

impl Default for ReportParameters {
    fn default() -> Self {
        ReportParameters {
            start_date: None,
            end_date: None,
            patient_ids: None,
            device_ids: None,
            doctor_ids: None,
            device_types: None,
            reading_types: None,
            include_charts: true,
            include_raw_data: false,
            group_by: None,
            aggregation: None,
            custom_parameters: HashMap::new(),
        }
    }
}
