# MeDUSA Deployment Guide

**Author**: Zhicheng Sun  
**Last Updated**: February 2026

---

## Quick Start (5 Minutes)

### Prerequisites

```powershell
# 1. Install AWS CLI
winget install -e --id Amazon.AWSCLI

# 2. Install AWS SAM CLI
winget install -e --id Amazon.SAM-CLI

# 3. Configure AWS credentials
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (us-east-1)
```

### Deploy Backend

```powershell
cd MeDUSA/backend

# Build and deploy (first time - interactive)
sam build
sam deploy --guided

# Subsequent deployments
sam deploy
```

### Start Frontend

```powershell
cd MeDUSA/frontend
flutter pub get
flutter run -d chrome  # Web
# or
flutter run -d windows # Windows desktop
```

---

## Detailed Deployment

### 1. AWS Setup

#### 1.1 Create JWT Secret

```powershell
# Create a strong JWT secret in AWS Secrets Manager
aws secretsmanager create-secret `
    --name medusa/jwt `
    --secret-string '{"secret":"YOUR_STRONG_SECRET_HERE_MIN_32_CHARS"}'
```

#### 1.2 Verify SES Email

```powershell
# Verify sender email in SES
aws ses verify-email-identity --email-address your-email@gmail.com
```

#### 1.3 Create Additional DynamoDB Table (for raw sensor data)

```powershell
# Create sensor data table with streams enabled
aws dynamodb create-table `
    --table-name medusa-sensor-data `
    --attribute-definitions `
        AttributeName=device_id,AttributeType=S `
        AttributeName=timestamp,AttributeType=N `
    --key-schema `
        AttributeName=device_id,KeyType=HASH `
        AttributeName=timestamp,KeyType=RANGE `
    --billing-mode PAY_PER_REQUEST `
    --stream-specification StreamEnabled=true,StreamViewType=NEW_IMAGE `
    --tags Key=Project,Value=MeDUSA

# Create tremor analysis table
aws dynamodb create-table `
    --table-name medusa-tremor-analysis `
    --attribute-definitions `
        AttributeName=patient_id,AttributeType=S `
        AttributeName=timestamp,AttributeType=S `
    --key-schema `
        AttributeName=patient_id,KeyType=HASH `
        AttributeName=timestamp,KeyType=RANGE `
    --billing-mode PAY_PER_REQUEST `
    --tags Key=Project,Value=MeDUSA
```

### 2. Backend Deployment

#### 2.1 SAM Build & Deploy

```powershell
cd MeDUSA/backend

# Build (compiles Python dependencies)
sam build

# Deploy with stack name
sam deploy --stack-name medusa-api-v3-stack --region us-east-1 --capabilities CAPABILITY_IAM --resolve-s3
```

#### 2.2 Get API URL

```powershell
# Get deployed API URL
aws cloudformation describe-stacks `
    --stack-name medusa-api-v3-stack `
    --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" `
    --output text
```

### 3. Frontend Configuration

#### 3.1 Update API Endpoint

Edit `frontend/lib/core/constants/app_constants.dart`:

```dart
// Update these URLs with your deployed API Gateway URL
static const String _generalApiBaseUrl = 'https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod';
static const String _tremorApiBaseUrl = 'https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod';
```

#### 3.2 Build for Production

```powershell
# Web build
flutter build web --release

# Windows build
flutter build windows --release
```

---

## Test Accounts

### Existing Test Accounts

| Email | Password | Role | Notes |
|-------|----------|------|-------|
| `zsun54@jh.edu` | `Testhnp123!` | Patient/Doctor | MFA Enabled |
| `andysun12@outlook.com` | `Testhnp123!` | Patient/Doctor | MFA Enabled |

### Create New Test Account via API

```powershell
# Register new user
$body = @{
    email = "test@example.com"
    password = "SecurePass123!"
    role = "patient"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://YOUR-API.execute-api.us-east-1.amazonaws.com/Prod/api/v1/auth/register" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

### Create Test Account via Script

```powershell
cd MeDUSA/tools
python continuous_pi_simulator.py --create-test-user test@example.com
```

---

## Simulate Pi Data

### Real-time Simulation

```powershell
cd MeDUSA/tools

# Start continuous simulation (1 data point per second)
python continuous_pi_simulator.py --patient-id usr_XXXXXXXX --interval 1.0

# Or create user and simulate in one command
python continuous_pi_simulator.py --create-test-user patient@test.com --interval 1.0
```

### Generate Historical Data

```powershell
# Generate 7 days of historical data
python continuous_pi_simulator.py --patient-id usr_XXXXXXXX --generate-historical --days 7
```

### Quick Test Data

```powershell
# Generate 2 minutes of realtime-style data
python generate_realtime_simulation.py
```

---

## Development Mode vs Production Mode

### Development Mode

For quick testing without full security:

1. **Backend** - Run locally:
```powershell
cd MeDUSA/backend/backend-py
.\start_local.ps1
# API will be at http://localhost:8000
```

2. **Frontend** - Point to local backend:
```dart
// In app_constants.dart, temporarily change:
static const String _generalApiBaseUrl = 'http://localhost:8000';
```

3. **Quick Login** - Use test accounts directly (MFA optional in dev)

### Production Mode

Full security enabled:

1. **Backend** - Deployed on AWS Lambda with:
   - JWT secrets in AWS Secrets Manager
   - WAF protection enabled
   - DynamoDB encryption at rest
   - TLS 1.3 via API Gateway

2. **Frontend** - Uses production API URLs with:
   - Certificate pinning
   - Secure storage for tokens
   - Full input validation

---

## DynamoDB Tables Reference

### Optimized Schema

| Table | Partition Key | Sort Key | GSI | Purpose |
|-------|--------------|----------|-----|---------|
| `medusa-users-prod` | `id` (S) | - | `email-index` | User accounts |
| `medusa-devices-prod` | `id` (S) | - | `macAddress-index` | Device registry |
| `medusa-sessions-prod` | `sessionId` (S) | - | `deviceId-index`, `patientId-index`, `status-index` | Device sessions |
| `medusa-patient-profiles-prod` | `userId` (S) | - | `doctorId-index` | Patient metadata |
| `medusa-poses-prod` | `patientId` (S) | `id` (S) | - | Pose records |
| `medusa-refresh-tokens-prod` | `token` (S) | - | - | Refresh tokens (with TTL) |
| `medusa-sensor-data` | `device_id` (S) | `timestamp` (N) | - | Raw accelerometer data |
| `medusa-tremor-analysis` | `patient_id` (S) | `timestamp` (S) | - | Processed tremor features |

### Data Flow

```
Pi Device → medusa-sensor-data → Lambda (process) → medusa-tremor-analysis → App
```

---

## Troubleshooting

### Common Issues

1. **CORS Error in Browser**
   - Check API Gateway CORS settings
   - Verify `AllowOrigin` includes your domain

2. **401 Unauthorized**
   - Token expired - refresh or re-login
   - Check JWT_SECRET matches in Secrets Manager

3. **No Tremor Data Showing**
   - Verify patient_id matches logged-in user
   - Run simulator to generate test data
   - Check DynamoDB table has data

4. **SAM Deploy Fails**
   - Ensure AWS credentials are configured
   - Check S3 bucket permissions
   - Verify IAM capabilities

### Health Check

```powershell
# Check API health
Invoke-RestMethod -Uri "https://YOUR-API.execute-api.us-east-1.amazonaws.com/Prod/api/v1/admin/health"

# Expected response:
# { "ok": true, "ts": 1234567890, "security": { "replayProtection": true, "nonceEnabled": true } }
```

### Logs

```powershell
# View Lambda logs
aws logs tail /aws/lambda/medusa-api-v3 --follow

# View specific time range
aws logs filter-log-events `
    --log-group-name /aws/lambda/medusa-api-v3 `
    --start-time (Get-Date).AddHours(-1).ToUnixTimeMilliseconds()
```

---

## Security Checklist

- [ ] JWT secret is strong (32+ characters) and in Secrets Manager
- [ ] SES email is verified
- [ ] WAF is enabled on API Gateway
- [ ] DynamoDB encryption is enabled
- [ ] S3 bucket blocks public access
- [ ] CORS is restricted to specific origins in production
- [ ] No hardcoded credentials in code
- [ ] Audit logging is enabled

---

## Cost Estimation (AWS Free Tier Eligible)

| Service | Free Tier | Est. Monthly Cost |
|---------|-----------|-------------------|
| Lambda | 1M requests/month | $0 |
| API Gateway | 1M requests/month | $0 |
| DynamoDB | 25 GB storage, 25 WCU/RCU | $0 |
| S3 | 5 GB storage | $0 |
| SES | 62,000 emails/month | $0 |
| WAF | - | ~$5 |

**Total (Free Tier)**: ~$5/month (WAF only)

---

*For additional support, refer to the API Documentation in `doc_assets/API_DOCUMENTATION.md`*
