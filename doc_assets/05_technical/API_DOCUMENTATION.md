# MeDUSA Backend API Documentation

**Version**: 3.0  
**Base URL**: `https://<API-GATEWAY-ID>.execute-api.us-east-1.amazonaws.com/Prod`  
**Tremor API Base URL**: `https://<API-GATEWAY-ID>.execute-api.us-east-1.amazonaws.com/Prod`  
**Last Updated**: February 2, 2026  
**Status**: Production

> **Note**: The actual API Gateway ID changes with each deployment. The current production API endpoint is configured in `frontend/lib/core/constants/app_constants.dart`. Update the Flutter app configuration to match your deployed API Gateway URL.

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [API Architecture](#api-architecture)
4. [Core APIs](#core-apis)
   - [Authentication & User Management](#authentication--user-management)
   - [Patient Management](#patient-management)
   - [Device Management](#device-management)
   - [Tremor Monitoring](#tremor-monitoring)
5. [Data Models](#data-models)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [Examples](#examples)

---

## Overview

The MeDUSA (Medical Data Fusion and Analysis) backend provides RESTful APIs for managing a Parkinson's disease tremor monitoring system. The system consists of two main API gateways:

- **General API (v3)**: Handles authentication, user management, patient profiles, and device management
- **Tremor API**: Specialized endpoints for tremor data querying and statistical analysis

### Key Features

- JWT-based authentication with refresh tokens
- Role-based access control (Admin, Doctor, Patient)
- Real-time tremor data processing
- Statistical analysis and aggregation
- Device-patient dynamic binding
- Secure password reset via email

---

## Authentication

### Authentication Flow

```
1. User Login → JWT Access Token + Refresh Token
2. Access Token (1 hour / 3600s TTL) used for API requests
3. Refresh Token (7 days TTL) used to obtain new access tokens
4. Token stored in HTTP-only cookies (production) or returned in response
```

### Token Structure

**Access Token Payload:**
```json
{
  "user_id": "uuid-v4",
  "email": "user@example.com",
  "role": "doctor|admin|patient",
  "exp": 1700000000,
  "iat": 1699998200
}
```

**Refresh Token:**
- Stored in DynamoDB table: `medusa-refresh-tokens-prod`
- Includes device fingerprint for security
- Automatically rotated on use

### Required Headers

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

---

## API Architecture

### Infrastructure

```
┌─────────────────────────────────────────────────────────┐
│                    API Gateway v3                       │
│            (<API-ID>.execute-api.us-east-1)            │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ↓
         ┌─────────────────────┐
         │  Lambda: medusa-api-v3 │
         │    (Python 3.10)       │
         └──────────┬─────────────┘
                    │
         ┌──────────┴──────────┐
         ↓                     ↓
┌─────────────────┐   ┌──────────────────┐
│   DynamoDB      │   │   AWS SES        │
│   Tables:       │   │   (Email)        │
│   - Users       │   └──────────────────┘
│   - Patients    │
│   - Devices     │
│   - Sessions    │
│   - Tokens      │
└─────────────────┘
```

```
┌─────────────────────────────────────────────────────────┐
│                MeDUSA Tremor API                        │
│            (<API-ID>.execute-api.us-east-1)            │
└──────────┬──────────────────────────────┬───────────────┘
           │                              │
           ↓                              ↓
┌──────────────────────┐    ┌──────────────────────────┐
│ Lambda:              │    │ Lambda:                  │
│ QueryTremorData      │    │ GetTremorStatistics      │
│ (Python 3.11)        │    │ (Python 3.11)            │
└──────────┬───────────┘    └──────────┬───────────────┘
           │                           │
           └───────────┬───────────────┘
                       ↓
              ┌─────────────────┐
              │   DynamoDB      │
              │   - tremor-     │
              │     analysis    │
              │   - sensor-data │
              └─────────────────┘
```

### DynamoDB Tables

| Table Name | Primary Key | GSI | Purpose |
|------------|-------------|-----|---------|
| medusa-users-prod | user_id (HASH) | EmailIndex (email) | User accounts |
| medusa-patient-profiles-prod | patient_id (HASH) | DoctorIndex (doctor_id) | Patient profiles |
| medusa-devices-prod | device_id (HASH) | PatientIndex (patient_id) | Device registry |
| medusa-refresh-tokens-prod | token_id (HASH) | UserIndex (user_id) | Refresh tokens |
| medusa-sessions-prod | session_id (HASH) | UserIndex (user_id) | User sessions |
| medusa-tremor-analysis | patient_id (HASH), timestamp (RANGE) | DeviceIndex (device_id) | Tremor analysis data |
| medusa-sensor-data | patient_id (HASH), timestamp (RANGE) | - | Raw sensor data |

---

## Core APIs

> ℹ️ **Note**: All names, email addresses, phone numbers, and other personal data shown in the API examples below (e.g., "John Smith", "jane.doe@email.com", "+1-555-0123") are **fictional placeholder data** for demonstration purposes only.

### Authentication & User Management

#### POST /auth/register

Register a new user account.

**Request:**
```json
{
  "email": "doctor@hospital.com",
  "password": "SecurePass123!@#",
  "role": "doctor",
  "first_name": "John",
  "last_name": "Smith"
}
```

**Password Requirements:**
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character (!@#$%^&*)

**Response (201 Created):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "doctor@hospital.com",
    "role": "doctor",
    "first_name": "John",
    "last_name": "Smith",
    "created_at": "2025-11-18T10:30:00Z"
  }
}
```

---

#### POST /auth/login

Authenticate user and obtain tokens.

**Request:**
```json
{
  "email": "doctor@hospital.com",
  "password": "SecurePass123!@#"
}
```

**Response (200 OK):**
```json
{
  "accessJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "user": {
    "id": "usr_8537f43b",
    "email": "doctor@hospital.com",
    "role": "doctor",
    "name": "John Smith"
  }
}
```

**Note**: The response uses camelCase field names (`accessJwt`, `refreshToken`, `expiresIn`) to match API v3 standards.

---

#### POST /auth/refresh

Obtain new access token using refresh token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

#### POST /auth/logout

Invalidate refresh token and end session.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

#### POST /auth/forgot-password

Request password reset email.

**Request:**
```json
{
  "email": "doctor@hospital.com"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password reset email sent if account exists"
}
```

**Email Contains:**
- 6-digit verification code
- Valid for 15 minutes
- Sent via AWS SES

---

#### POST /auth/reset-password

Reset password using verification code.

**Request:**
```json
{
  "email": "doctor@hospital.com",
  "code": "123456",
  "new_password": "NewSecurePass456!@#"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

---

#### POST /auth/change-password

Change password for authenticated user.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "current_password": "OldPassword123!@#",
  "new_password": "NewSecurePass456!@#"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

---

### Patient Management

#### POST /patients

Create new patient profile.

**Permissions**: Admin, Doctor

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "first_name": "Jane",
  "last_name": "Doe",
  "date_of_birth": "1965-05-15",
  "gender": "female",
  "email": "jane.doe@email.com",
  "phone": "+1-555-0123",
  "address": "123 Main St, Boston, MA 02101",
  "medical_history": {
    "diagnosis_date": "2020-03-10",
    "medications": ["Levodopa", "Carbidopa"],
    "allergies": ["Penicillin"],
    "notes": "Stage 2 Parkinson's disease"
  }
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Patient created successfully",
  "patient": {
    "patient_id": "PAT-001",
    "first_name": "Jane",
    "last_name": "Doe",
    "date_of_birth": "1965-05-15",
    "gender": "female",
    "email": "jane.doe@email.com",
    "phone": "+1-555-0123",
    "address": "123 Main St, Boston, MA 02101",
    "doctor_id": "550e8400-e29b-41d4-a716-446655440000",
    "medical_history": {
      "diagnosis_date": "2020-03-10",
      "medications": ["Levodopa", "Carbidopa"],
      "allergies": ["Penicillin"],
      "notes": "Stage 2 Parkinson's disease"
    },
    "created_at": "2025-11-18T10:30:00Z",
    "updated_at": "2025-11-18T10:30:00Z"
  }
}
```

---

#### GET /patients

List all patients.

**Permissions**: Admin (all patients), Doctor (own patients), Patient (self only)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `limit` (optional): Number of results (default: 50, max: 100)
- `offset` (optional): Pagination offset

**Response (200 OK):**
```json
{
  "success": true,
  "patients": [
    {
      "patient_id": "PAT-001",
      "first_name": "Jane",
      "last_name": "Doe",
      "date_of_birth": "1965-05-15",
      "gender": "female",
      "email": "jane.doe@email.com",
      "doctor_id": "550e8400-e29b-41d4-a716-446655440000",
      "created_at": "2025-11-18T10:30:00Z"
    }
  ],
  "count": 1,
  "has_more": false
}
```

---

#### GET /patients/{patient_id}

Get patient details.

**Permissions**: Admin, Doctor (if assigned), Patient (self only)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "patient": {
    "patient_id": "PAT-001",
    "first_name": "Jane",
    "last_name": "Doe",
    "date_of_birth": "1965-05-15",
    "gender": "female",
    "email": "jane.doe@email.com",
    "phone": "+1-555-0123",
    "address": "123 Main St, Boston, MA 02101",
    "doctor_id": "550e8400-e29b-41d4-a716-446655440000",
    "medical_history": {
      "diagnosis_date": "2020-03-10",
      "medications": ["Levodopa", "Carbidopa"],
      "allergies": ["Penicillin"],
      "notes": "Stage 2 Parkinson's disease"
    },
    "created_at": "2025-11-18T10:30:00Z",
    "updated_at": "2025-11-18T10:30:00Z"
  }
}
```

---

#### PUT /patients/{patient_id}

Update patient information.

**Permissions**: Admin, Doctor (if assigned)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "phone": "+1-555-9999",
  "address": "456 Oak Ave, Boston, MA 02102",
  "medical_history": {
    "diagnosis_date": "2020-03-10",
    "medications": ["Levodopa", "Carbidopa", "Rasagiline"],
    "allergies": ["Penicillin"],
    "notes": "Stage 2 Parkinson's disease, medication adjusted"
  }
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Patient updated successfully",
  "patient": {
    "patient_id": "PAT-001",
    "phone": "+1-555-9999",
    "address": "456 Oak Ave, Boston, MA 02102",
    "updated_at": "2025-11-18T11:00:00Z"
  }
}
```

---

#### DELETE /patients/{patient_id}

Delete patient profile.

**Permissions**: Admin only

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Patient deleted successfully"
}
```

---

### Device Management

#### POST /devices

Register new monitoring device.

**Permissions**: Admin, Doctor

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "device_name": "Tremor Monitor v2",
  "device_type": "wearable_sensor",
  "manufacturer": "MedTech Corp",
  "model": "TM-2024",
  "serial_number": "SN123456789",
  "firmware_version": "2.1.0"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Device registered successfully",
  "device": {
    "device_id": "DEV-001",
    "device_name": "Tremor Monitor v2",
    "device_type": "wearable_sensor",
    "manufacturer": "MedTech Corp",
    "model": "TM-2024",
    "serial_number": "SN123456789",
    "firmware_version": "2.1.0",
    "status": "available",
    "patient_id": null,
    "last_seen": null,
    "created_at": "2025-11-18T10:30:00Z",
    "updated_at": "2025-11-18T10:30:00Z"
  }
}
```

---

#### GET /devices

List all devices.

**Permissions**: Admin, Doctor

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `status` (optional): Filter by status (available, in_use, maintenance, decommissioned)
- `patient_id` (optional): Filter by assigned patient
- `limit` (optional): Number of results (default: 50)

**Response (200 OK):**
```json
{
  "success": true,
  "devices": [
    {
      "device_id": "DEV-001",
      "device_name": "Tremor Monitor v2",
      "device_type": "wearable_sensor",
      "status": "in_use",
      "patient_id": "PAT-001",
      "last_seen": "2025-11-18T10:25:00Z",
      "firmware_version": "2.1.0"
    },
    {
      "device_id": "DEV-002",
      "device_name": "Tremor Monitor v2",
      "device_type": "wearable_sensor",
      "status": "available",
      "patient_id": null,
      "last_seen": null,
      "firmware_version": "2.1.0"
    }
  ],
  "count": 2,
  "has_more": false
}
```

---

#### GET /devices/{device_id}

Get device details.

**Permissions**: Admin, Doctor, Patient (if assigned to them)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "device": {
    "device_id": "DEV-001",
    "device_name": "Tremor Monitor v2",
    "device_type": "wearable_sensor",
    "manufacturer": "MedTech Corp",
    "model": "TM-2024",
    "serial_number": "SN123456789",
    "firmware_version": "2.1.0",
    "status": "in_use",
    "patient_id": "PAT-001",
    "assigned_at": "2025-11-15T09:00:00Z",
    "last_seen": "2025-11-18T10:25:00Z",
    "battery_level": 85,
    "signal_quality": "excellent",
    "created_at": "2025-11-10T08:00:00Z",
    "updated_at": "2025-11-18T10:25:00Z"
  }
}
```

---

#### PUT /devices/{device_id}/assign

Assign device to patient (dynamic binding).

**Permissions**: Admin, Doctor

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "patient_id": "PAT-001"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device assigned successfully",
  "device": {
    "device_id": "DEV-001",
    "patient_id": "PAT-001",
    "status": "in_use",
    "assigned_at": "2025-11-18T11:00:00Z"
  }
}
```

---

#### PUT /devices/{device_id}/unassign

Unassign device from patient.

**Permissions**: Admin, Doctor

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device unassigned successfully",
  "device": {
    "device_id": "DEV-001",
    "patient_id": null,
    "status": "available",
    "unassigned_at": "2025-11-18T11:30:00Z"
  }
}
```

---

#### PUT /devices/{device_id}

Update device information.

**Permissions**: Admin, Doctor

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "device_name": "Tremor Monitor v2 Pro",
  "firmware_version": "2.2.0",
  "status": "maintenance"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device updated successfully",
  "device": {
    "device_id": "DEV-001",
    "device_name": "Tremor Monitor v2 Pro",
    "firmware_version": "2.2.0",
    "status": "maintenance",
    "updated_at": "2025-11-18T12:00:00Z"
  }
}
```

---

#### DELETE /devices/{device_id}

Delete device.

**Permissions**: Admin only

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device deleted successfully"
}
```

---

### Tremor Monitoring

> ⚠️ **Note**: The API Gateway ID (`buektgcf8l`) below is deployment-specific. Replace with your actual Tremor API Gateway URL.

**Base URL**: `https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod`

#### GET /api/v1/tremor/analysis

Query tremor analysis data for a patient.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `patient_id` (required): Patient identifier
- `device_id` (optional): Filter by specific device
- `start_time` (optional): ISO 8601 timestamp (e.g., "2025-11-17T00:00:00Z")
- `end_time` (optional): ISO 8601 timestamp
- `limit` (optional): Number of results (default: 50, max: 1000)

**Example Request:**
```
GET /api/v1/tremor/analysis?patient_id=PAT-001&start_time=2025-11-17T00:00:00Z&limit=10
```

**Response (200 OK):**
```json
{
  "success": true,
  "count": 10,
  "has_more": true,
  "data": [
    {
      "patient_id": "PAT-001",
      "device_id": "DEV-001",
      "timestamp": "2025-11-17T22:11:40Z",
      "tremor_index": 7.2,
      "rms_value": 0.1455,
      "dominant_frequency": 5.8,
      "tremor_power": 111.2144,
      "total_power": 2646.9154,
      "is_parkinsonian": true,
      "signal_quality": 0.96
    },
    {
      "patient_id": "PAT-001",
      "device_id": "DEV-001",
      "timestamp": "2025-11-17T22:06:40Z",
      "tremor_index": 6.5,
      "rms_value": 0.1489,
      "dominant_frequency": 5.2,
      "tremor_power": 123.7181,
      "total_power": 2763.6638,
      "is_parkinsonian": true,
      "signal_quality": 0.98
    }
  ]
}
```

**Field Descriptions:**
- `tremor_index`: Normalized tremor severity (0-10 scale)
- `rms_value`: Root mean square of acceleration signal
- `dominant_frequency`: Primary frequency component (Hz)
- `tremor_power`: Power in tremor frequency band (3-8 Hz)
- `total_power`: Total signal power
- `is_parkinsonian`: Boolean flag for Parkinsonian tremor characteristics (4-6 Hz)
- `signal_quality`: Signal quality score (0-1)

---

#### GET /api/v1/tremor/statistics

Get aggregated tremor statistics for a patient.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `patient_id` (required): Patient identifier
- `start_time` (optional): ISO 8601 timestamp for start of analysis period
- `end_time` (optional): ISO 8601 timestamp for end of analysis period

**Example Request:**
```
GET /api/v1/tremor/statistics?patient_id=PAT-001&start_time=2025-11-15T00:00:00Z
```

**Response (200 OK):**
```json
{
  "success": true,
  "statistics": {
    "patient_id": "PAT-001",
    "time_range": {
      "start": "2025-11-15T22:16:40Z",
      "end": "2025-11-17T22:11:40Z",
      "duration_hours": 47.9
    },
    "total_readings": 576,
    "parkinsonian_episodes": 192,
    "tremor_scores": {
      "average": 3.48,
      "min": 0.14,
      "max": 9.98,
      "median": 0.33,
      "std_dev": 4.51
    },
    "frequency_analysis": {
      "avg_dominant_freq": 2.04,
      "parkinsonian_percentage": 33.3
    },
    "severity_distribution": {
      "minimal": 384,
      "mild": 0,
      "moderate": 0,
      "severe": 0,
      "very_severe": 192
    },
    "latest_reading": {
      "timestamp": "2025-11-17T22:11:40Z",
      "tremor_score": 0.42,
      "is_parkinsonian": false
    }
  }
}
```

**Severity Classification:**
- `minimal`: Tremor score < 2
- `mild`: Tremor score 2-4
- `moderate`: Tremor score 4-6
- `severe`: Tremor score 6-8
- `very_severe`: Tremor score > 8

---

## Data Models

### User

```typescript
interface User {
  user_id: string;           // UUID v4
  email: string;             // Unique email address
  password_hash: string;     // bcrypt hash
  role: "admin" | "doctor" | "patient";
  first_name: string;
  last_name: string;
  created_at: string;        // ISO 8601
  updated_at: string;        // ISO 8601
  last_login?: string;       // ISO 8601
  is_active: boolean;        // Account status
}
```

### Patient

```typescript
interface Patient {
  patient_id: string;        // Format: PAT-XXX
  first_name: string;
  last_name: string;
  date_of_birth: string;     // YYYY-MM-DD
  gender: "male" | "female" | "other";
  email?: string;
  phone?: string;
  address?: string;
  doctor_id: string;         // Assigned doctor's user_id
  medical_history?: {
    diagnosis_date?: string;
    medications?: string[];
    allergies?: string[];
    notes?: string;
  };
  created_at: string;        // ISO 8601
  updated_at: string;        // ISO 8601
}
```

### Device

```typescript
interface Device {
  device_id: string;         // Format: DEV-XXX
  device_name: string;
  device_type: "wearable_sensor" | "fixed_sensor";
  manufacturer: string;
  model: string;
  serial_number: string;
  firmware_version: string;
  status: "available" | "in_use" | "maintenance" | "decommissioned";
  patient_id?: string;       // Currently assigned patient (null if available)
  assigned_at?: string;      // ISO 8601
  last_seen?: string;        // ISO 8601
  battery_level?: number;    // 0-100
  signal_quality?: "excellent" | "good" | "fair" | "poor";
  created_at: string;        // ISO 8601
  updated_at: string;        // ISO 8601
}
```

### Tremor Analysis Record

```typescript
interface TremorAnalysis {
  patient_id: string;        // Partition key
  timestamp: string;         // Sort key, ISO 8601
  device_id: string;
  tremor_index: number;      // 0-10 scale
  rms_value: number;         // Root mean square
  dominant_frequency: number; // Hz
  tremor_power: number;      // Power in 3-8 Hz band
  total_power: number;       // Total signal power
  is_parkinsonian: boolean;  // 4-6 Hz characteristic
  signal_quality: number;    // 0-1 score
  ttl: number;               // Unix timestamp for auto-deletion (90 days)
}
```

---

## Error Handling

### Standard Error Response

```json
{
  "success": false,
  "error": "Error message description",
  "error_code": "ERROR_CODE",
  "details": "Additional error details (optional)"
}
```

### HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource already exists |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |

### Common Error Codes

```javascript
// Authentication Errors
"INVALID_CREDENTIALS"      // Wrong email/password
"TOKEN_EXPIRED"            // Access token expired
"INVALID_TOKEN"            // Malformed or invalid token
"REFRESH_TOKEN_INVALID"    // Refresh token not found or expired

// Authorization Errors
"INSUFFICIENT_PERMISSIONS" // User role lacks required permission
"ACCESS_DENIED"            // Resource access not allowed

// Validation Errors
"MISSING_REQUIRED_FIELD"   // Required field not provided
"INVALID_EMAIL_FORMAT"     // Email format invalid
"WEAK_PASSWORD"            // Password doesn't meet requirements
"INVALID_DATE_FORMAT"      // Date format incorrect

// Resource Errors
"USER_NOT_FOUND"           // User doesn't exist
"PATIENT_NOT_FOUND"        // Patient doesn't exist
"DEVICE_NOT_FOUND"         // Device doesn't exist
"DUPLICATE_EMAIL"          // Email already registered
"DEVICE_ALREADY_ASSIGNED"  // Device in use by another patient

// Data Errors
"NO_DATA_FOUND"            // No tremor data for query
"INVALID_TIME_RANGE"       // Start time after end time
```

### Example Error Responses

**401 Unauthorized:**
```json
{
  "success": false,
  "error": "Invalid or expired token",
  "error_code": "TOKEN_EXPIRED"
}
```

**403 Forbidden:**
```json
{
  "success": false,
  "error": "You don't have permission to access this patient",
  "error_code": "INSUFFICIENT_PERMISSIONS"
}
```

**400 Bad Request:**
```json
{
  "success": false,
  "error": "Password must be at least 8 characters and contain uppercase, lowercase, number, and special character",
  "error_code": "WEAK_PASSWORD"
}
```

---

## Rate Limiting

### Current Limits

| API | Limit | Window |
|-----|-------|--------|
| Authentication endpoints | 5 requests | 1 minute |
| General API | 100 requests | 1 minute |
| Tremor API | 1000 requests | 1 minute |

### Rate Limit Headers

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1700000000
```

### Rate Limit Exceeded Response

```json
{
  "success": false,
  "error": "Rate limit exceeded. Please try again later.",
  "error_code": "RATE_LIMIT_EXCEEDED",
  "retry_after": 60
}
```

---

## Examples

> ⚠️ **Note**: The API Gateway IDs shown in these examples (e.g., `zcrqexrdw1`, `buektgcf8l`) are deployment-specific and will change with each new deployment. Always refer to your actual API Gateway URL configured in the frontend application.

### Complete Authentication Flow

```javascript
// 1. Register new user
const registerResponse = await fetch(
  'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/auth/register',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'doctor@hospital.com',
      password: 'SecurePass123!@#',
      role: 'doctor',
      first_name: 'John',
      last_name: 'Smith'
    })
  }
);

// 2. Login
const loginResponse = await fetch(
  'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/auth/login',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'doctor@hospital.com',
      password: 'SecurePass123!@#'
    })
  }
);

const { access_token, refresh_token } = await loginResponse.json();

// 3. Use access token for API calls
const patientsResponse = await fetch(
  'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/patients',
  {
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json'
    }
  }
);

// 4. Refresh token when access token expires
const refreshResponse = await fetch(
  'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/auth/refresh',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token })
  }
);

const { access_token: newAccessToken } = await refreshResponse.json();
```

### Query Tremor Data

```javascript
// Get last 24 hours of tremor data
const now = new Date();
const yesterday = new Date(now - 24 * 60 * 60 * 1000);

const response = await fetch(
  `https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod/api/v1/tremor/analysis?` +
  `patient_id=PAT-001&` +
  `start_time=${yesterday.toISOString()}&` +
  `end_time=${now.toISOString()}&` +
  `limit=100`,
  {
    headers: {
      'Authorization': `Bearer ${access_token}`
    }
  }
);

const { data, count, has_more } = await response.json();
console.log(`Found ${count} tremor readings`);
```

### Get Patient Statistics

```javascript
// Get weekly tremor statistics
const statsResponse = await fetch(
  `https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod/api/v1/tremor/statistics?` +
  `patient_id=PAT-001&` +
  `start_time=2025-11-11T00:00:00Z&` +
  `end_time=2025-11-18T00:00:00Z`,
  {
    headers: {
      'Authorization': `Bearer ${access_token}`
    }
  }
);

const { statistics } = await statsResponse.json();
console.log(`Average tremor score: ${statistics.tremor_scores.average}`);
console.log(`Parkinsonian episodes: ${statistics.parkinsonian_percentage}%`);
```

### Device Assignment Workflow

```javascript
// 1. Create patient
const patientResponse = await fetch(
  'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/patients',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      first_name: 'Jane',
      last_name: 'Doe',
      date_of_birth: '1965-05-15',
      gender: 'female',
      email: 'jane.doe@email.com'
    })
  }
);

const { patient } = await patientResponse.json();

// 2. Find available device
const devicesResponse = await fetch(
  'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/devices?status=available',
  {
    headers: {
      'Authorization': `Bearer ${access_token}`
    }
  }
);

const { devices } = await devicesResponse.json();
const availableDevice = devices[0];

// 3. Assign device to patient
const assignResponse = await fetch(
  `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/devices/${availableDevice.device_id}/assign`,
  {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      patient_id: patient.patient_id
    })
  }
);

console.log('Device assigned successfully!');
```

---

## Appendix

### Environment Variables (Backend)

```bash
# JWT Configuration
JWT_SECRET=your-secret-key-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# DynamoDB Tables
USERS_TABLE=medusa-users-prod
PATIENTS_TABLE=medusa-patient-profiles-prod
DEVICES_TABLE=medusa-devices-prod
REFRESH_TOKENS_TABLE=medusa-refresh-tokens-prod
SESSIONS_TABLE=medusa-sessions-prod
TREMOR_TABLE=medusa-tremor-analysis
SENSOR_TABLE=medusa-sensor-data

# AWS SES (Example - replace with your verified email)
AWS_REGION=us-east-1
SES_FROM_EMAIL=noreply@your-domain.com
SES_FROM_NAME=MeDUSA System

# Feature Flags
PRODUCTION_MODE=true
ENABLE_EMAIL=true
```

### Deployment Information

**Infrastructure:**
- API Gateway v3 (REST API)
- Lambda Functions (Python 3.10, 3.11)
- DynamoDB (On-Demand billing)
- AWS SES (Email delivery)

**Monitoring:**
- CloudWatch Logs (all Lambda functions)
- CloudWatch Metrics (API Gateway, Lambda, DynamoDB)
- X-Ray Tracing (enabled on all services)

**Security:**
- HTTPS only (TLS 1.2+)
- JWT tokens with HMAC-SHA256
- bcrypt password hashing (cost factor: 12)
- Refresh token rotation
- Input validation and sanitization
- Rate limiting per IP

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | 2025-11-18 | Added tremor API, unified documentation |
| 2.0 | 2025-11-14 | Added device management, patient profiles |
| 1.0 | 2025-11-11 | Initial release with authentication |

---

## Support

For API support or bug reports:
- **Repository**: https://github.com/EM0V0/MeDUSA
- **Documentation**: This file
- **AWS Region**: us-east-1

---

**Last Updated**: February 2, 2026  
**Maintained by**: Zhicheng Sun
