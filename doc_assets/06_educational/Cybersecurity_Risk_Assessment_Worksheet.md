# Cybersecurity Risk Assessment Worksheet

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Purpose**: Educational worksheet for cybersecurity risk assessment in medical devices  
**Reference**: FDA/MITRE Playbook for Threat Modeling Medical Devices

---

## Instructions for Students

This worksheet guides you through the cybersecurity risk assessment process for the MeDUSA platform. Complete each section to demonstrate understanding of:

1. Asset identification and criticality
2. Threat identification using STRIDE
3. Vulnerability assessment
4. Risk scoring and prioritization
5. Control selection and justification

---

## Part 1: Asset Inventory

### 1.1 Identify Critical Assets

List all assets in the MeDUSA system that require protection:

| Asset ID | Asset Name | Asset Type | Criticality (1-5) | Justification |
|----------|-----------|------------|-------------------|---------------|
| A1 | Patient Tremor Data | Data | 5 | PHI, treatment decisions |
| A2 | User Credentials | Data | 5 | Access control |
| A3 | JWT Tokens | Data | 4 | Session authentication |
| A4 | API Endpoints | Service | 4 | System functionality |
| A5 | DynamoDB Tables | Infrastructure | 5 | Data persistence |
| A6 | Device Identity | Data | 3 | Device authentication |
| A7 | Audit Logs | Data | 4 | Compliance, forensics |
| A8 | | | | |
| A9 | | | | |
| A10 | | | | |

**Student Task**: Add any additional assets you identify (A8-A10)

### 1.2 Data Flow Analysis

Document how data flows through the system:

```
[Sensor Device] ---(BLE)--- [Mobile App] ---(HTTPS/TLS 1.3)--- [API Gateway]
                                                                     |
                                                              [Lambda Functions]
                                                                     |
                                                              [DynamoDB/S3]
```

**Student Task**: Identify trust boundaries and potential interception points

Trust Boundaries:
1. _________________________________________________
2. _________________________________________________
3. _________________________________________________

---

## Part 2: STRIDE Threat Analysis

### 2.1 Spoofing Threats

| Threat ID | Threat Description | Target Asset | Attack Vector | Your Notes |
|-----------|-------------------|--------------|---------------|------------|
| S1 | Attacker impersonates legitimate user | A2 | Credential theft | |
| S2 | Attacker spoofs device identity | A6 | MAC spoofing | |
| S3 | | | | |
| S4 | | | | |

**Student Task**: Add 2 additional spoofing threats (S3, S4)

### 2.2 Tampering Threats

| Threat ID | Threat Description | Target Asset | Attack Vector | Your Notes |
|-----------|-------------------|--------------|---------------|------------|
| T1 | Modify tremor data in transit | A1 | MITM attack | |
| T2 | Alter patient records | A1 | API manipulation | |
| T3 | | | | |
| T4 | | | | |

**Student Task**: Add 2 additional tampering threats (T3, T4)

### 2.3 Repudiation Threats

| Threat ID | Threat Description | Target Asset | Attack Vector | Your Notes |
|-----------|-------------------|--------------|---------------|------------|
| R1 | Deny accessing patient data | A7 | Insufficient logging | |
| R2 | | | | |

**Student Task**: Add 1 additional repudiation threat (R2)

### 2.4 Information Disclosure Threats

| Threat ID | Threat Description | Target Asset | Attack Vector | Your Notes |
|-----------|-------------------|--------------|---------------|------------|
| I1 | Expose patient data to unauthorized users | A1 | RBAC bypass | |
| I2 | Credential leakage in logs | A2 | Verbose logging | |
| I3 | | | | |

**Student Task**: Add 1 additional information disclosure threat (I3)

### 2.5 Denial of Service Threats

| Threat ID | Threat Description | Target Asset | Attack Vector | Your Notes |
|-----------|-------------------|--------------|---------------|------------|
| D1 | Overwhelm API with requests | A4 | HTTP flooding | |
| D2 | | | | |

**Student Task**: Add 1 additional DoS threat (D2)

### 2.6 Elevation of Privilege Threats

| Threat ID | Threat Description | Target Asset | Attack Vector | Your Notes |
|-----------|-------------------|--------------|---------------|------------|
| E1 | Patient gains doctor privileges | A4 | Role manipulation | |
| E2 | | | | |

**Student Task**: Add 1 additional EoP threat (E2)

---

## Part 3: Vulnerability Assessment

### 3.1 Technical Vulnerabilities

For each identified threat, assess potential vulnerabilities:

| Threat ID | Vulnerability | CVSS Base (0-10) | Exploitability | Current Controls |
|-----------|--------------|------------------|----------------|------------------|
| S1 | Weak password policy | 6.5 | Medium | Password validator |
| T1 | Unencrypted traffic | 7.5 | High | TLS 1.3 |
| | | | | |
| | | | | |
| | | | | |

**Student Task**: Complete the vulnerability assessment for all threats

### 3.2 CVSS Calculation Exercise

Calculate CVSS v3.1 score for the following scenario:

**Scenario**: An attacker can exploit an IDOR vulnerability to access other patients' tremor data

| Metric | Value | Score |
|--------|-------|-------|
| Attack Vector | Network | |
| Attack Complexity | Low | |
| Privileges Required | Low | |
| User Interaction | None | |
| Scope | Changed | |
| Confidentiality Impact | High | |
| Integrity Impact | None | |
| Availability Impact | None | |

**Your calculated CVSS score**: _____________

---

## Part 4: Risk Scoring

### 4.1 Risk Matrix

Use the following matrix to score risks:

| | Impact: Low (1) | Impact: Medium (2) | Impact: High (3) | Impact: Critical (4) |
|-|-----------------|--------------------|-----------------|-----------------------|
| **Likelihood: Very High (4)** | 4 | 8 | 12 | 16 |
| **Likelihood: High (3)** | 3 | 6 | 9 | 12 |
| **Likelihood: Medium (2)** | 2 | 4 | 6 | 8 |
| **Likelihood: Low (1)** | 1 | 2 | 3 | 4 |

**Risk Levels**:
- 1-3: Low (Accept)
- 4-6: Medium (Monitor)
- 7-9: High (Mitigate)
- 10-16: Critical (Immediate action)

### 4.2 Risk Register

Complete the risk register for your identified threats:

| Threat ID | Likelihood (1-4) | Impact (1-4) | Risk Score | Risk Level | Priority |
|-----------|-----------------|--------------|------------|------------|----------|
| S1 | | | | | |
| S2 | | | | | |
| T1 | | | | | |
| T2 | | | | | |
| R1 | | | | | |
| I1 | | | | | |
| I2 | | | | | |
| D1 | | | | | |
| E1 | | | | | |

**Student Task**: Score all identified threats

---

## Part 5: Control Selection

### 5.1 Control Categories

For each high/critical risk, select appropriate controls:

| Control Type | Description | Example |
|--------------|-------------|---------|
| Preventive | Stops threats before they occur | Authentication, encryption |
| Detective | Identifies threats when they occur | Logging, monitoring |
| Corrective | Responds to threats after occurrence | Incident response, patching |

### 5.2 Control Mapping

Map controls to your highest priority risks:

| Risk ID | Risk Score | Control Type | Proposed Control | Implementation | Residual Risk |
|---------|-----------|--------------|------------------|----------------|---------------|
| | | Preventive | | | |
| | | Detective | | | |
| | | Corrective | | | |
| | | Preventive | | | |
| | | Detective | | | |

**Student Task**: Complete control mapping for top 5 risks

### 5.3 Control Justification

For your highest priority risk, provide detailed justification:

**Risk ID**: _______________

**Current State**:
_________________________________________________________________
_________________________________________________________________

**Proposed Control**:
_________________________________________________________________

**Justification** (Why this control?):
_________________________________________________________________
_________________________________________________________________

**Implementation Effort** (Hours/Cost):
_________________________________________________________________

**Expected Risk Reduction**:
- Original Risk Score: ______
- Residual Risk Score: ______
- Reduction: ______%

---

## Part 6: Patient Safety Analysis

### 6.1 Safety Impact Assessment

Analyze how each high-priority cybersecurity risk could impact patient safety:

| Risk ID | Potential Patient Harm | Severity (S1-S5) | Likelihood | Mitigation |
|---------|----------------------|------------------|------------|------------|
| | Wrong treatment due to falsified data | | | |
| | Missed critical tremor alert | | | |
| | Privacy breach causing emotional harm | | | |

**Severity Scale**:
- S1: Negligible - No injury
- S2: Minor - Temporary discomfort
- S3: Serious - Medical intervention needed
- S4: Critical - Life-threatening
- S5: Catastrophic - Death

### 6.2 Clinical Scenario Analysis

**Scenario**: A 68-year-old Parkinson's patient uses MeDUSA for daily tremor monitoring. Their doctor adjusts medication based on weekly tremor trend reports.

**Question 1**: If an attacker modifies the patient's tremor scores to appear lower than actual, what clinical impact could occur?

Your Answer:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

**Question 2**: What security control(s) would prevent this scenario?

Your Answer:
_________________________________________________________________
_________________________________________________________________

---

## Part 7: Regulatory Mapping

### 7.1 FDA Expectations Alignment

Map your controls to FDA premarket cybersecurity expectations:

| FDA Section | Requirement | Your Control | Evidence |
|-------------|-------------|--------------|----------|
| 5.1 | Authentication | | |
| 5.2 | Authorization | | |
| 6.1 | Encryption in transit | | |
| 6.2 | Encryption at rest | | |
| 7.0 | Audit controls | | |
| 8.0 | Software updates | | |

### 7.2 Compliance Gap Analysis

Identify any gaps in compliance:

| FDA Requirement | Current State | Gap | Remediation Plan | Priority |
|-----------------|---------------|-----|------------------|----------|
| | | | | |
| | | | | |
| | | | | |

---

## Part 8: Deliverables Checklist

Before submission, ensure you have completed:

- [ ] Asset inventory with criticality ratings
- [ ] Trust boundary identification
- [ ] STRIDE threat analysis (all 6 categories)
- [ ] Vulnerability assessment with CVSS scores
- [ ] Risk register with scores and priorities
- [ ] Control selection and justification for top 5 risks
- [ ] Patient safety impact analysis
- [ ] Clinical scenario response
- [ ] FDA mapping table
- [ ] Gap analysis with remediation plans

---

## Grading Rubric

| Section | Points | Criteria |
|---------|--------|----------|
| Asset Inventory | 10 | Completeness, accurate criticality |
| STRIDE Analysis | 20 | All categories covered, realistic threats |
| Risk Scoring | 15 | Correct calculations, justified scores |
| Control Selection | 20 | Appropriate controls, strong justification |
| Patient Safety | 15 | Clinical understanding demonstrated |
| Regulatory Mapping | 10 | Accurate FDA alignment |
| Documentation Quality | 10 | Clear, professional formatting |
| **Total** | **100** | |

---

## References

1. FDA. (2025). Cybersecurity in Medical Devices: Quality System Considerations
2. MITRE & MDIC. (2021). Playbook for Threat Modeling Medical Devices
3. ISO 14971:2019. Medical devices — Application of risk management
4. NIST SP 800-30. Guide for Conducting Risk Assessments
5. CVSS v3.1 Specification Document

---

**Instructor Notes**:
- This worksheet is designed for a 2-3 hour lab session
- Students should have access to the MeDUSA codebase
- Sample solutions available in instructor guide
- Encourage discussion of alternative control strategies

---

**Document Information**:
- Author: Zhicheng Sun
- Version: 1.0
- Compliance: FDA 2025 Premarket Cybersecurity Guidance, ISO 14971
