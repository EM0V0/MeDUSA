// S3 service for file storage operations
use aws_sdk_s3::{Client, Error as S3Error};
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::types::{ObjectCannedAcl, ServerSideEncryption};
use std::collections::HashMap;
use uuid::Uuid;
use chrono::{DateTime, Utc};

use crate::{Result, AppError, Config};

pub struct S3Service {
    client: Client,
    config: Config,
}

#[derive(Debug, Clone)]
pub struct UploadRequest {
    pub bucket: String,
    pub key: String,
    pub content: Vec<u8>,
    pub content_type: String,
    pub metadata: Option<HashMap<String, String>>,
    pub acl: Option<ObjectCannedAcl>,
}

#[derive(Debug, Clone)]
pub struct UploadResponse {
    pub bucket: String,
    pub key: String,
    pub url: String,
    pub etag: String,
    pub size: u64,
    pub uploaded_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct DownloadRequest {
    pub bucket: String,
    pub key: String,
    pub range: Option<String>, // For partial downloads
}

#[derive(Debug, Clone)]
pub struct DownloadResponse {
    pub content: Vec<u8>,
    pub content_type: String,
    pub metadata: HashMap<String, String>,
    pub last_modified: Option<DateTime<Utc>>,
    pub size: u64,
}

impl S3Service {
    /// Create a new S3 service instance
    pub fn new(client: Client, config: Config) -> Self {
        Self { client, config }
    }
    
    /// Upload a file to S3
    pub async fn upload(&self, request: UploadRequest) -> Result<UploadResponse> {
        let mut put_request = self.client
            .put_object()
            .bucket(&request.bucket)
            .key(&request.key)
            .body(ByteStream::from(request.content.clone()))
            .content_type(&request.content_type)
            .server_side_encryption(ServerSideEncryption::Aes256);
        
        // Add metadata if provided
        if let Some(metadata) = &request.metadata {
            for (key, value) in metadata {
                put_request = put_request.metadata(key, value);
            }
        }
        
        // Set ACL if provided
        if let Some(acl) = request.acl {
            put_request = put_request.acl(acl);
        }
        
        let result = put_request.send().await
            .map_err(|e| AppError::Storage(format!("Failed to upload to S3: {}", e)))?;
        
        let etag = result.e_tag().unwrap_or("").to_string();
        let url = self.get_object_url(&request.bucket, &request.key);
        
        Ok(UploadResponse {
            bucket: request.bucket,
            key: request.key,
            url,
            etag,
            size: request.content.len() as u64,
            uploaded_at: Utc::now(),
        })
    }
    
    /// Download a file from S3
    pub async fn download(&self, request: DownloadRequest) -> Result<DownloadResponse> {
        let mut get_request = self.client
            .get_object()
            .bucket(&request.bucket)
            .key(&request.key);
        
        // Add range if specified (for partial downloads)
        if let Some(range) = request.range {
            get_request = get_request.range(range);
        }
        
        let result = get_request.send().await
            .map_err(|e| AppError::Storage(format!("Failed to download from S3: {}", e)))?;
        
        // Extract metadata before consuming the body
        let content_type = result.content_type().unwrap_or("application/octet-stream").to_string();
        let size = result.content_length().unwrap_or(0) as u64;
        
        let mut metadata = HashMap::new();
        if let Some(meta) = result.metadata() {
            for (key, value) in meta {
                metadata.insert(key.clone(), value.clone());
            }
        }
        
        let last_modified = result.last_modified()
            .and_then(|dt| DateTime::from_timestamp(dt.secs(), dt.subsec_nanos()));
        
        // Now consume the body after extracting metadata
        let content = result.body.collect().await
            .map_err(|e| AppError::Storage(format!("Failed to read S3 object body: {}", e)))?
            .into_bytes()
            .to_vec();
        
        Ok(DownloadResponse {
            content,
            content_type,
            metadata,
            last_modified,
            size,
        })
    }
    
    /// Delete a file from S3
    pub async fn delete(&self, bucket: &str, key: &str) -> Result<()> {
        self.client
            .delete_object()
            .bucket(bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| AppError::Storage(format!("Failed to delete from S3: {}", e)))?;
        
        Ok(())
    }
    
    /// Generate a presigned URL for direct upload/download
    pub async fn generate_presigned_url(
        &self,
        bucket: &str,
        key: &str,
        expires_in_secs: u64,
        operation: &str, // "GET" or "PUT"
    ) -> Result<String> {
        let expires_in = std::time::Duration::from_secs(expires_in_secs);
        
        let presigned_request = match operation.to_uppercase().as_str() {
            "GET" => {
                let presigning_config = aws_sdk_s3::presigning::PresigningConfig::expires_in(expires_in)
                    .map_err(|e| AppError::Storage(format!("Failed to create presigning config: {}", e)))?;
                self.client
                    .get_object()
                    .bucket(bucket)
                    .key(key)
                    .presigned(presigning_config)
                    .await
                    .map_err(|e| AppError::Storage(format!("Failed to generate presigned GET URL: {}", e)))?
            }
            "PUT" => {
                let presigning_config = aws_sdk_s3::presigning::PresigningConfig::expires_in(expires_in)
                    .map_err(|e| AppError::Storage(format!("Failed to create presigning config: {}", e)))?;
                self.client
                    .put_object()
                    .bucket(bucket)
                    .key(key)
                    .presigned(presigning_config)
                    .await
                    .map_err(|e| AppError::Storage(format!("Failed to generate presigned PUT URL: {}", e)))?
            }
            _ => return Err(AppError::BadRequest("Invalid operation. Use GET or PUT".to_string())),
        };
        
        Ok(presigned_request.uri().to_string())
    }
    
    /// List objects in a bucket with prefix
    pub async fn list_objects(
        &self,
        bucket: &str,
        prefix: Option<&str>,
        max_keys: Option<i32>,
    ) -> Result<Vec<S3Object>> {
        let mut request = self.client
            .list_objects_v2()
            .bucket(bucket);
        
        if let Some(prefix) = prefix {
            request = request.prefix(prefix);
        }
        
        if let Some(max_keys) = max_keys {
            request = request.max_keys(max_keys);
        }
        
        let result = request.send().await
            .map_err(|e| AppError::Storage(format!("Failed to list S3 objects: {}", e)))?;
        
        let mut objects = Vec::new();
        for object in result.contents() {
            let s3_object = S3Object {
                key: object.key().unwrap_or("").to_string(),
                size: object.size().unwrap_or(0) as u64,
                last_modified: object.last_modified()
                    .and_then(|dt| DateTime::from_timestamp(dt.secs(), dt.subsec_nanos())),
                etag: object.e_tag().unwrap_or("").to_string(),
                storage_class: object.storage_class().map(|sc| sc.as_str().to_string()),
            };
            objects.push(s3_object);
        }
        
        Ok(objects)
    }
    
    /// Check if an object exists
    pub async fn object_exists(&self, bucket: &str, key: &str) -> Result<bool> {
        match self.client
            .head_object()
            .bucket(bucket)
            .key(key)
            .send()
            .await {
                Ok(_) => Ok(true),
                Err(e) => {
                    // Check if it's a "Not Found" error
                    if e.to_string().contains("404") || e.to_string().contains("NotFound") {
                        Ok(false)
                    } else {
                        Err(AppError::Storage(format!("Failed to check object existence: {}", e)))
                    }
                }
            }
    }
    
    /// Copy an object within S3 or between buckets
    pub async fn copy_object(
        &self,
        source_bucket: &str,
        source_key: &str,
        dest_bucket: &str,
        dest_key: &str,
    ) -> Result<()> {
        let copy_source = format!("{}/{}", source_bucket, source_key);
        
        self.client
            .copy_object()
            .copy_source(&copy_source)
            .bucket(dest_bucket)
            .key(dest_key)
            .server_side_encryption(ServerSideEncryption::Aes256)
            .send()
            .await
            .map_err(|e| AppError::Storage(format!("Failed to copy S3 object: {}", e)))?;
        
        Ok(())
    }
    
    // Convenience methods for different file types
    
    /// Upload a report file
    pub async fn upload_report(
        &self,
        report_id: Uuid,
        content: Vec<u8>,
        content_type: &str,
        filename: &str,
    ) -> Result<UploadResponse> {
        let key = format!("reports/{}/{}", report_id, filename);
        
        let mut metadata = HashMap::new();
        metadata.insert("report_id".to_string(), report_id.to_string());
        metadata.insert("uploaded_at".to_string(), Utc::now().to_rfc3339());
        
        let request = UploadRequest {
            bucket: self.config.reports_bucket.clone(),
            key,
            content,
            content_type: content_type.to_string(),
            metadata: Some(metadata),
            acl: Some(ObjectCannedAcl::Private),
        };
        
        self.upload(request).await
    }
    
    /// Upload device data file
    pub async fn upload_device_data(
        &self,
        device_id: Uuid,
        patient_id: Option<Uuid>,
        content: Vec<u8>,
        content_type: &str,
        filename: &str,
    ) -> Result<UploadResponse> {
        let key = match patient_id {
            Some(pid) => format!("device-data/{}/{}/{}", device_id, pid, filename),
            None => format!("device-data/{}/{}", device_id, filename),
        };
        
        let mut metadata = HashMap::new();
        metadata.insert("device_id".to_string(), device_id.to_string());
        if let Some(pid) = patient_id {
            metadata.insert("patient_id".to_string(), pid.to_string());
        }
        metadata.insert("uploaded_at".to_string(), Utc::now().to_rfc3339());
        
        let request = UploadRequest {
            bucket: self.config.device_data_bucket.clone(),
            key,
            content,
            content_type: content_type.to_string(),
            metadata: Some(metadata),
            acl: Some(ObjectCannedAcl::Private),
        };
        
        self.upload(request).await
    }
    
    /// Create backup of data
    pub async fn create_backup(
        &self,
        backup_name: &str,
        content: Vec<u8>,
    ) -> Result<UploadResponse> {
        let timestamp = Utc::now().format("%Y%m%d_%H%M%S").to_string();
        let key = format!("backups/{}/{}.backup", timestamp, backup_name);
        
        let mut metadata = HashMap::new();
        metadata.insert("backup_name".to_string(), backup_name.to_string());
        metadata.insert("created_at".to_string(), Utc::now().to_rfc3339());
        
        let request = UploadRequest {
            bucket: self.config.backup_bucket.clone(),
            key,
            content,
            content_type: "application/octet-stream".to_string(),
            metadata: Some(metadata),
            acl: Some(ObjectCannedAcl::Private),
        };
        
        self.upload(request).await
    }
    
    /// Helper method to construct object URL
    fn get_object_url(&self, bucket: &str, key: &str) -> String {
        format!("https://{}.s3.{}.amazonaws.com/{}", bucket, self.config.aws_region, key)
    }
}

#[derive(Debug, Clone)]
pub struct S3Object {
    pub key: String,
    pub size: u64,
    pub last_modified: Option<DateTime<Utc>>,
    pub etag: String,
    pub storage_class: Option<String>,
}
