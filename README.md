# MeDUSA - Medical Data Unified System & Analytics

A professional Parkinson's disease tremor monitoring system with real-time data analysis, patient management, and device integration.

---

## 📚 Documentation

- **[API Documentation](API_DOCUMENTATION.md)** - Complete backend API reference with all endpoints

---

## 🚀 Quick Start

### Frontend (Flutter App)

```powershell
cd meddevice-app-flutter-main
flutter pub get
flutter run
```

**Automatically configured to connect to production APIs** ✅

### 后端 API

**生产环境（AWS Lambda）**
- API 地址: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1`
- 状态: ✅ 已部署运行
- 测试: 100% 通过 (8/8)

**本地测试（可选）**
```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend\backend-py
.\start_local.ps1
```

**更新云端部署**
```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\deploy.ps1
```

---

## 📋 系统架构

### Backend APIs

Production APIs are deployed on AWS:
- **General API**: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod`
- **Tremor API**: `https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod`

See **[API_DOCUMENTATION.md](API_DOCUMENTATION.md)** for complete endpoint reference.

---

## 🏗️ System Architecture

### Frontend (Flutter)
- **Framework**: Flutter 3.x
- **Platforms**: Web, Windows, Android, iOS
- **UI**: Material Design 3
- **State Management**: Riverpod + BLoC
- **Network**: Dio with TLS 1.3
- **Bluetooth**: flutter_blue_plus, win_ble

### Backend (Python)
- **Runtime**: AWS Lambda (Python 3.10, 3.11)
- **API Gateway**: REST API with JWT authentication
- **Database**: DynamoDB (on-demand billing)
- **Email**: AWS SES
- **Storage**: S3
- **Authentication**: JWT (bcrypt + PyJWT)

### Key Features
- ✅ Role-based access control (Admin, Doctor, Patient)
- ✅ Real-time tremor data processing
- ✅ Device-patient dynamic binding
- ✅ Statistical analysis and aggregation
- ✅ Secure password reset via email
- ✅ Bluetooth device integration

---

## 🔵 Bluetooth Capabilities

### Pages
- Device scanning (`device_scan_page.dart`)
- Device connection (`device_connection_page.dart`)
- WiFi provisioning (`wifi_provision_page.dart`)
- Windows BLE testing (`winble_test_page.dart`)

### Services
- Bluetooth adapter (`bluetooth_adapter.dart`)
- Bluetooth service (`bluetooth_service.dart`)
- WiFi helper service (`wifi_helper_bluetooth_service.dart`)

---

## 📊 Deployment Status

### Production Environment (AWS)
- **Status**: ✅ Operational
- **Region**: us-east-1
- **API Gateways**: 2 active
  - General API: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod`
  - Tremor API: `https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod`
- **Lambda Functions**: 7 deployed
  - medusa-api-v3 (Auth, User Management)
  - QueryTremorData (GET /api/v1/tremor/analysis)
  - GetTremorStatistics (GET /api/v1/tremor/statistics)
  - AssignPatientToDoctor (POST /api/v1/doctor/assign-patient)
  - GetDoctorPatients (GET /api/v1/doctor/patients)
  - ProcessSensorData (Real-time tremor processing)
  - + 1 more
- **DynamoDB Tables**: 7 active
  - medusa-users-prod
  - medusa-patient-profiles-prod
  - medusa-tremor-analysis
  - medusa-sensor-data
  - + 3 more

### Test Accounts
- **Patient**: kdu9@jh.edu / Testhnp123!
  - User ID: usr_8537f43b
  - Has 1H of recent tremor data (12 points)
  - Has 24H of historical data (100 points)
- **Doctor**: zhichengsun0508@outlook.com / Testhnp123!
  - User ID: usr_10b28691
  - Assigned patient: kdu9@jh.edu

### Infrastructure
```
API Gateway v3 → Lambda (medusa-api-v3) → DynamoDB (users-prod)
                                        → AWS SES (email)

Tremor API → Lambda (QueryTremorData) → DynamoDB (tremor-analysis)
          → Lambda (GetTremorStatistics)
          → Lambda (ProcessSensorData) → DynamoDB (sensor-data)
          
Doctor API → Lambda (GetDoctorPatients) → DynamoDB (patient-profiles-prod)
          → Lambda (AssignPatientToDoctor)
```

---

## 🛠️ Development

### Frontend Setup
```powershell
cd meddevice-app-flutter-main
flutter pub get
flutter run -d windows  # or web, android, ios
```

**Login Credentials:**
- Patient: kdu9@jh.edu / Testhnp123!
- Doctor: zhichengsun0508@outlook.com / Testhnp123!

### Backend Dependencies
```txt
# lambda_functions/requirements.txt
fastapi==0.115.2
mangum==0.17.0
boto3==1.35.36
bcrypt==4.2.0
PyJWT==2.9.0
uvicorn==0.32.0
numpy>=1.24.0
scipy>=1.10.0
```

---

## 📝 Change Log

### 2025-11-18 (Latest)
- ✅ **Patient Dashboard Fixed**
  - Fixed timestamp type mismatch (ISO 8601 ↔ Unix timestamps)
  - Fixed data model field mapping (tremor_score → tremorIndex)
  - Fixed tremor score display range (0-100 instead of 0-1)
  - Added actual time range calculation for charts
  - Eliminated chart overflow issues (290.h container)
  - Default time range set to 1H with fresh test data

- ✅ **Doctor-Patient Management**
  - Created AssignPatientToDoctor Lambda function
  - Created GetDoctorPatients Lambda function
  - Added doctor_patient_service.dart for API integration
  - Fixed DynamoDB schema issues (userId vs patient_id)
  - Doctor can now view and manage assigned patients

- ✅ **API Deployment & Testing**
  - Deployed GET /api/v1/doctor/patients endpoint
  - Deployed POST /api/v1/doctor/assign-patient endpoint
  - Deployed QueryTremorData Lambda
  - Deployed GetTremorStatistics Lambda
  - All endpoints returning 200 with real data

- ✅ **Data Generation**
  - Generated fresh test data for recent 1 hour
  - Created generate_recent_data.py script
  - 12 data points with realistic Parkinsonian episodes
  - Fixed timestamp format for DynamoDB compatibility

### 2025-11-14
- ✅ **Backend Migration**
  - CORS configuration fixed (API Gateway)
  - Login/registration connected to production APIs
  - Frontend cleanup (removed SSO, demo features)
  - RBAC framework deployed
  - Bluetooth functionality preserved

---

## 📞 Support

- **Repository**: https://github.com/EM0V0/MeDUSA
- **API Documentation**: [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
- **AWS Region**: us-east-1
- **Lambda Functions**: See `lambda_functions/README.md`

---

**MeDUSA © 2025 - Professional Medical Data System**
