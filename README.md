# MeDUSA - Medical Data Unified System & Analytics

A professional Parkinson's disease tremor monitoring system with real-time data analysis, patient management, and device integration.

---

## 📚 Documentation

### Core Documentation
- **[API Documentation](doc_assets/API_DOCUMENTATION.md)** - Complete backend API reference
- **[Reproducibility Guide](doc_assets/Reproducibility_Guide.md)** - Guide for running the simulation and backend

### Regulatory Compliance (FDA Premarket)
- **[FDA Premarket Checklist](doc_assets/FDA_Premarket_Cybersecurity_Checklist.md)** - FDA cybersecurity expectations mapping
- **[Threat Model](doc_assets/Threat_Model.md)** - STRIDE threat analysis document
- **[ISO 14971 Risk Assessment](doc_assets/ISO14971_Risk_Assessment.md)** - Medical device risk management
- **[Security Traceability Matrix](doc_assets/Security_Traceability_Matrix.md)** - Requirements to controls mapping
- **[Security Controls Verification](doc_assets/Security_Controls_Verification.md)** - Control verification evidence
- **[SBOM Documentation](doc_assets/SBOM_Documentation.md)** - Software Bill of Materials

### Security Implementation
- **[Security Implementation Summary](doc_assets/Security_Implementation_Summary.md)** - Comprehensive overview of all security measures

### Educational Resources
- **[Cybersecurity Risk Assessment Worksheet](doc_assets/Cybersecurity_Risk_Assessment_Worksheet.md)** - Student exercise worksheet
- **[Security Audit Report](SECURITY_AUDIT.md)** - System security audit results

## 🔐 Test Accounts

Use these credentials to test the application immediately:

| Role | Email | Password | Status |
| :--- | :--- | :--- | :--- |
| **Patient/Doctor** | `zsun54@jh.edu` | `Testhnp123!` | Active (MFA Enabled) |
| **Patient/Doctor** | `andysun12@outlook.com` | `Testhnp123!` | Active (MFA Enabled) |

---

## 🚀 Quick Start

### Frontend (Flutter App)

```powershell
cd frontend
flutter pub get
flutter run
```

**Automatically configured to connect to production APIs** ✅

### Backend API

**Production (AWS Lambda)**
- API URL: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1`
- Status: ✅ Deployed & Running
- Test Coverage: 100% Passing (8/8)

**Local Testing (Optional)**
```powershell
cd backend/backend-py
.\start_local.ps1
```

**Deploy Updates**
```powershell
cd backend
.\deploy.ps1
```

---

## 📋 System Architecture

### Backend APIs

Production APIs are deployed on AWS:
- **General API**: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod`
- **Tremor API**: `https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod`

See **[API Documentation](doc_assets/API_DOCUMENTATION.md)** for complete endpoint reference.

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
- **Authentication**: JWT (PyJWT) with Argon2id for password hashing. Access tokens are signed with HS256 using a secret configured via the `JWT_SECRET` environment variable (production values are injected from AWS Secrets Manager; local/dev scripts provide a dev fallback). Refresh tokens are issued and short access token lifetimes are enforced.

### Key Features
- ✅ Role-based access control (Admin, Doctor, Patient)
- ✅ Real-time tremor data processing
- ✅ Device-patient dynamic binding
- ✅ Statistical analysis and aggregation
- ✅ Secure password reset via email
- ✅ Bluetooth device integration

---

### Implementation Notes (Security & Device Onboarding)

- **Authorizer / JWT verification**: The API uses application-layer JWT middleware (see `backend/backend-py/auth.py`) which extracts the bearer token from the Authorization header, removes the `Bearer ` prefix if present, and verifies the token using the `JWT_SECRET` and HS256. The middleware relies on application-level `role` claims for finer-grained access control. In production, `JWT_SECRET` should be stored and rotated in Secrets Manager (see `backend/template.yaml`), and the dev fallback must never be used for production deployments.

- **Device Onboarding / Registration**: The repo contains a simple demonstration script `tools/register_device.py` which writes a device item directly to the DynamoDB table `medusa-devices-prod` for testing. This is intended as a quick binding helper for development. Production device provisioning should rely on managed IoT provisioning (X.509 certs / Just-in-Time provisioning or a secure registration API), authenticated device identity, and TLS-protected channels rather than hard-coded scripts.

## 🔵 Bluetooth Capabilities

### Pages
- Device scanning (`device_scan_page.dart`)
- Device connection (`device_connection_page.dart`)
- WiFi provisioning (`wifi_provision_page.dart`)
- Windows BLE testing (`winble_test_page.dart`)
