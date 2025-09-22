// Data models for the medical device backend
// Defines all the data structures used throughout the application

pub mod user;
pub mod device;
pub mod patient;
pub mod report;
pub mod audit_log;

// Re-export all model types for convenience
pub use user::*;
pub use device::*;
pub use patient::*;
pub use report::*;
pub use audit_log::*;
