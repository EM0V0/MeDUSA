# Software Bill of Materials (SBOM) Documentation

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Format**: CycloneDX 1.4 (JSON)  
**Purpose**: Component transparency for FDA premarket submissions

---

## 1. Overview

This document describes the Software Bill of Materials (SBOM) for the MeDUSA platform, providing:
- Complete inventory of software components
- Version information and licensing
- Known vulnerability status
- Update procedures

Per FDA 2025 Premarket Cybersecurity Guidance, SBOMs enable:
- Vulnerability management
- Supply chain transparency
- Post-market security updates

---

## 2. SBOM Generation

### 2.1 Automated Generation (CI/CD)

SBOMs are automatically generated on every build via GitHub Actions:

```yaml
# .github/workflows/sbom.yml
name: Generate SBOM

on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  generate-sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Frontend SBOM (Flutter/Dart)
      - name: Generate Frontend SBOM
        run: |
          cd frontend
          flutter pub get
          dart run cyclonedx:cyclonedx -o sbom-frontend.json
      
      # Backend SBOM (Python)
      - name: Generate Backend SBOM
        run: |
          cd backend/backend-py
          pip install cyclonedx-bom
          cyclonedx-py -r requirements.txt -o sbom-backend.json
      
      - name: Upload SBOMs
        uses: actions/upload-artifact@v4
        with:
          name: sbom-artifacts
          path: |
            frontend/sbom-frontend.json
            backend/backend-py/sbom-backend.json
```

### 2.2 Manual Generation

**Frontend (Flutter)**:
```powershell
cd MeDUSA\frontend
flutter pub get
dart run cyclonedx:cyclonedx -o sbom-frontend.json
```

**Backend (Python)**:
```powershell
cd MeDUSA\backend\backend-py
pip install cyclonedx-bom
cyclonedx-py -r requirements.txt -o sbom-backend.json
```

---

## 3. Component Inventory

### 3.1 Frontend Components (Flutter)

| Component | Version | License | Purpose | Security Critical |
|-----------|---------|---------|---------|-------------------|
| flutter | 3.x | BSD-3 | UI framework | No |
| flutter_secure_storage | 9.0.0 | BSD-3 | Credential storage | **Yes** |
| dio | 5.4.0 | MIT | HTTP client | **Yes** |
| hive | 2.2.3 | Apache-2.0 | Local database | Yes |
| flutter_bloc | 8.1.6 | MIT | State management | No |
| go_router | 15.0.0 | BSD-3 | Navigation | No |
| flutter_blue_plus | 1.32.12 | BSD-3 | BLE communication | Yes |
| crypto | 3.0.3 | BSD-3 | Cryptography | **Yes** |
| cryptography | 2.7.0 | Apache-2.0 | Advanced cryptography | **Yes** |
| responsive_framework | 1.0.0 | MIT | Responsive UI | No |
| win_ble | 1.1.1 | MIT | Windows BLE (C++ native) | **Yes** |

### 3.2 Backend Components (Python)

| Component | Version | License | Purpose | Security Critical |
|-----------|---------|---------|---------|-------------------|
| fastapi | 0.115.2 | MIT | Web framework | **Yes** |
| mangum | 0.17.0 | MIT | AWS Lambda adapter | Yes |
| pyjwt | 2.9.0 | MIT | JWT handling | **Yes** |
| argon2-cffi | 21.3.0 | MIT | Password hashing | **Yes** |
| boto3 | 1.35.36 | Apache-2.0 | AWS SDK | Yes |
| pydantic | 2.9.2 | MIT | Data validation | **Yes** |
| uvicorn | 0.32.0 | BSD-3 | ASGI server | No |
| pyotp | 2.9.0 | MIT | TOTP MFA support | **Yes** |

### 3.3 Infrastructure Components

| Component | Version | Provider | Purpose |
|-----------|---------|----------|---------|
| AWS Lambda | Python 3.10/3.11 | AWS | Serverless compute |
| AWS API Gateway | REST v1 | AWS | API management |
| AWS DynamoDB | On-demand | AWS | Database |
| AWS S3 | Standard | AWS | Object storage |
| AWS SES | Standard | AWS | Email service |
| AWS IAM | N/A | AWS | Identity management |

---

## 4. Vulnerability Management

### 4.1 Scanning Schedule

| Scan Type | Frequency | Tool | Responsible |
|-----------|-----------|------|-------------|
| Dependency scan | Every commit | Safety, Dependabot | Automated |
| Container scan | Weekly | Trivy | DevOps |
| SAST | Every PR | Bandit, flutter analyze | Automated |
| Manual review | Monthly | Zhicheng Sun | Manual |

### 4.2 Current Vulnerability Status

**As of February 2026:**

| Severity | Frontend | Backend | Total |
|----------|----------|---------|-------|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 0 | 0 | 0 |
| Low | 2 | 1 | 3 |

**Low Severity Details:**
- Informational findings related to outdated documentation
- Non-exploitable in current configuration

### 4.3 Vulnerability Response SLA

| Severity | Detection to Fix | Communication |
|----------|-----------------|---------------|
| Critical | 24 hours | Immediate notification |
| High | 7 days | Within 24 hours |
| Medium | 30 days | Weekly report |
| Low | 90 days | Monthly report |

---

## 5. Update Procedures

### 5.1 Dependency Update Process

```
1. Automated PR created by Dependabot/Renovate
2. CI/CD runs security scans
3. Developer reviews changes
4. Testing in staging environment
5. Security review (for critical components)
6. Merge and deploy
7. Update SBOM artifact
```

### 5.2 Emergency Patching

For critical vulnerabilities:

1. **Immediate**: Assess exploitability in our context
2. **Within 4 hours**: Develop patch or workaround
3. **Within 24 hours**: Deploy fix to production
4. **Within 48 hours**: Update SBOM and notify stakeholders

---

## 6. SBOM Format Specification

### 6.1 CycloneDX Schema

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "serialNumber": "urn:uuid:...",
  "version": 1,
  "metadata": {
    "timestamp": "2026-02-01T00:00:00Z",
    "tools": [
      {
        "vendor": "CycloneDX",
        "name": "cyclonedx-python",
        "version": "3.x"
      }
    ],
    "component": {
      "type": "application",
      "name": "MeDUSA",
      "version": "3.0.0"
    }
  },
  "components": [
    {
      "type": "library",
      "name": "pyjwt",
      "version": "2.9.0",
      "purl": "pkg:pypi/pyjwt@2.9.0",
      "licenses": [
        {
          "license": {
            "id": "MIT"
          }
        }
      ]
    }
  ]
}
```

### 6.2 Required Fields

For FDA submission, each component must include:

- [ ] Component name
- [ ] Version number
- [ ] Package URL (purl)
- [ ] License information
- [ ] Supplier/vendor
- [ ] Hash/checksum (when available)

---

## 7. License Compliance

### 7.1 License Summary

| License Type | Count | Commercial Use | Modification |
|--------------|-------|----------------|--------------|
| MIT | 15 | ✅ Allowed | ✅ Allowed |
| BSD-3-Clause | 12 | ✅ Allowed | ✅ Allowed |
| Apache-2.0 | 8 | ✅ Allowed | ✅ Allowed |
| GPL | 0 | N/A | N/A |

### 7.2 License Obligations

All licenses in use are permissive and compatible with commercial/medical device use:

1. **MIT/BSD**: Include copyright notice in distribution
2. **Apache-2.0**: Include NOTICE file, copyright notice

---

## 8. Supply Chain Security

### 8.1 Package Source Verification

| Package Manager | Registry | Verification |
|-----------------|----------|--------------|
| pub.dev | https://pub.dev | Package signing |
| PyPI | https://pypi.org | Package signing (PEP 691) |
| npm | https://registry.npmjs.org | Integrity hashes |

### 8.2 Lock File Management

- **Frontend**: `pubspec.lock` committed to repository
- **Backend**: `requirements.txt` with pinned versions
- **Verification**: Hash verification on install

---

## 9. SBOM Distribution

### 9.1 Artifact Storage

| Location | Access | Retention |
|----------|--------|-----------|
| GitHub Actions | Per-build | 90 days |
| Release Assets | Per-release | Permanent |
| Documentation | Manual | With each major version |

### 9.2 Access for Regulators

SBOMs are available:
1. As GitHub Release attachments
2. Upon request to security team *(replace `security@medusa-project.example` with actual contact)*
3. In FDA premarket submission package

---

## 10. Document Maintenance

| Activity | Frequency | Responsible |
|----------|-----------|-------------|
| SBOM regeneration | Every release | CI/CD |
| Vulnerability scan | Daily | Automated |
| Manual review | Quarterly | Zhicheng Sun |
| Document update | With major changes | Zhicheng Sun |

---

## Appendix A: Sample SBOM Extract

```json
{
  "components": [
    {
      "type": "library",
      "bom-ref": "pkg:pypi/pyjwt@2.8.0",
      "name": "pyjwt",
      "version": "2.8.0",
      "description": "JSON Web Token implementation in Python",
      "purl": "pkg:pypi/pyjwt@2.8.0",
      "licenses": [{"license": {"id": "MIT"}}],
      "externalReferences": [
        {
          "type": "website",
          "url": "https://github.com/jpadilla/pyjwt"
        }
      ]
    },
    {
      "type": "library",
      "bom-ref": "pkg:pypi/argon2-cffi@23.1.0",
      "name": "argon2-cffi",
      "version": "23.1.0",
      "description": "Argon2 password hashing for Python",
      "purl": "pkg:pypi/argon2-cffi@23.1.0",
      "licenses": [{"license": {"id": "MIT"}}]
    }
  ]
}
```

---

**Document Control:**
- Created: February 2026
- Author: Zhicheng Sun
- Review: Quarterly
