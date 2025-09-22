# Configuration Guide

This document explains how to configure the MeDUSA Medical Device Management System for your environment.

## Backend Configuration

### 1. AWS Credentials

Before deploying, ensure AWS credentials are configured:

```bash
# Option 1: AWS Configure (access keys)
aws configure

# Option 2: AWS SSO (recommended for organizations)
aws configure sso
aws sso login
```

### 2. Environment Variables (Optional)

Copy the environment template:
```bash
cd meddevice-backend-rust
cp .env.example .env
```

Edit `.env` with your specific values:
- `AWS_REGION`: Your preferred AWS region (default: us-east-1)
- `ENVIRONMENT`: development, staging, or production
- `JWT_SECRET`: Will be auto-generated if not provided

### 3. SAM Configuration

The `samconfig.toml` file contains deployment parameters. Key settings:

```toml
stack_name = "meddevice-backend-development"  # Change for different environments
region = "us-east-1"                          # Update to your region
```

For production deployments, update the parameter overrides:
```toml
parameter_overrides = "Environment=production EnableWAF=true EnableVPC=true"
```

## Frontend Configuration

### 1. API Endpoint Configuration

After deploying the backend, you'll get an API Gateway URL. Update the frontend:

1. Copy the environment template:
   ```bash
   cd meddevice-app-flutter-main
   cp .env.example .env
   ```

2. Edit `.env` with your API endpoint:
   ```
   API_BASE_URL=https://your-api-id.execute-api.us-east-1.amazonaws.com/development
   ```

3. Or directly edit `lib/core/constants/app_constants.dart`:
   ```dart
   static const String _productionBaseUrl = 'https://your-api-id.execute-api.us-east-1.amazonaws.com/development';
   ```

## Deployment Environments

### Development
- Single AWS account
- Simplified security settings
- Debug logging enabled

### Staging
- Production-like environment
- Enhanced security features
- Performance monitoring

### Production
- Full security features enabled
- WAF and VPC configuration
- Comprehensive audit logging
- Multi-AZ deployment

## Security Configuration

### JWT Secrets
- Auto-generated during first deployment
- Stored in AWS Systems Manager Parameter Store
- 64-character cryptographically secure secrets

### CORS Configuration
- Development: Allows all origins (`*`)
- Production: Restrict to specific domains

### TLS Configuration
- Frontend enforces TLS 1.3
- Certificate pinning for API endpoints
- Medical-grade encryption standards

## Environment-Specific Settings

### Development
```toml
Environment = "development"
EnableWAF = false
EnableVPC = false
AllowedOrigins = "*"
```

### Production
```toml
Environment = "production" 
EnableWAF = true
EnableVPC = true
AllowedOrigins = "https://yourdomain.com"
```

## Database Configuration

DynamoDB tables are automatically created with these naming patterns:
- Users: `{environment}-meddevice-users`
- Patients: `{environment}-meddevice-patients`
- Devices: `{environment}-meddevice-devices`
- Reports: `{environment}-meddevice-reports`
- Audit Logs: `{environment}-meddevice-audit-logs`

## S3 Bucket Configuration

S3 buckets for file storage:
- Reports: `{environment}-meddevice-reports-{account-id}`
- Device Data: `{environment}-meddevice-device-data-{account-id}`
- Backups: `{environment}-meddevice-backups-{account-id}`

## Monitoring and Logging

### CloudWatch Integration
- Lambda function logs
- API Gateway access logs
- DynamoDB metrics
- Security event logging

### Audit Trails
- All user actions logged
- Medical device access tracking
- Compliance reporting capabilities

## Troubleshooting

### Common Configuration Issues

1. **AWS Credentials Not Found**
   ```bash
   aws sts get-caller-identity  # Verify credentials
   ```

2. **SAM Build Failures**
   ```bash
   sam --version  # Verify SAM CLI installation
   cargo --version  # Verify Rust installation
   ```

3. **CORS Errors**
   - Update AllowedOrigins in samconfig.toml
   - Redeploy backend after changes

4. **Database Access Errors**
   - Verify IAM permissions in CloudFormation
   - Check DynamoDB table names match environment

## Security Best Practices

1. **Never commit secrets to git**
   - Use .env files (ignored by git)
   - Use AWS Systems Manager for production secrets

2. **Rotate JWT secrets regularly**
   - Generate new secrets for production deployments
   - Update SAM parameters

3. **Use least privilege IAM policies**
   - Lambda functions have minimal required permissions
   - Separate roles for different environments

4. **Enable audit logging**
   - All medical device access is logged
   - Compliance reporting available

## Contact

For configuration assistance, refer to the main README.md or contact the development team.