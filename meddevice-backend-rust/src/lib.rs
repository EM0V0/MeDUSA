// Core library for the medical device backend
// Contains shared modules used across all Lambda functions

pub mod config;
pub mod models;
pub mod services;
pub mod utils;
pub mod errors;

// Re-export commonly used types
pub use errors::{AppError, Result};
pub use config::Config;
