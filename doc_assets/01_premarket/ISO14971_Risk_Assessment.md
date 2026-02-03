# ISO 14971 Risk Management Documentation

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Standard Reference**: ISO 14971:2019 - Medical devices — Application of risk management to medical devices

---

## 1. Introduction

### 1.1 Purpose

This document applies ISO 14971:2019 risk management principles to the MeDUSA tremor monitoring platform, focusing on cybersecurity risks that may impact patient safety.

### 1.2 Scope

This risk management process covers:
- Flutter mobile/desktop application
- AWS serverless backend
- Device-cloud communication interfaces

**Out of Scope**: Raspberry Pi hardware (covered in separate document)

### 1.3 Definitions

| Term | Definition |
|------|------------|
| **Harm** | Injury or damage to the health of people |
| **Hazard** | Potential source of harm |
| **Hazardous Situation** | Circumstance in which people are exposed to hazard(s) |
| **Risk** | Combination of probability of occurrence of harm and severity of that harm |
| **Risk Control** | Process in which decisions are made and controls implemented |

---

## 2. Risk Management Plan

### 2.1 Risk Management Activities

| Activity | Responsible | Timing |
|----------|-------------|--------|
| Risk identification | Zhicheng Sun | Design phase |
| Risk analysis | Zhicheng Sun | Design/Development |
| Risk evaluation | Product Manager | Before release |
| Risk control implementation | Zhicheng Sun | Development phase |
| Residual risk evaluation | Zhicheng Sun | Pre-release |
| Production/post-production | Zhicheng Sun | Continuous |

### 2.2 Risk Acceptability Criteria

#### 2.2.1 Severity Levels

| Level | Description | Examples in MeDUSA Context |
|-------|-------------|---------------------------|
| **S1 - Negligible** | Inconvenience or temporary discomfort | UI display error, minor delay |
| **S2 - Minor** | Temporary injury, not requiring intervention | Minor delay in tremor reporting |
| **S3 - Serious** | Injury requiring medical intervention | Missed critical tremor alert |
| **S4 - Critical** | Life-threatening injury | Incorrect medication dosage due to falsified data |
| **S5 - Catastrophic** | Death | Wrong treatment leading to fatal outcome |

#### 2.2.2 Probability Levels

| Level | Description | Quantitative |
|-------|-------------|--------------|
| **P1 - Incredible** | Can be ruled out | < 10⁻⁶ |
| **P2 - Improbable** | Unlikely to occur | 10⁻⁶ to 10⁻⁴ |
| **P3 - Remote** | Could occur | 10⁻⁴ to 10⁻² |
| **P4 - Occasional** | May occur | 10⁻² to 10⁻¹ |
| **P5 - Frequent** | Expected to occur | > 10⁻¹ |

#### 2.2.3 Risk Acceptability Matrix

|  | S1 | S2 | S3 | S4 | S5 |
|--|-----|-----|-----|-----|-----|
| **P5** | M | H | U | U | U |
| **P4** | L | M | H | U | U |
| **P3** | L | L | M | H | U |
| **P2** | L | L | L | M | H |
| **P1** | L | L | L | L | M |

**Legend:**
- **L** (Low/Acceptable): Broadly acceptable
- **M** (Medium/ALARP): As Low As Reasonably Practicable - requires justification
- **H** (High): Unacceptable without risk reduction
- **U** (Unacceptable): Must be reduced or eliminated

---

## 3. Risk Analysis

### 3.1 Preliminary Hazard Analysis (PHA)

#### 3.1.1 Hazard Identification

| ID | Hazard | Source | Potential Harm |
|----|--------|--------|----------------|
| H1 | Unauthorized data access | Credential theft | Privacy breach, wrong treatment decisions |
| H2 | Data integrity loss | Data tampering | Incorrect tremor assessment |
| H3 | System unavailability | DoS attack | Delayed treatment monitoring |
| H4 | Device spoofing | Fake device | False sensor data |
| H5 | Session hijacking | Token theft | Unauthorized actions |
| H6 | Cross-patient data leak | RBAC bypass | Privacy breach |

#### 3.1.2 Hazardous Situations

| HS ID | Hazard | Hazardous Situation | Foreseeable Sequence of Events |
|-------|--------|--------------------|---------------------------------|
| HS1 | H1 | Attacker accesses patient data | Credential stolen → Login → Access patient records |
| HS2 | H2 | Tremor data modified | API exploited → Data changed → Wrong severity shown |
| HS3 | H3 | Monitoring unavailable | DoS attack → System down → Missed critical events |
| HS4 | H4 | False data recorded | Fake device → Wrong patient ID → Incorrect records |
| HS5 | H5 | Unauthorized treatment changes | Session stolen → Modify settings → Patient harm |
| HS6 | H6 | Wrong patient data exposed | RBAC bypass → Other patient visible → Privacy breach |

### 3.2 Fault Tree Analysis (FTA)

#### 3.2.1 Top Event: Patient Receives Incorrect Treatment

```
Patient Receives Incorrect Treatment
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
Incorrect Data      Doctor Error
Presented           (Out of scope)
    │
    ├─────────────┬─────────────┬─────────────┐
    │             │             │             │
    ▼             ▼             ▼             ▼
Data Tampered  Display Error  Sync Failure  Device Error
    │             │             │          (Out of scope)
    │             │             │
    ▼             ▼             ▼
[H2]          Software Bug   Network/Server
              (Tested out)   Failure [H3]
```

---

## 4. Risk Evaluation & Control

### 4.1 Risk Evaluation Table

| Risk ID | Hazard | Initial Severity | Initial Probability | Initial Risk | Acceptable? |
|---------|--------|-----------------|--------------------:|--------------|-------------|
| R1 | H1 - Unauthorized access | S3 | P3 | M | ALARP |
| R2 | H2 - Data integrity | S4 | P2 | M | ALARP |
| R3 | H3 - Unavailability | S3 | P3 | M | ALARP |
| R4 | H4 - Device spoofing | S3 | P2 | L | Yes |
| R5 | H5 - Session hijacking | S3 | P2 | L | Yes |
| R6 | H6 - Cross-patient leak | S2 | P2 | L | Yes |

### 4.2 Risk Control Measures

#### R1 - Unauthorized Data Access

| Control ID | Control Measure | Implementation |
|------------|----------------|----------------|
| RC1.1 | Strong password policy | `password_validator.py` |
| RC1.2 | Multi-factor authentication | TOTP in `verification_service.dart` |
| RC1.3 | JWT token authentication | `auth.py:issue_tokens()` |
| RC1.4 | Short token expiration | 1-hour access tokens |
| RC1.5 | Rate limiting | API Gateway: 5 auth/min |

**Post-Control Assessment:**
- New Probability: P1 (Incredible with MFA)
- New Risk Level: L (Acceptable)

#### R2 - Data Integrity Loss

| Control ID | Control Measure | Implementation |
|------------|----------------|----------------|
| RC2.1 | Input validation | Pydantic models in API |
| RC2.2 | TLS encryption | `SecureNetworkService` |
| RC2.3 | RBAC enforcement | `rbac.py:require_role()` |
| RC2.4 | Audit logging | CloudWatch logs |
| RC2.5 | Immutable timestamps | DynamoDB design |

**Post-Control Assessment:**
- New Probability: P1 (Incredible)
- New Risk Level: L (Acceptable)

#### R3 - System Unavailability

| Control ID | Control Measure | Implementation |
|------------|----------------|----------------|
| RC3.1 | API rate limiting | API Gateway throttling |
| RC3.2 | Lambda auto-scaling | AWS managed |
| RC3.3 | DynamoDB on-demand | Auto-scaling capacity |
| RC3.4 | CloudWatch alarms | Availability monitoring |

**Post-Control Assessment:**
- New Probability: P2 (Improbable)
- New Risk Level: L (Acceptable)

#### R4 - Device Spoofing

| Control ID | Control Measure | Implementation |
|------------|----------------|----------------|
| RC4.1 | MAC address binding | `db.py:get_device_by_mac()` |
| RC4.2 | Admin device approval | `main.py:register_device()` |
| RC4.3 | Session-based binding | `create_measurement_session()` |

**Post-Control Assessment:**
- New Probability: P1 (Incredible)
- New Risk Level: L (Acceptable)

#### R5 - Session Hijacking

| Control ID | Control Measure | Implementation |
|------------|----------------|----------------|
| RC5.1 | HTTPS enforcement | `SecureNetworkService` |
| RC5.2 | Token rotation | Refresh token flow |
| RC5.3 | Token binding | Device fingerprint (future) |

**Post-Control Assessment:**
- New Probability: P1 (Incredible)
- New Risk Level: L (Acceptable)

#### R6 - Cross-Patient Data Leak

| Control ID | Control Measure | Implementation |
|------------|----------------|----------------|
| RC6.1 | Patient ID validation | `main.py` RBAC checks |
| RC6.2 | Doctor-patient binding | `db.py:get_patients_by_doctor()` |
| RC6.3 | Role-based filtering | Query restrictions |

**Post-Control Assessment:**
- New Probability: P1 (Incredible)
- New Risk Level: L (Acceptable)

---

## 5. Residual Risk Summary

### 5.1 Post-Control Risk Matrix

| Risk ID | Hazard | Post-Control Severity | Post-Control Probability | Residual Risk | Status |
|---------|--------|----------------------|--------------------------|---------------|--------|
| R1 | Unauthorized access | S3 | P1 | L | ✅ Acceptable |
| R2 | Data integrity | S4 | P1 | L | ✅ Acceptable |
| R3 | Unavailability | S3 | P2 | L | ✅ Acceptable |
| R4 | Device spoofing | S3 | P1 | L | ✅ Acceptable |
| R5 | Session hijacking | S3 | P1 | L | ✅ Acceptable |
| R6 | Cross-patient leak | S2 | P1 | L | ✅ Acceptable |

### 5.2 Overall Residual Risk Evaluation

**Conclusion**: All identified risks have been reduced to acceptable levels through the implementation of appropriate controls. The overall residual risk of the MeDUSA platform is **ACCEPTABLE**.

---

## 6. Risk-Benefit Analysis

### 6.1 Intended Benefits

| Benefit | Description |
|---------|-------------|
| **Continuous Monitoring** | Real-time tremor assessment for Parkinson's patients |
| **Remote Care** | Enables remote patient monitoring |
| **Data-Driven Treatment** | Provides objective tremor data for treatment decisions |
| **Early Detection** | Identifies Parkinsonian episodes early |

### 6.2 Residual Risks

All residual risks are at acceptable levels (L) as documented above.

### 6.3 Benefit-Risk Conclusion

The medical benefits of the MeDUSA platform—continuous tremor monitoring enabling better treatment outcomes for Parkinson's disease patients—**outweigh the residual risks** which have been reduced to acceptable levels through comprehensive security controls.

---

## 7. Verification of Risk Control Effectiveness

| Control ID | Verification Method | Result | Date |
|------------|--------------------:|--------|------|
| RC1.1-RC1.5 | Security audit, penetration testing | Pass | Feb 2026 |
| RC2.1-RC2.5 | Code review, API testing | Pass | Feb 2026 |
| RC3.1-RC3.4 | Load testing, monitoring | Pass | Feb 2026 |
| RC4.1-RC4.3 | API testing, device registration test | Pass | Feb 2026 |
| RC5.1-RC5.3 | TLS verification, session testing | Pass | Feb 2026 |
| RC6.1-RC6.3 | RBAC testing, cross-patient access test | Pass | Feb 2026 |

---

## 8. Production & Post-Production Information

### 8.1 Production Monitoring

| Activity | Frequency | Responsible |
|----------|-----------|-------------|
| Security log review | Daily | Operations |
| Incident tracking | Continuous | Zhicheng Sun |
| Vulnerability scanning | Weekly | Zhicheng Sun |
| Control effectiveness review | Quarterly | Zhicheng Sun |

### 8.2 Post-Production Data Sources

- CloudWatch metrics and logs
- User feedback and support tickets
- Security incident reports
- Vulnerability disclosures

### 8.3 Risk Management File Updates

Risk management documentation will be updated when:
- New hazards are identified
- Control effectiveness changes
- Significant incidents occur
- Regulatory requirements change
- System architecture changes significantly

---

## 9. Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Risk Manager | | | |
| Quality Assurance | | | |
| Regulatory Affairs | | | |
| Project Lead | | | |

---

## Appendix A: Risk Management Process Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│                    RISK MANAGEMENT PROCESS                       │
│                        (ISO 14971:2019)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ Risk Analysis│───►│Risk Evaluation│───►│ Risk Control │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│        │                    │                    │               │
│        ▼                    ▼                    ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Identify   │    │   Compare    │    │  Implement   │      │
│  │   Hazards    │    │ Against Risk │    │   Controls   │      │
│  │              │    │  Criteria    │    │              │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│        │                    │                    │               │
│        ▼                    ▼                    ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  Estimate    │    │  Determine   │    │   Verify     │      │
│  │    Risk      │    │Acceptability │    │Effectiveness │      │
│  │              │    │              │    │              │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                                                  │               │
│                                                  ▼               │
│                                          ┌──────────────┐       │
│                                          │   Residual   │       │
│                                          │     Risk     │       │
│                                          │  Evaluation  │       │
│                                          └──────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Appendix B: References

1. ISO 14971:2019 - Medical devices — Application of risk management to medical devices
2. ISO/TR 24971:2020 - Medical devices — Guidance on the application of ISO 14971
3. FDA. (2025). Cybersecurity in Medical Devices
4. IEC 62443 - Industrial communication networks - Network and system security

---

**Document Control:**
- Document ID: MeDUSA-RM-001
- Version: 1.0
- Created: February 2026
- Author: Zhicheng Sun
- Review Cycle: After any significant change or annually
