# Medical Device Backend

A secure, enterprise-grade medical device data fusion and analysis backend built with Rust, designed for HIPAA-compliant medical applications and deployed on AWS Lambda.

## 🏥 Overview

This backend provides a comprehensive API for managing medical device data, patient information, and real-time health monitoring. It's built with Rust for maximum performance and security, deployed as serverless functions on AWS Lambda.

### Key Features

- **🔐 Zero-Trust Security Architecture** - WAF, VPC, encryption, audit logging
- **🏥 Medical-Grade Authentication** - Argon2id password hashing, JWT tokens
- **📊 Real-time Data Processing** - Device readings, patient monitoring
- **☁️ AWS Serverless** - Lambda, DynamoDB, S3 integration
- **🚀 High Performance** - Rust-based, sub-millisecond response times
- **🔒 HIPAA Compliant** - Comprehensive audit trails and data protection

## 🚀 Quick Start

### Prerequisites

- **Rust** (latest stable)
- **AWS CLI** (configured with appropriate permissions)
- **Git** (for version control)

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/EM0V0/MeDUSA_Rust.git
cd MeDUSA_Rust

# Install dependencies
cargo build --release
```

### 2. Configure AWS

```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

### 3. Deploy to AWS

**Simple Deployment (Recommended for testing):**
```bash
# Windows (PowerShell)
.\deploy-simple.bat

# Windows (CMD)
deploy-simple.bat
```

**Advanced Deployment (Production with full security):**
```bash
# Windows (PowerShell)
.\deploy.bat

# Windows (CMD)
deploy.bat
```

## ☁️ AWS Architecture

### Serverless Components

- **API Gateway** - RESTful API endpoints
- **Lambda Functions** - Serverless compute
- **DynamoDB** - NoSQL database
- **S3** - File storage
- **CloudWatch** - Logging and monitoring
- **X-Ray** - Distributed tracing

### Security Features

- **WAF** - Web Application Firewall
- **VPC** - Network isolation
- **KMS** - Key management
- **IAM** - Access control
- **Audit Logs** - Complete operation tracking

## 📋 API Endpoints

### Authentication
- `POST /api/v1/user/register` - User registration
- `POST /api/v1/user/login` - User login
- `POST /api/v1/user/logout` - User logout
- `POST /api/v1/user/refresh` - Refresh token
- `GET /api/v1/user/profile` - Get user profile
- `POST /api/v1/user/change-password` - Change password

### Patient Management
- `GET /api/v1/patients` - List patients
- `POST /api/v1/patients` - Create patient
- `GET /api/v1/patients/{id}` - Get patient details
- `PUT /api/v1/patients/{id}` - Update patient
- `DELETE /api/v1/patients/{id}` - Delete patient

### Device Management
- `GET /api/v1/devices` - List devices
- `POST /api/v1/devices` - Create device
- `GET /api/v1/devices/{id}` - Get device details
- `PUT /api/v1/devices/{id}` - Update device
- `DELETE /api/v1/devices/{id}` - Delete device

### Report Management
- `GET /api/v1/reports` - List reports
- `POST /api/v1/reports` - Create report
- `GET /api/v1/reports/{id}` - Get report details
- `GET /api/v1/reports/{id}/download` - Download report
- `DELETE /api/v1/reports/{id}` - Delete report

### System
- `GET /health` - Health check

## 🛠️ Development

### Project Structure

```
meddevice-backend-rust/
├── src/
│   ├── handlers/          # Lambda function handlers
│   │   ├── auth/          # Authentication handler
│   │   ├── patients/      # Patient management handler
│   │   ├── devices/       # Device management handler
│   │   ├── reports/       # Report management handler
│   │   └── admin/         # Admin operations handler
│   ├── models/            # Data models
│   │   ├── user.rs        # User model
│   │   ├── patient.rs     # Patient model
│   │   ├── device.rs      # Device model
│   │   ├── report.rs      # Report model
│   │   └── audit_log.rs   # Audit log model
│   ├── services/          # Business logic
│   │   ├── auth.rs        # Authentication service
│   │   ├── dynamodb.rs    # DynamoDB service
│   │   ├── s3.rs          # S3 service
│   │   ├── crypto.rs      # Cryptographic service
│   │   └── audit.rs       # Audit service
│   ├── config.rs          # Configuration management
│   ├── errors.rs          # Error handling
│   ├── lib.rs             # Library entry point
│   └── utils.rs           # Utility functions
├── template.yaml          # AWS SAM template
├── deploy.bat             # Advanced AWS deployment
├── deploy-simple.bat      # Simple AWS deployment
├── Cargo.toml             # Rust project configuration
└── README.md              # This file
```

### Building Lambda Functions

```bash
# Build all Lambda functions
cargo build --release

# Build specific function
cargo build --release --bin auth
cargo build --release --bin patients
cargo build --release --bin devices
cargo build --release --bin reports
cargo build --release --bin admin
```

### Environment Variables

Create a `.env` file for local development:

```env
# JWT Configuration
JWT_SECRET=your-64-byte-secret-key
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24
JWT_REFRESH_EXPIRATION_DAYS=7

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# DynamoDB Tables
USERS_TABLE=meddevice-users
PATIENTS_TABLE=meddevice-patients
DEVICES_TABLE=meddevice-devices
REPORTS_TABLE=meddevice-reports
AUDIT_LOGS_TABLE=meddevice-audit-logs

# S3 Buckets
FILES_BUCKET=meddevice-files
REPORTS_BUCKET=meddevice-reports
```

## 🔒 Security Features

### Authentication & Authorization
- **Argon2id Password Hashing** - Medical-grade password protection
- **JWT Tokens** - Secure token-based authentication
- **Role-Based Access Control** - Granular permissions
- **Two-Factor Authentication** - TOTP support

### Data Protection
- **Encryption at Rest** - KMS-managed encryption
- **Encryption in Transit** - TLS 1.3
- **Data Masking** - Sensitive data protection
- **Audit Logging** - Complete operation tracking

### Network Security
- **WAF Protection** - Web Application Firewall
- **VPC Isolation** - Network-level security
- **Private Subnets** - Database isolation
- **Security Groups** - Firewall rules

## 📊 Monitoring & Observability

### AWS CloudWatch
- **Logs** - Application and system logs
- **Metrics** - Performance and usage metrics
- **Alarms** - Automated alerting
- **Dashboards** - Visual monitoring

### AWS X-Ray
- **Distributed Tracing** - Request flow tracking
- **Performance Analysis** - Bottleneck identification
- **Error Tracking** - Issue diagnosis

### Cost Monitoring
- **Cost Explorer** - Usage analysis
- **Billing Alerts** - Budget notifications
- **Resource Tagging** - Cost allocation

## 🆘 Troubleshooting

### Common Issues

**AWS deployment fails:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name meddevice-backend-production

# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name meddevice-backend-production
```

**Lambda function errors:**
```bash
# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/meddevice

# Get recent logs
aws logs filter-log-events --log-group-name /aws/lambda/meddevice-auth --start-time $(date -d '1 hour ago' +%s)000
```

**API Gateway issues:**
```bash
# Check API Gateway
aws apigateway get-rest-apis

# Test API endpoint
curl -X GET https://your-api-id.execute-api.region.amazonaws.com/prod/health
```

### Debugging Steps

1. **Check CloudFormation stack status**
2. **Review CloudWatch logs for errors**
3. **Verify IAM permissions**
4. **Test API endpoints individually**
5. **Check DynamoDB table permissions**

## 📚 Documentation

- **API Reference** - Complete endpoint documentation
- **Security Guide** - Zero-trust architecture details
- **Deployment Guide** - AWS deployment instructions
- **Frontend Integration** - Flutter app connection guide

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Check the troubleshooting section above
- Review AWS CloudFormation events
- Check CloudWatch logs for errors
- Open an issue on GitHub

---

**Built with ❤️ for medical device data management**

*This backend is designed for production use in medical environments and includes comprehensive security, monitoring, and compliance features.*