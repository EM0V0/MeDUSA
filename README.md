# MeDUSA - Medical Device Universal Security Alignment

<div align="center">

![MeDUSA Logo](https://img.shields.io/badge/MeDUSA-Medical%20Device%20Security-blue?style=for-the-badge&logo=shield)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat-square&logo=python)
![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20DynamoDB-FF9900?style=flat-square&logo=amazonaws)
![License](https://img.shields.io/badge/License-Educational-green?style=flat-square)

**A Hands-On Platform for Medical Device Cybersecurity Education**

*Bridging the Gap Between Theory and Practice in Healthcare Security*

[Features](#features) • [Quick Start](#quick-start) • [Learning Modules](#learning-modules) • [Deployment](#deployment) • [Documentation](#documentation)

</div>

---

## Overview

**MeDUSA** (Medical Device Universal Security Alignment) is an open-source educational platform designed to teach medical device cybersecurity through hands-on experience. Built as a realistic Parkinson's disease tremor monitoring system, MeDUSA provides students with a safe, controlled environment to learn and practice security concepts critical to healthcare technology.

### Why MeDUSA?

The medical device industry faces a critical shortage of cybersecurity professionals who understand both healthcare requirements and security principles. Traditional classroom instruction often fails to provide the practical experience needed to develop real-world skills. MeDUSA addresses this gap by offering:

- **Real-World Simulation**: A fully functional medical device ecosystem
- **Security-First Design**: Implementations following FDA guidance and industry standards  
- **Comprehensive Curriculum**: From basic concepts to advanced penetration testing
- **Practical Labs**: Hands-on exercises with intentional vulnerabilities to discover and fix

---

## Features

### Clinical Features
| Feature | Description |
|---------|-------------|
| **Real-time Tremor Monitoring** | Live visualization of Parkinsonian tremor data with Demo Mode |
| **Patient Management** | Complete CRUD operations for patient records |
| **Device Integration** | BLE-based medical device pairing and data collection |
| **Data Analytics** | Statistical analysis with frequency domain processing |
| **Multi-Role Access** | Patient, Doctor, and Administrator interfaces |

### Security Features
| Feature | Implementation |
|---------|----------------|
| **Authentication** | JWT-based auth with mandatory MFA (TOTP) |
| **Password Security** | Argon2id hashing with NIST-compliant validation |
| **Encryption** | TLS 1.3 for all communications |
| **Access Control** | Role-Based Access Control (RBAC) |
| **Audit Logging** | Comprehensive security event tracking |
| **Replay Protection** | Nonce-based request validation |

### Platform Support
| Platform | BLE Support | Notes |
|----------|-------------|-------|
| **Web** | ✅ Web Bluetooth | Chrome/Edge/Opera, requires HTTPS |
| **Windows** | ✅ Full BLE | Scan, pair, WiFi provision |
| **Android** | ✅ FlutterBluePlus | Standard mobile BLE |
| **iOS** | ✅ FlutterBluePlus | Requires Mac for build |

> **Note on Web Bluetooth:** Web platform uses the Web Bluetooth API which requires user interaction to select devices (no background scanning). Only Chromium-based browsers are supported.

---

## Learning Modules

MeDUSA supports a progressive learning path for medical device security:

### 🔬 Security Education Center (Interactive)

Access the **Security Education Center** in the Admin dashboard to:

- **Explore 12 Security Features**: Toggle between secure/insecure modes to understand vulnerabilities
- **Interactive Demonstrations**: 
  - Password hashing comparison (MD5 vs SHA256 vs Argon2id)
  - JWT token structure breakdown
  - RBAC permission matrix
  - Replay attack prevention with nonces
- **Educational Console Logging**: Set `SECURITY_MODE=educational` for verbose security explanations
- **FDA Compliance Mapping**: Each feature links to FDA 2025 cybersecurity requirements

📖 See [Security_Education_Center_Guide.md](doc_assets/06_educational/Security_Education_Center_Guide.md) for detailed documentation.

### Module 1: Foundations
- Understanding medical device regulations (FDA, IEC 62443)
- Introduction to the STRIDE threat model
- Basic authentication and authorization concepts

### Module 2: Secure Development
- Implementing secure authentication flows
- Password policy enforcement
- Session management best practices

### Module 3: Threat Modeling
- Performing STRIDE analysis on MeDUSA
- Identifying attack surfaces in medical devices
- Creating threat model documentation

### Module 4: Vulnerability Assessment
- Discovering intentional vulnerabilities
- API security testing
- Bluetooth security analysis

### Module 5: Penetration Testing
- Conducting authorized security tests
- Exploiting common vulnerabilities
- Writing professional security reports

### Module 6: Compliance & Documentation
- FDA premarket cybersecurity requirements
- Creating Software Bill of Materials (SBOM)
- Risk assessment documentation (ISO 14971)

---

## Quick Start

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x or later
- [Python](https://www.python.org/downloads/) 3.10+
- [AWS CLI](https://aws.amazon.com/cli/) (for backend deployment)
- [Git](https://git-scm.com/)

### One-Command Setup (Windows)

```powershell
# Clone the repository
git clone https://github.com/EM0V0/MeDUSA.git
cd MeDUSA

# Quick start with demo mode
.\scripts\quick_start.ps1 -Mode dev
```

### Manual Setup

#### Frontend (Flutter App)
```powershell
cd frontend
flutter pub get
flutter run -d chrome    # For web
flutter run -d windows   # For Windows desktop
```

#### Backend (Local Development)
```powershell
cd backend/backend-py
pip install -r requirements.txt
.\start_local.ps1
```

### Demo Mode
No hardware device? No problem! MeDUSA includes a **Demo Mode** that generates realistic simulated tremor data:

1. Log in to the dashboard
2. Click the **"Demo Mode"** button
3. Watch real-time simulated tremor visualization
4. Click **"Trigger Episode"** to simulate a Parkinsonian tremor event

This is perfect for demonstrations, training sessions, and learning without physical devices.

---

## Deployment

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Flutter)                        │
│              Web │ Windows │ Android │ iOS                       │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ HTTPS/TLS 1.3
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AWS API Gateway                              │
│                    (REST API + JWT Auth)                         │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Lambda (Python)                         │
│        Authentication │ RBAC │ Business Logic │ Audit           │
└──────────┬──────────────────────┬───────────────────┬───────────┘
           │                      │                   │
           ▼                      ▼                   ▼
    ┌──────────────┐      ┌──────────────┐    ┌──────────────┐
    │  DynamoDB    │      │     S3       │    │   AWS SES    │
    │  (Users,     │      │  (Firmware,  │    │   (Email     │
    │   Devices,   │      │   Reports)   │    │   Service)   │
    │   Sessions)  │      │              │    │              │
    └──────────────┘      └──────────────┘    └──────────────┘
```

### AWS Deployment

#### Step 1: Configure AWS Credentials
```powershell
aws configure
# Enter your AWS Access Key ID, Secret, and region (us-east-1 recommended)
```

#### Step 2: Deploy Backend
```powershell
cd backend

# Build and deploy with SAM
sam build
sam deploy --guided

# Or use the deployment script
.\deploy.ps1
```

#### Step 3: Configure Email Service (AWS SES)
```powershell
# Verify sender email address
.\configure-ses.ps1 -Email "your-verified-email@domain.com"
```

#### Step 4: Update Frontend Configuration
Edit `frontend/lib/core/constants/app_constants.dart` with your API Gateway URL.

### Environment Variables (Required)

| Variable | Description |
|----------|-------------|
| `JWT_SECRET` | Secret key for JWT signing |
| `USERS_TABLE` | DynamoDB users table name |
| `SENDER_EMAIL` | Verified SES email address |
| `USE_SES` | Enable AWS SES (`true`/`false`) |

### Docker Compose Deployment

MeDUSA provides three Docker Compose configurations for different use cases:

#### Secure Mode (Production)
```bash
# All security features enabled
docker-compose -f docker-compose.secure.yml up -d
```

#### Educational Mode (Learning with Verbose Logging)
```bash
# Security enabled + detailed console explanations
docker-compose -f docker-compose.educational.yml up -d

# View security education logs
docker logs -f medusa-backend-educational
```

#### Insecure Mode (Vulnerability Demonstrations)
```bash
# ⚠️ EDUCATIONAL USE ONLY - Security features can be toggled off
docker-compose -f docker-compose.insecure.yml up -d
```

### 🔄 Runtime Mode Switching (No Restart Needed!)

Once the server is running, switch modes instantly via API or UI:

```bash
# Switch modes via API
curl -X POST "http://localhost:8080/api/v1/security/mode?mode=educational"
curl -X POST "http://localhost:8080/api/v1/security/mode?mode=insecure"
curl -X POST "http://localhost:8080/api/v1/security/mode?mode=secure"

# Toggle individual security features (educational/insecure mode only)
curl -X POST "http://localhost:8080/api/v1/security/features/password_hashing/toggle?enabled=false"

# Check real-time security status
curl "http://localhost:8080/api/v1/security/live-status"
```

Or use the **Security Lab UI** (Admin → Security Lab):
- Click **SECURE / EDUCATIONAL / INSECURE** buttons to switch modes
- Use **toggle switches** on each feature to enable/disable
- View real-time security score and console logging

See **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** for comprehensive deployment instructions.

---

## Documentation

### Core Documentation
| Document | Description |
|----------|-------------|
| [API Documentation](doc_assets/05_technical/API_DOCUMENTATION.md) | Complete REST API reference |
| [Deployment Guide](DEPLOYMENT_GUIDE.md) | Detailed deployment instructions |
| [Reproducibility Guide](doc_assets/04_testing/Reproducibility_Guide.md) | Setup and simulation guide |

### Security and Compliance
| Document | Description |
|----------|-------------|
| [FDA Premarket Checklist](doc_assets/01_premarket/FDA_Premarket_Cybersecurity_Checklist.md) | FDA cybersecurity requirements mapping |
| [Postmarket Cybersecurity Plan](doc_assets/03_postmarket/Postmarket_Cybersecurity_Plan.md) | TPLC postmarket management plan |
| [Preliminary Hazard Analysis](doc_assets/01_premarket/Preliminary_Hazard_Analysis.md) | PHA with STRIDE-based hazard identification |
| [Threat Model (STRIDE)](doc_assets/01_premarket/Threat_Model.md) | Comprehensive threat analysis |
| [ISO 14971 Risk Assessment](doc_assets/01_premarket/ISO14971_Risk_Assessment.md) | Medical device risk management |
| [Security Traceability Matrix](doc_assets/02_security/Security_Traceability_Matrix.md) | Requirements to controls mapping |
| [SBOM Documentation](doc_assets/01_premarket/SBOM_Documentation.md) | Software Bill of Materials |

### Educational Resources
| Document | Description |
|----------|-------------|
| [Cybersecurity Risk Worksheet](doc_assets/06_educational/Cybersecurity_Risk_Assessment_Worksheet.md) | Hands-on student exercise |
| [Security Audit Report](SECURITY_AUDIT.md) | Example security audit findings |
| [Security Controls Verification](doc_assets/02_security/Security_Controls_Verification.md) | Control verification evidence |
| [Testing Guide](doc_assets/04_testing/Testing_Guide.md) | Comprehensive testing procedures |

---

## Skills You'll Develop

By working with MeDUSA, students will gain practical skills in:

### Technical Skills
- Full-stack development (Flutter + Python + AWS)
- Implementing secure authentication systems
- Bluetooth Low Energy (BLE) communication
- Cloud deployment (AWS Lambda, DynamoDB, S3)
- Security testing and vulnerability assessment

### Domain Knowledge
- Medical device regulatory requirements
- FDA premarket cybersecurity guidance
- Healthcare data protection principles
- STRIDE threat modeling methodology
- Security documentation standards

### Professional Skills
- Writing security assessment reports
- Conducting risk analysis
- Communicating security findings to stakeholders
- Prioritizing remediation efforts

---

## Project Structure

```
MeDUSA/
├── frontend/                 # Flutter application
│   ├── lib/
│   │   ├── core/            # Constants, theme, routing
│   │   ├── features/        # Feature modules
│   │   │   ├── auth/        # Authentication
│   │   │   ├── dashboard/   # Dashboard views
│   │   │   ├── devices/     # Device management
│   │   │   └── patients/    # Patient management
│   │   └── shared/          # Shared services & widgets
│   └── test/                # Unit & widget tests
│
├── backend/
│   ├── backend-py/          # Python Lambda functions
│   │   ├── main.py          # API endpoints
│   │   ├── auth.py          # Authentication logic
│   │   ├── db.py            # Database operations
│   │   └── models.py        # Data models
│   ├── template.yaml        # SAM template
│   └── deploy.ps1           # Deployment script
│
├── doc_assets/              # Documentation & compliance
├── tools/                   # Utility & testing scripts
└── scripts/                 # Setup & automation scripts
```

---

## Contributing

MeDUSA welcomes contributions from educators and students:

1. **Report Issues**: Found a bug or have a suggestion? Open an issue!
2. **Add Features**: Fork the repo and submit a pull request
3. **Improve Documentation**: Help make learning materials clearer
4. **Create Labs**: Design new educational exercises

---

## Disclaimer

**MeDUSA is designed for educational purposes only.**

- This is NOT a certified medical device
- Do NOT use for actual patient care
- Some features intentionally include vulnerabilities for learning
- Always conduct security testing in authorized environments only

---

## License

This project is released for **educational and research purposes**.

---

## Author

<div align="center">

**Independently Developed by Zhicheng Sun**

MeDUSA was designed and built as a comprehensive educational platform to address the critical need for hands-on medical device cybersecurity training in academic settings.

</div>

---

## Acknowledgments

- **Michael Rushanan** and his *Medical Device Cybersecurity* course at Johns Hopkins University for providing the educational framework, learning materials, and expert guidance that shaped this platform
- Flutter and Dart teams for the excellent cross-platform framework
- AWS for cloud infrastructure services
- The medical device security research community
- Educators and students who provide valuable feedback

---

<div align="center">

**Ready to start your medical device security journey?**

[Get Started](#quick-start) | [Documentation](#documentation) | [Report Issue](https://github.com/EM0V0/MeDUSA/issues)

---

*MeDUSA - Empowering the Next Generation of Medical Device Security Professionals*

</div>
