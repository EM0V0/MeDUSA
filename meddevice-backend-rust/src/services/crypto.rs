// 高级加密服务 - 医疗级安全配置
use argon2::{Argon2, Config, Variant, Version};
use argon2::password_hash::{rand_core::OsRng, SaltString, PasswordHasher, PasswordVerifier, PasswordHash};
use crate::{Result, AppError};

pub struct CryptoService;

impl CryptoService {
    /// 创建医疗级Argon2id配置
    pub fn create_argon2_config() -> Config<'static> {
        Config {
            variant: Variant::Argon2id,    // 最安全的变体
            version: Version::Version13,   // 最新版本
            mem_cost: 65536,              // 64 MB内存 (医疗级安全)
            time_cost: 3,                 // 3次迭代 (平衡安全性和性能)
            lanes: 4,                     // 4个并行线程
            thread_mode: argon2::ThreadMode::Parallel,
            secret: &[],                  // 无额外密钥
            ad: &[],                      // 无关联数据
            hash_length: 32,              // 32字节输出
        }
    }
    
    /// 使用医疗级配置哈希密码
    pub fn hash_password_medical_grade(password: &str) -> Result<String> {
        let config = Self::create_argon2_config();
        let salt = SaltString::generate(&mut OsRng);
        
        let hash = argon2::hash_encoded(
            password.as_bytes(),
            salt.as_bytes(),
            &config
        ).map_err(|e| AppError::Internal(format!("Argon2 hashing failed: {}", e)))?;
        
        Ok(hash)
    }
    
    /// 验证医疗级哈希密码
    pub fn verify_password_medical_grade(password: &str, hash: &str) -> Result<bool> {
        match argon2::verify_encoded(hash, password.as_bytes()) {
            Ok(true) => Ok(true),
            Ok(false) => Ok(false),
            Err(_) => Ok(false), // 不暴露具体错误信息
        }
    }
    
    /// 生成加密强度的随机字符串
    pub fn generate_secure_random(length: usize) -> String {
        use rand::{Rng, distributions::Alphanumeric};
        
        let mut rng = rand::thread_rng();
        (0..length)
            .map(|_| rng.sample(Alphanumeric) as char)
            .collect()
    }
    
    /// 生成医疗级JWT密钥 (64字节)
    pub fn generate_medical_jwt_secret() -> String {
        use rand::RngCore;
        
        let mut key = vec![0u8; 64]; // 64字节 = 512位
        OsRng.fill_bytes(&mut key);
        base64::encode(key)
    }
    
    /// 验证JWT密钥强度
    pub fn validate_jwt_secret(secret: &str) -> Result<()> {
        if secret.len() < 64 {
            return Err(AppError::Internal(
                "JWT secret must be at least 64 characters for medical-grade security".to_string()
            ));
        }
        
        // 检查是否使用默认密钥
        if secret.contains("change-in-production") {
            return Err(AppError::Internal(
                "Default JWT secret detected. Must use secure random key in production".to_string()
            ));
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_argon2_hash_verify() {
        let password = "TestPassword123!";
        let hash = CryptoService::hash_password_medical_grade(password).unwrap();
        
        // 验证正确密码
        assert!(CryptoService::verify_password_medical_grade(password, &hash).unwrap());
        
        // 验证错误密码
        assert!(!CryptoService::verify_password_medical_grade("WrongPassword", &hash).unwrap());
    }
    
    #[test]
    fn test_jwt_secret_validation() {
        // 测试短密钥
        assert!(CryptoService::validate_jwt_secret("short").is_err());
        
        // 测试默认密钥
        assert!(CryptoService::validate_jwt_secret("change-in-production").is_err());
        
        // 测试有效密钥
        let valid_secret = CryptoService::generate_medical_jwt_secret();
        assert!(CryptoService::validate_jwt_secret(&valid_secret).is_ok());
    }
    
    #[test]
    fn test_secure_random_generation() {
        let random1 = CryptoService::generate_secure_random(32);
        let random2 = CryptoService::generate_secure_random(32);
        
        assert_eq!(random1.len(), 32);
        assert_eq!(random2.len(), 32);
        assert_ne!(random1, random2); // 应该不同
    }
}
