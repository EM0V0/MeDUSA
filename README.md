# MeDUSA - Medical Device Management System

Professional medical device management platform with Flutter frontend and Rust AWS Lambda backend.

## 🏥 Overview

A complete medical device data management, patient monitoring, and healthcare analytics platform designed for professional healthcare environments.

**Key Features:**
- Cross-platform Flutter web application
- Serverless Rust backend on AWS Lambda
- Medical device compliance and security
- Patient monitoring and device management
- End-to-end encryption and audit trails

## 🚀 Quick Start

### Prerequisites

You need the following tools installed:

```bash
# Install Flutter SDK
winget install Google.Flutter

# Install Rust and Cargo Lambda
winget install Rustlang.Rustup
cargo install cargo-lambda

# Install AWS CLI and SAM CLI
winget install Amazon.AWSCLI
winget install Amazon.SAM-CLI
```

**Verify installations:**
```bash
flutter --version
cargo --version
aws --version
sam --version
```

### 1. Clone and Setup

```bash
git clone <your-repository-url>
cd meddevice

# Setup Flutter frontend
cd meddevice-app-flutter-main
flutter pub get
cd ..
```

### 2. Configure AWS Credentials

**Important**: You must configure AWS credentials before deployment.

**Option A: AWS SSO (Recommended for organizations)**
```bash
aws configure sso
aws sso login
aws sts get-caller-identity  # Verify
```

**Option B: Access Keys**
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-east-1)
aws sts get-caller-identity  # Verify
```

### 3. Deploy Backend

Navigate to the backend directory and use SAM CLI:

```bash
cd meddevice-backend-rust

# Build the application
sam build

# Deploy to AWS (first time deployment)
sam deploy --guided

# For subsequent deployments
sam deploy
```

**After successful deployment, you will see output like:**
```
CloudFormation outputs from deployed stack
---------------------------------------------------------
Outputs
---------------------------------------------------------
Key                 MedDeviceApiUrl
Description         API Gateway endpoint URL for MedDevice backend
Value               https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/development
---------------------------------------------------------
```

**Copy this API URL - you'll need it for frontend configuration.**

### 4. Configure Frontend

Update the frontend to use your deployed API:

1. Open `meddevice-app-flutter-main/lib/core/constants/app_constants.dart`
2. Replace the `_productionBaseUrl` with your API Gateway URL:

```dart
static const String _productionBaseUrl = 'https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/development';
```

### 5. Run Frontend

```bash
cd meddevice-app-flutter-main
flutter run -d chrome
```

The application will open in Chrome. You can now test registration and login functionality.

## 🔧 Development

### Project Structure
```
meddevice/
├── meddevice-app-flutter-main/     # Flutter web application
│   ├── lib/
│   │   ├── features/               # Feature modules (auth, patients, devices)
│   │   ├── shared/                 # Shared services and widgets
│   │   └── core/                   # Core configuration and constants
│   └── pubspec.yaml
├── meddevice-backend-rust/         # Rust Lambda backend
│   ├── src/                        # Source code
│   ├── template-simple.yaml        # SAM CloudFormation template
│   └── Cargo.toml
└── scripts/
    └── backend/
        └── deploy.ps1               # PowerShell deployment script
```

### Backend API Endpoints

After deployment, your API will provide these endpoints:

```
Authentication:
POST /auth/register       # User registration
POST /auth/login         # User login
POST /auth/logout        # User logout
POST /auth/refresh       # Refresh tokens

Patient Management:
GET  /patients           # List patients
POST /patients           # Create patient
GET  /patients/{id}      # Get patient details

Device Management:
GET  /devices            # List devices
POST /devices            # Create device
GET  /devices/{id}       # Get device details

Reports:
GET  /reports            # List reports
POST /reports            # Create report
GET  /reports/{id}       # Get specific report

Admin:
GET  /admin/users        # List users (admin only)
POST /admin/users        # Create user (admin only)
```

### User Roles

The system supports four user roles:
- **Admin**: Full system access
- **Doctor**: Patient management and medical records
- **Technician**: Device management and maintenance
- **Patient**: Limited access to own records

### Technology Stack

**Frontend:**
- Flutter 3.x with Dart
- Responsive web design
- TLS 1.3 secure networking
- JWT authentication

**Backend:**
- Rust with AWS Lambda runtime
- DynamoDB for data storage
- S3 for file storage
- API Gateway for HTTP routing
- CloudFormation for infrastructure

**Security:**
- JWT token authentication
- Argon2id password hashing
- TLS 1.3 encryption
- CORS protection
- Medical-grade security compliance

## 🔒 Security & Compliance

This platform is designed with medical device security standards in mind:

- **HIPAA Compliance**: Secure handling of patient data
- **Medical Device Standards**: Following IEC 62304 guidelines  
- **Data Encryption**: End-to-end encryption for sensitive data
- **Audit Trails**: Complete logging of all system activities
- **Access Controls**: Role-based permission system

## 🛠 Deployment Configurations

### Environment Variables

The backend uses these environment variables (managed by SAM):
- `ENVIRONMENT`: deployment environment (development/staging/production)
- `USERS_TABLE`: DynamoDB users table name
- `PATIENTS_TABLE`: DynamoDB patients table name
- `DEVICES_TABLE`: DynamoDB devices table name
- `REPORTS_TABLE`: DynamoDB reports table name
- `AUDIT_LOGS_TABLE`: DynamoDB audit logs table name

### AWS Resources Created

The deployment creates:
- **Lambda Functions**: Auth, Patient, Device, Report, Admin handlers
- **DynamoDB Tables**: Users, Patients, Devices, Reports, Audit Logs
- **S3 Buckets**: Report storage, device data, backups
- **API Gateway**: RESTful API endpoint
- **IAM Roles**: Least-privilege access for Lambda functions

## 📝 Configuration Notes

### Frontend Configuration

The Flutter app is configured for medical-grade security:
- TLS 1.3 only connections
- Certificate pinning (update certificates as needed)
- Request/response encryption
- Secure token storage

### Backend Configuration

The Rust backend includes:
- Medical-grade JWT secret generation
- Secure password hashing with Argon2id
- Database encryption at rest
- Comprehensive audit logging

## 🐛 Troubleshooting

### Common Issues

**CORS Errors:**
- Ensure your API Gateway has proper CORS configuration
- Check that the frontend URL matches CORS allowed origins

**Authentication Errors:**
- Verify JWT secret is properly configured
- Check user roles match backend expectations

**Database Errors:**
- Ensure DynamoDB tables are created successfully
- Verify IAM permissions for Lambda functions

**Build Errors:**
- Make sure all prerequisites are installed
- Use `sam build` before deployment
- Check Rust compilation targets

### Getting Help

1. Check CloudWatch logs for backend errors
2. Use browser developer tools for frontend debugging
3. Verify AWS resource creation in CloudFormation console
4. Test API endpoints directly using tools like Postman

## 📋 License

This project is designed for medical device environments. Please ensure compliance with relevant medical device regulations in your jurisdiction.

---

**Note**: This is medical device software. Development and deployment must follow relevant medical device regulations and security standards.