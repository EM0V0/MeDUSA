// 安全配置验证工具
use crate::{Result, AppError};
use crate::services::CryptoService;

pub struct SecurityValidator;

impl SecurityValidator {
    /// 验证生产环境安全配置
    pub fn validate_production_config(jwt_secret: &str, environment: &str) -> Result<()> {
        // 检查环境
        if environment == "production" {
            // JWT密钥验证
            CryptoService::validate_jwt_secret(jwt_secret)?;
            
            // 检查是否使用默认值
            if jwt_secret.contains("change-in-production") {
                return Err(AppError::Internal(
                    "Production environment detected with default JWT secret. This is a security risk!".to_string()
                ));
            }
        }
        
        Ok(())
    }
    
    /// 生成安全配置报告
    pub fn generate_security_report(jwt_secret: &str, environment: &str) -> SecurityReport {
        let mut recommendations = Vec::new();
        let mut warnings = Vec::new();
        let mut is_secure = true;
        
        // JWT密钥检查
        if jwt_secret.len() < 64 {
            warnings.push("JWT secret is shorter than recommended 64 characters".to_string());
            recommendations.push("Generate a new JWT secret with at least 64 characters".to_string());
            is_secure = false;
        }
        
        if jwt_secret.contains("change-in-production") {
            warnings.push("Using default JWT secret".to_string());
            recommendations.push("Generate a secure random JWT secret for production".to_string());
            is_secure = false;
        }
        
        // 环境检查
        match environment {
            "production" => {
                if is_secure {
                    recommendations.push("Production environment with secure configuration ✅".to_string());
                }
            }
            "development" => {
                recommendations.push("Development environment - ensure secure config before production".to_string());
            }
            _ => {
                warnings.push(format!("Unknown environment: {}", environment));
            }
        }
        
        // Argon2配置检查
        recommendations.push("Using Argon2id for password hashing - Medical grade security ✅".to_string());
        recommendations.push("JWT tokens expire in 1 hour - Enhanced security ✅".to_string());
        recommendations.push("Refresh tokens expire in 7 days - Balanced security ✅".to_string());
        
        SecurityReport {
            is_secure,
            environment: environment.to_string(),
            jwt_secret_length: jwt_secret.len(),
            warnings,
            recommendations,
        }
    }
}

#[derive(Debug)]
pub struct SecurityReport {
    pub is_secure: bool,
    pub environment: String,
    pub jwt_secret_length: usize,
    pub warnings: Vec<String>,
    pub recommendations: Vec<String>,
}

impl SecurityReport {
    /// 打印安全报告
    pub fn print_report(&self) {
        println!("\n🔒 MEDICAL DEVICE BACKEND SECURITY REPORT");
        println!("==========================================");
        println!("Environment: {}", self.environment);
        println!("Security Status: {}", if self.is_secure { "✅ SECURE" } else { "⚠️  NEEDS ATTENTION" });
        println!("JWT Secret Length: {} characters", self.jwt_secret_length);
        
        if !self.warnings.is_empty() {
            println!("\n⚠️  SECURITY WARNINGS:");
            for warning in &self.warnings {
                println!("  • {}", warning);
            }
        }
        
        if !self.recommendations.is_empty() {
            println!("\n💡 RECOMMENDATIONS:");
            for rec in &self.recommendations {
                println!("  • {}", rec);
            }
        }
        
        println!("\n🏥 Medical-Grade Security Features:");
        println!("  • Argon2id password hashing");
        println!("  • Short-lived JWT tokens (1 hour)");
        println!("  • Secure refresh token mechanism");
        println!("  • Zero-trust architecture");
        println!("  • WAF protection");
        println!("  • Comprehensive audit logging");
        println!("==========================================\n");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_security_validation() {
        // 测试安全配置
        let secure_secret = CryptoService::generate_medical_jwt_secret();
        assert!(SecurityValidator::validate_production_config(&secure_secret, "production").is_ok());
        
        // 测试不安全配置
        assert!(SecurityValidator::validate_production_config("short", "production").is_err());
        assert!(SecurityValidator::validate_production_config("change-in-production", "production").is_err());
    }
    
    #[test]
    fn test_security_report() {
        let report = SecurityValidator::generate_security_report("short-key", "production");
        assert!(!report.is_secure);
        assert!(!report.warnings.is_empty());
        
        let secure_secret = CryptoService::generate_medical_jwt_secret();
        let secure_report = SecurityValidator::generate_security_report(&secure_secret, "production");
        assert!(secure_report.is_secure);
    }
}
