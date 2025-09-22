# MeDUSA Flutter Application - Backend API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Base Configuration](#base-configuration)
3. [Authentication & Security](#authentication--security)
4. [User Management](#user-management)
5. [Patient Management](#patient-management)
6. [Medical Data & Devices](#medical-data--devices)
7. [Symptoms Tracking](#symptoms-tracking)
8. [Reports & Analytics](#reports--analytics)
9. [Messaging System](#messaging-system)
10. [Notifications & Alerts](#notifications--alerts)
11. [Profile & Settings](#profile--settings)
12. [Real-time Data Streaming](#real-time-data-streaming)
13. [Admin & System Management](#admin--system-management)
14. [Data Models](#data-models)
15. [Error Handling](#error-handling)
16. [Security Requirements](#security-requirements)

---

## Overview

This document provides comprehensive API specifications for the MeDUSA Flutter application backend. The application is a secure, enterprise-grade medical data fusion and analysis system supporting multi-platform deployment with regulatory compliance (FDA, HIPAA).

### Key Features
- **Multi-role Authentication** (Doctor, Patient, Admin)
- **Real-time Medical Data Monitoring**
- **Bluetooth Device Integration** (Raspberry Pi medical devices)
- **Secure Messaging System**
- **Two-Factor Authentication (2FA)**
- **OAuth Integration** (Google, Apple, Microsoft)
- **Comprehensive Audit Logging**
- **Advanced Analytics & Reporting**

---

## Base Configuration

### API Base URL
```
Base URL: https://localhost:7001
API Version: /api/v1
Full Base: https://localhost:7001/api/v1
```

### Network Configuration
```json
{
  "timeouts": {
    "connect": 15000,
    "receive": 15000,
    "send": 15000
  },
  "pagination": {
    "defaultPageSize": 20,
    "maxPageSize": 100
  }
}
```

### Standard Headers
```http
Content-Type: application/json
Authorization: Bearer <jwt_token>
X-API-Version: v1
X-Client-Platform: flutter
```

---

## Authentication & Security

### 1. User Authentication

#### Login
```http
POST /api/v1/user/login
```

**Request Body:**
```json
{
  "email": "string",
  "password": "string"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "string",
    "email": "string",
    "name": "string",
    "role": "doctor|patient|admin",
    "lastLogin": "2024-01-01T00:00:00.000Z",
    "isActive": true
  },
  "token": "jwt_token_string",
  "refreshToken": "refresh_token_string",
  "expiresIn": 3600
}
```

#### Register
```http
POST /api/v1/user/register
```

**Request Body:**
```json
{
  "name": "string",
  "email": "string",
  "password": "string",
  "role": "doctor|patient|admin"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "string",
    "email": "string",
    "name": "string",
    "role": "string",
    "lastLogin": null,
    "isActive": true
  },
  "token": "jwt_token_string",
  "refreshToken": "refresh_token_string"
}
```

#### Logout
```http
POST /api/v1/user/logout
```

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "success": true,
  "message": "Successfully logged out"
}
```

#### Refresh Token
```http
POST /api/v1/auth/refresh
```

**Request Body:**
```json
{
  "refreshToken": "string"
}
```

**Response:**
```json
{
  "success": true,
  "token": "new_jwt_token",
  "refreshToken": "new_refresh_token",
  "expiresIn": 3600
}
```

### 2. Two-Factor Authentication (2FA)

#### Setup 2FA
```http
POST /api/v1/auth/2fa/setup
```

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "success": true,
  "secret": "base32_secret_string",
  "qrCodeUrl": "otpauth://totp/MeDUSA%20Security:user@example.com?secret=...",
  "backupCodes": [
    "123456789",
    "987654321",
    "..."
  ]
}
```

#### Verify 2FA Setup
```http
POST /api/v1/auth/2fa/verify-setup
```

**Request Body:**
```json
{
  "code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "2FA successfully enabled"
}
```

#### Verify 2FA Code
```http
POST /api/v1/auth/2fa/verify
```

**Request Body:**
```json
{
  "code": "123456",
  "isBackupCode": false
}
```

**Response:**
```json
{
  "success": true,
  "valid": true
}
```

#### Disable 2FA
```http
POST /api/v1/auth/2fa/disable
```

**Request Body:**
```json
{
  "password": "current_password"
}
```

### 3. OAuth Integration

#### OAuth Callback Handler
```http
POST /api/v1/auth/oauth/callback
```

**Request Body:**
```json
{
  "provider": "google|apple|microsoft",
  "accessToken": "string",
  "idToken": "string",
  "userInfo": {
    "email": "string",
    "name": "string",
    "picture": "string"
  }
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "string",
    "email": "string",
    "name": "string",
    "role": "patient",
    "isActive": true,
    "oauthProvider": "google|apple|microsoft"
  },
  "token": "jwt_token_string",
  "refreshToken": "refresh_token_string"
}
```

---

## User Management

### 1. User Profile

#### Get Current User Profile
```http
GET /api/v1/user/profile
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "string",
    "email": "string",
    "name": "string",
    "role": "string",
    "lastLogin": "2024-01-01T00:00:00.000Z",
    "isActive": true,
    "profile": {
      "phone": "string",
      "address": "string",
      "dateOfBirth": "1990-01-01",
      "gender": "male|female|other",
      "emergencyContact": {
        "name": "string",
        "phone": "string",
        "relationship": "string"
      }
    }
  }
}
```

#### Update User Profile
```http
PUT /api/v1/user/profile
```

**Request Body:**
```json
{
  "name": "string",
  "phone": "string",
  "address": "string",
  "dateOfBirth": "1990-01-01",
  "gender": "male|female|other",
  "emergencyContact": {
    "name": "string",
    "phone": "string",
    "relationship": "string"
  }
}
```

### 2. Admin User Management

#### List All Users
```http
GET /api/v1/admin/users
```

**Query Parameters:**
```
page: integer (default: 1)
limit: integer (default: 20, max: 100)
search: string (search by name, email)
role: string (filter by role)
status: string (active|inactive)
sortBy: string (name|email|role|lastLogin)
sortOrder: string (asc|desc)
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "string",
      "name": "string",
      "email": "string",
      "role": "string",
      "lastLogin": "2024-01-01T00:00:00.000Z",
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00.000Z",
      "statistics": {
        "totalSessions": 42,
        "lastActivityDays": 2
      }
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 10,
    "totalItems": 200,
    "itemsPerPage": 20
  }
}
```

#### Create User
```http
POST /api/v1/admin/users
```

**Request Body:**
```json
{
  "name": "string",
  "email": "string",
  "password": "string",
  "role": "doctor|patient|admin",
  "profile": {
    "phone": "string",
    "address": "string",
    "dateOfBirth": "1990-01-01",
    "gender": "male|female|other"
  }
}
```

#### Update User
```http
PUT /api/v1/admin/users/{userId}
```

#### Delete User
```http
DELETE /api/v1/admin/users/{userId}
```

#### Get User Statistics
```http
GET /api/v1/admin/users/statistics
```

**Response:**
```json
{
  "success": true,
  "statistics": {
    "totalUsers": 1250,
    "activeUsers": 1180,
    "usersByRole": {
      "doctors": 45,
      "patients": 1150,
      "admins": 5
    },
    "newUsersThisMonth": 23,
    "userGrowthRate": 2.5
  }
}
```

---

## Patient Management

### 1. Patient Data

#### Get Patient List (Doctor View)
```http
GET /api/v1/patients
```

**Query Parameters:**
```
page: integer
limit: integer
search: string
status: stable|moderate|critical
condition: string
sortBy: name|lastReading|tremorScore|status
sortOrder: asc|desc
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "PAT-001",
      "name": "John Doe",
      "age": 65,
      "gender": "Male",
      "condition": "Parkinson's Disease",
      "status": "stable|moderate|critical",
      "lastReading": "2024-01-01T00:00:00.000Z",
      "tremorScore": 4.2,
      "phone": "+1 (555) 123-4567",
      "email": "john.doe@email.com",
      "address": "123 Main St, City, State 12345",
      "assignedDoctor": "DR-001",
      "medicalHistory": {
        "diagnosisDate": "2020-03-15",
        "medications": [
          {
            "name": "Levodopa",
            "dosage": "100mg",
            "frequency": "3x daily",
            "startDate": "2020-03-15"
          }
        ],
        "allergies": ["Penicillin"],
        "comorbidities": ["Hypertension"]
      },
      "sensorInfo": {
        "deviceId": "DEV-001",
        "status": "active|warning|inactive",
        "batteryLevel": 85,
        "lastSync": "2024-01-01T00:00:00.000Z"
      }
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 5,
    "totalItems": 100
  }
}
```

#### Get Patient Details
```http
GET /api/v1/patients/{patientId}
```

**Response:**
```json
{
  "success": true,
  "patient": {
    "id": "PAT-001",
    "personalInfo": {
      "name": "John Doe",
      "age": 65,
      "gender": "Male",
      "phone": "+1 (555) 123-4567",
      "email": "john.doe@email.com",
      "address": "123 Main St, City, State 12345",
      "emergencyContact": {
        "name": "Jane Doe",
        "phone": "+1 (555) 123-4568",
        "relationship": "Spouse"
      }
    },
    "medicalInfo": {
      "condition": "Parkinson's Disease",
      "status": "stable",
      "diagnosisDate": "2020-03-15",
      "assignedDoctor": "DR-001",
      "tremorScore": 4.2,
      "lastReading": "2024-01-01T00:00:00.000Z",
      "medications": [],
      "allergies": [],
      "comorbidities": []
    },
    "deviceInfo": {
      "deviceId": "DEV-001",
      "status": "active",
      "batteryLevel": 85,
      "lastSync": "2024-01-01T00:00:00.000Z",
      "firmwareVersion": "1.2.3"
    },
    "recentReadings": [
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "tremorScore": 4.2,
        "heartRate": 72,
        "activity": "walking",
        "medicationTaken": true
      }
    ]
  }
}
```

#### Update Patient Information
```http
PUT /api/v1/patients/{patientId}
```

**Request Body:**
```json
{
  "personalInfo": {
    "phone": "string",
    "address": "string",
    "emergencyContact": {
      "name": "string",
      "phone": "string",
      "relationship": "string"
    }
  },
  "medicalInfo": {
    "status": "stable|moderate|critical",
    "assignedDoctor": "string",
    "medications": [],
    "allergies": [],
    "comorbidities": []
  }
}
```

### 2. Patient Medical Data

#### Get Patient Medical Readings
```http
GET /api/v1/patients/{patientId}/readings
```

**Query Parameters:**
```
startDate: string (ISO date)
endDate: string (ISO date)
type: tremor|heartRate|activity|medication
interval: minute|hour|day|week
limit: integer
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "timestamp": "2024-01-01T00:00:00.000Z",
      "deviceId": "DEV-001",
      "readings": {
        "tremorScore": 4.2,
        "heartRate": 72,
        "bloodPressure": {
          "systolic": 120,
          "diastolic": 80
        },
        "activity": {
          "type": "walking",
          "duration": 1800,
          "steps": 2500
        },
        "medication": {
          "taken": true,
          "time": "2024-01-01T08:00:00.000Z",
          "medication": "Levodopa"
        }
      },
      "location": {
        "latitude": 40.7128,
        "longitude": -74.0060
      },
      "quality": "good|fair|poor"
    }
  ],
  "aggregates": {
    "averageTremorScore": 4.5,
    "averageHeartRate": 75,
    "totalSteps": 8500,
    "medicationAdherence": 0.95
  }
}
```

#### Add Medical Reading
```http
POST /api/v1/patients/{patientId}/readings
```

**Request Body:**
```json
{
  "timestamp": "2024-01-01T00:00:00.000Z",
  "deviceId": "DEV-001",
  "readings": {
    "tremorScore": 4.2,
    "heartRate": 72,
    "bloodPressure": {
      "systolic": 120,
      "diastolic": 80
    },
    "activity": {
      "type": "walking",
      "duration": 1800,
      "steps": 2500
    }
  },
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  }
}
```

---

## Medical Data & Devices

### 1. Device Management

#### Get Device List
```http
GET /api/v1/devices
```

**Query Parameters:**
```
status: active|inactive|maintenance|error
type: raspberry_pi|sensor|gateway
assignedTo: string (patient ID)
location: string
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "DEV-001",
      "name": "Tremor Sensor #001",
      "type": "raspberry_pi",
      "model": "RPi 4B",
      "status": "active|inactive|maintenance|error",
      "assignedPatient": "PAT-001",
      "location": "Home - Living Room",
      "lastSeen": "2024-01-01T00:00:00.000Z",
      "batteryLevel": 85,
      "signalStrength": -45,
      "firmwareVersion": "1.2.3",
      "serialNumber": "RPI001234567",
      "installationDate": "2023-06-15",
      "specifications": {
        "sensors": ["accelerometer", "gyroscope", "magnetometer"],
        "connectivity": ["bluetooth", "wifi"],
        "batteryType": "Li-ion 3000mAh",
        "operatingTemp": "-10°C to 50°C"
      },
      "statistics": {
        "totalReadings": 15420,
        "uptime": "99.5%",
        "lastMaintenance": "2024-01-01T00:00:00.000Z"
      }
    }
  ]
}
```

#### Get Device Details
```http
GET /api/v1/devices/{deviceId}
```

#### Update Device Configuration
```http
PUT /api/v1/devices/{deviceId}/config
```

**Request Body:**
```json
{
  "samplingRate": 100,
  "sensitivity": "high|medium|low",
  "dataTransmissionInterval": 300,
  "powerSaveMode": true,
  "alertThresholds": {
    "tremorScore": 8.0,
    "heartRate": {
      "min": 60,
      "max": 100
    },
    "batteryLevel": 20
  }
}
```

#### Send Device Command
```http
POST /api/v1/devices/{deviceId}/commands
```

**Request Body:**
```json
{
  "command": "start_collection|stop_collection|get_info|restart|calibrate",
  "parameters": {
    "duration": 3600,
    "mode": "continuous|interval"
  }
}
```

**Response:**
```json
{
  "success": true,
  "commandId": "CMD-001",
  "status": "sent|acknowledged|completed|failed",
  "result": {
    "message": "Command executed successfully",
    "data": {}
  }
}
```

### 2. Bluetooth Integration

#### Get Available Bluetooth Devices
```http
GET /api/v1/bluetooth/scan
```

**Response:**
```json
{
  "success": true,
  "devices": [
    {
      "id": "BT-001",
      "name": "MeDUSA Sensor",
      "address": "AA:BB:CC:DD:EE:FF",
      "rssi": -45,
      "services": ["12345678-1234-1234-1234-123456789abc"],
      "manufacturerData": "MeDUSA Medical Systems",
      "isConnectable": true,
      "lastSeen": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

#### Connect to Bluetooth Device
```http
POST /api/v1/bluetooth/connect
```

**Request Body:**
```json
{
  "deviceId": "BT-001",
  "patientId": "PAT-001"
}
```

#### Get Bluetooth Connection Status
```http
GET /api/v1/bluetooth/status/{deviceId}
```

**Response:**
```json
{
  "success": true,
  "status": {
    "isConnected": true,
    "connectionTime": "2024-01-01T00:00:00.000Z",
    "signalStrength": -45,
    "dataRate": 1024,
    "lastDataReceived": "2024-01-01T00:00:00.000Z",
    "statistics": {
      "totalDataReceived": 1048576,
      "packetsLost": 12,
      "connectionDrops": 2
    }
  }
}
```

---

## Symptoms Tracking

### 1. Patient Symptom Records

#### Get Symptom Records
```http
GET /api/v1/patients/{patientId}/symptoms
```

**Query Parameters:**
```
startDate: string (ISO date)
endDate: string (ISO date)
intensity: number (1-5 scale filter)
symptoms: string[] (filter by symptom types)
triggers: string[] (filter by trigger types)
page: integer
limit: integer
sortBy: timestamp|intensity
sortOrder: asc|desc
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "SYM-001",
      "patientId": "PAT-001",
      "timestamp": "2024-01-01T00:00:00.000Z",
      "intensity": 4.0,
      "symptoms": [
        "Hand tremor",
        "Difficulty writing"
      ],
      "trigger": "Stress",
      "notes": "Had an important meeting today, tremor was more noticeable",
      "location": {
        "latitude": 40.7128,
        "longitude": -74.0060
      },
      "attachments": [
        {
          "id": "ATT-001",
          "fileName": "symptom_photo.jpg",
          "fileType": "image/jpeg",
          "fileSize": 1048576,
          "thumbnailUrl": "https://api.example.com/files/ATT-001/thumbnail",
          "downloadUrl": "https://api.example.com/files/ATT-001/download"
        }
      ],
      "medicationTiming": {
        "lastTaken": "2024-01-01T08:00:00.000Z",
        "medication": "Levodopa",
        "timeSinceLastDose": 240
      },
      "activityCorrelation": {
        "activityType": "meeting",
        "stressLevel": 8,
        "environmentalFactors": ["noise", "bright lights"]
      }
    }
  ],
  "aggregates": {
    "averageIntensity": 3.2,
    "mostCommonSymptoms": ["Hand tremor", "Rigidity"],
    "frequentTriggers": ["Stress", "Caffeine", "Fatigue"],
    "intensityTrends": {
      "improving": false,
      "stable": true,
      "worsening": false
    }
  }
}
```

#### Log New Symptom Record
```http
POST /api/v1/patients/{patientId}/symptoms
```

**Request Body:**
```json
{
  "timestamp": "2024-01-01T00:00:00.000Z",
  "intensity": 4.0,
  "symptoms": [
    "Hand tremor",
    "Difficulty writing"
  ],
  "trigger": "Stress",
  "notes": "Had an important meeting today, tremor was more noticeable",
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "attachments": [
    {
      "fileName": "symptom_photo.jpg",
      "fileType": "image/jpeg",
      "fileData": "base64_encoded_image_data"
    }
  ],
  "medicationTiming": {
    "lastTaken": "2024-01-01T08:00:00.000Z",
    "medication": "Levodopa"
  },
  "activityCorrelation": {
    "activityType": "meeting",
    "stressLevel": 8,
    "environmentalFactors": ["noise", "bright lights"]
  }
}
```

**Response:**
```json
{
  "success": true,
  "symptom": {
    "id": "SYM-001",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "status": "recorded"
  }
}
```

#### Update Symptom Record
```http
PUT /api/v1/patients/{patientId}/symptoms/{symptomId}
```

#### Delete Symptom Record
```http
DELETE /api/v1/patients/{patientId}/symptoms/{symptomId}
```

#### Quick Symptom Log
```http
POST /api/v1/patients/{patientId}/symptoms/quick-log
```

**Request Body:**
```json
{
  "intensity": 3.0,
  "primarySymptom": "Hand tremor",
  "notes": "Quick log entry"
}
```

### 2. Symptom Analytics

#### Get Symptom Trends
```http
GET /api/v1/patients/{patientId}/symptoms/trends
```

**Query Parameters:**
```
timeRange: week|month|quarter|year
symptomType: string
```

**Response:**
```json
{
  "success": true,
  "trends": {
    "intensityTrend": {
      "direction": "stable|improving|worsening",
      "changePercentage": -5.2,
      "dataPoints": [
        {
          "date": "2024-01-01",
          "averageIntensity": 3.2,
          "recordCount": 5
        }
      ]
    },
    "symptomFrequency": {
      "Hand tremor": 45,
      "Rigidity": 32,
      "Difficulty writing": 28
    },
    "triggerAnalysis": {
      "Stress": 35,
      "Caffeine": 28,
      "Fatigue": 22,
      "Weather": 15
    },
    "timePatterns": {
      "morningWorst": true,
      "peakHours": ["08:00", "14:00", "20:00"],
      "bestHours": ["10:00", "16:00"]
    }
  }
}
```

---

## Reports & Analytics

### 1. Medical Reports

#### Get Report List
```http
GET /api/v1/reports
```

**Query Parameters:**
```
patientId: string
type: tremor_analysis|medication_effectiveness|daily_activity|sleep_quality|progress_tracking
status: processing|completed|failed
dateFrom: string (ISO date)
dateTo: string (ISO date)
author: string (doctor ID)
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "RPT-001",
      "title": "Weekly Tremor Analysis - John Doe",
      "type": "tremor_analysis",
      "patientId": "PAT-001",
      "patientName": "John Doe",
      "status": "completed|processing|failed",
      "createdDate": "2024-01-01T00:00:00.000Z",
      "completedDate": "2024-01-01T00:30:00.000Z",
      "author": "Dr. Smith",
      "authorId": "DR-001",
      "parameters": {
        "startDate": "2024-01-01",
        "endDate": "2024-01-07",
        "includeCharts": true,
        "includeRecommendations": true
      },
      "downloadUrl": "https://api.example.com/reports/RPT-001/download",
      "fileSize": 2048576
    }
  ]
}
```

#### Generate Report
```http
POST /api/v1/reports/generate
```

**Request Body:**
```json
{
  "type": "tremor_analysis|medication_effectiveness|daily_activity|sleep_quality|progress_tracking",
  "patientId": "PAT-001",
  "parameters": {
    "startDate": "2024-01-01",
    "endDate": "2024-01-07",
    "includeCharts": true,
    "includeRecommendations": true,
    "format": "pdf|excel|json"
  },
  "title": "Custom Report Title"
}
```

**Response:**
```json
{
  "success": true,
  "reportId": "RPT-001",
  "status": "processing",
  "estimatedCompletionTime": "2024-01-01T00:30:00.000Z"
}
```

#### Download Report
```http
GET /api/v1/reports/{reportId}/download
```

**Response:** Binary file download

#### Get Report Status
```http
GET /api/v1/reports/{reportId}/status
```

**Response:**
```json
{
  "success": true,
  "report": {
    "id": "RPT-001",
    "status": "completed",
    "progress": 100,
    "downloadUrl": "https://api.example.com/reports/RPT-001/download",
    "fileSize": 2048576,
    "error": null
  }
}
```

### 2. Analytics

#### Get Dashboard Analytics
```http
GET /api/v1/analytics/dashboard
```

**Query Parameters:**
```
timeRange: today|week|month|quarter|year
patientId: string (for doctor-specific patient analytics)
```

**Response:**
```json
{
  "success": true,
  "analytics": {
    "overview": {
      "totalPatients": 150,
      "activeDevices": 142,
      "recentAlerts": 8,
      "systemUptime": "99.8%"
    },
    "patientStats": {
      "stable": 120,
      "moderate": 25,
      "critical": 5
    },
    "deviceStats": {
      "active": 142,
      "warning": 6,
      "inactive": 2
    },
    "trends": {
      "averageTremorScore": {
        "current": 4.2,
        "previous": 4.5,
        "change": -6.7
      },
      "medicationAdherence": {
        "current": 0.94,
        "previous": 0.91,
        "change": 3.3
      }
    },
    "recentAlerts": [
      {
        "id": "ALT-001",
        "type": "high_tremor|medication_reminder|sensor_offline|low_battery",
        "severity": "info|warning|critical",
        "patientId": "PAT-001",
        "patientName": "John Doe",
        "message": "High tremor detected",
        "timestamp": "2024-01-01T00:00:00.000Z",
        "acknowledged": false
      }
    ]
  }
}
```

#### Get Patient Analytics
```http
GET /api/v1/analytics/patients/{patientId}
```

**Query Parameters:**
```
timeRange: today|week|month|quarter|year
metrics: tremor|heartRate|activity|medication|all
```

**Response:**
```json
{
  "success": true,
  "analytics": {
    "patientInfo": {
      "id": "PAT-001",
      "name": "John Doe",
      "condition": "Parkinson's Disease"
    },
    "timeRange": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-07T23:59:59.000Z"
    },
    "metrics": {
      "tremor": {
        "average": 4.2,
        "min": 2.1,
        "max": 7.8,
        "trend": "stable|improving|declining",
        "dataPoints": [
          {
            "timestamp": "2024-01-01T00:00:00.000Z",
            "value": 4.2
          }
        ]
      },
      "medication": {
        "adherence": 0.94,
        "missedDoses": 2,
        "onTimePercentage": 0.87,
        "schedule": [
          {
            "medication": "Levodopa",
            "scheduledTime": "08:00",
            "actualTime": "08:05",
            "taken": true
          }
        ]
      },
      "activity": {
        "averageSteps": 5420,
        "activeMinutes": 180,
        "sedentaryMinutes": 600,
        "sleepQuality": 7.2
      }
    },
    "alerts": [
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "type": "high_tremor",
        "severity": "warning",
        "value": 8.2,
        "threshold": 8.0
      }
    ]
  }
}
```

---

## Messaging System

### 1. Messages

#### Get Message List
```http
GET /api/v1/messages
```

**Query Parameters:**
```
conversationWith: string (user ID)
type: text|image|document|medical_report|appointment|prescription|reminder
priority: low|normal|high|urgent
isRead: boolean
page: integer
limit: integer
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "MSG-001",
      "senderId": "DR-001",
      "senderName": "Dr. Smith",
      "senderRole": "doctor",
      "receiverId": "PAT-001",
      "receiverName": "John Doe",
      "receiverRole": "patient",
      "content": "Hello John, how are you feeling today?",
      "type": "text|image|document|medical_report|appointment|prescription|reminder",
      "priority": "normal",
      "timestamp": "2024-01-01T00:00:00.000Z",
      "isRead": false,
      "attachments": [
        {
          "id": "ATT-001",
          "fileName": "report.pdf",
          "fileType": "application/pdf",
          "fileSize": 1048576,
          "thumbnailUrl": "https://api.example.com/files/ATT-001/thumbnail",
          "downloadUrl": "https://api.example.com/files/ATT-001/download"
        }
      ],
      "replyToMessageId": null
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 5,
    "totalItems": 100
  }
}
```

#### Send Message
```http
POST /api/v1/messages
```

**Request Body:**
```json
{
  "receiverId": "PAT-001",
  "content": "Hello John, how are you feeling today?",
  "type": "text|image|document|medical_report|appointment|prescription|reminder",
  "priority": "normal|high|urgent",
  "attachments": [
    {
      "fileName": "report.pdf",
      "fileType": "application/pdf",
      "fileData": "base64_encoded_file_content"
    }
  ],
  "replyToMessageId": "MSG-001"
}
```

**Response:**
```json
{
  "success": true,
  "message": {
    "id": "MSG-002",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "status": "sent"
  }
}
```

#### Mark Message as Read
```http
PUT /api/v1/messages/{messageId}/read
```

#### Get Conversation
```http
GET /api/v1/messages/conversation/{userId}
```

**Response:**
```json
{
  "success": true,
  "conversation": {
    "participantId": "PAT-001",
    "participantName": "John Doe",
    "participantRole": "patient",
    "lastMessage": {
      "content": "Thank you, Doctor!",
      "timestamp": "2024-01-01T00:00:00.000Z",
      "isRead": true
    },
    "unreadCount": 0
  },
  "messages": []
}
```

### 2. File Attachments

#### Upload File
```http
POST /api/v1/files/upload
```

**Request:** Multipart form data
```
file: binary
messageId: string (optional)
description: string (optional)
```

**Response:**
```json
{
  "success": true,
  "file": {
    "id": "FILE-001",
    "fileName": "report.pdf",
    "fileType": "application/pdf",
    "fileSize": 1048576,
    "uploadedAt": "2024-01-01T00:00:00.000Z",
    "downloadUrl": "https://api.example.com/files/FILE-001/download",
    "thumbnailUrl": "https://api.example.com/files/FILE-001/thumbnail"
  }
}
```

#### Download File
```http
GET /api/v1/files/{fileId}/download
```

---

## Notifications & Alerts

### 1. Alert Management

#### Get Alert List
```http
GET /api/v1/alerts
```

**Query Parameters:**
```
patientId: string
type: high_tremor|medication_reminder|sensor_offline|low_battery|system_alert
severity: info|warning|critical
isRead: boolean
startDate: string (ISO date)
endDate: string (ISO date)
page: integer
limit: integer
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "ALT-001",
      "patientId": "PAT-001",
      "patientName": "John Doe",
      "type": "high_tremor|medication_reminder|sensor_offline|low_battery|system_alert",
      "severity": "info|warning|critical",
      "title": "High Tremor Detected",
      "message": "Tremor score of 8.2 exceeds threshold of 8.0",
      "timestamp": "2024-01-01T00:00:00.000Z",
      "isRead": false,
      "isAcknowledged": false,
      "data": {
        "tremorScore": 8.2,
        "threshold": 8.0,
        "deviceId": "DEV-001",
        "location": "Home"
      },
      "actions": [
        {
          "type": "acknowledge",
          "label": "Acknowledge"
        },
        {
          "type": "contact_patient",
          "label": "Contact Patient"
        }
      ]
    }
  ],
  "summary": {
    "total": 25,
    "unread": 8,
    "critical": 2,
    "warning": 6,
    "info": 17
  }
}
```

#### Create Alert
```http
POST /api/v1/alerts
```

**Request Body:**
```json
{
  "patientId": "PAT-001",
  "type": "high_tremor|medication_reminder|sensor_offline|low_battery|system_alert",
  "severity": "info|warning|critical",
  "title": "High Tremor Detected",
  "message": "Tremor score of 8.2 exceeds threshold of 8.0",
  "data": {
    "tremorScore": 8.2,
    "threshold": 8.0,
    "deviceId": "DEV-001"
  },
  "notificationChannels": ["push", "email", "sms"]
}
```

#### Mark Alert as Read
```http
PUT /api/v1/alerts/{alertId}/read
```

#### Acknowledge Alert
```http
PUT /api/v1/alerts/{alertId}/acknowledge
```

**Request Body:**
```json
{
  "notes": "Contacted patient, medication adjusted"
}
```

#### Dismiss Alert
```http
DELETE /api/v1/alerts/{alertId}
```

### 2. Notification Preferences

#### Get Notification Settings
```http
GET /api/v1/users/{userId}/notifications/settings
```

**Response:**
```json
{
  "success": true,
  "settings": {
    "channels": {
      "email": {
        "enabled": true,
        "address": "user@example.com"
      },
      "sms": {
        "enabled": false,
        "phoneNumber": "+1234567890"
      },
      "push": {
        "enabled": true,
        "deviceTokens": ["token1", "token2"]
      }
    },
    "alertTypes": {
      "criticalAlerts": {
        "enabled": true,
        "channels": ["push", "email", "sms"],
        "quietHours": {
          "enabled": true,
          "start": "22:00",
          "end": "07:00"
        }
      },
      "medicationReminders": {
        "enabled": true,
        "channels": ["push"],
        "advanceMinutes": 30
      },
      "dailyReports": {
        "enabled": true,
        "channels": ["email"],
        "time": "08:00"
      },
      "weeklyReports": {
        "enabled": false,
        "channels": ["email"],
        "dayOfWeek": "monday",
        "time": "09:00"
      }
    },
    "thresholds": {
      "tremorScore": 8.0,
      "heartRate": {
        "min": 60,
        "max": 100
      },
      "batteryLevel": 20,
      "deviceOfflineMinutes": 30
    }
  }
}
```

#### Update Notification Settings
```http
PUT /api/v1/users/{userId}/notifications/settings
```

**Request Body:**
```json
{
  "channels": {
    "email": {
      "enabled": true
    },
    "sms": {
      "enabled": true,
      "phoneNumber": "+1234567890"
    }
  },
  "alertTypes": {
    "criticalAlerts": {
      "enabled": true,
      "channels": ["push", "email"]
    }
  },
  "thresholds": {
    "tremorScore": 7.5
  }
}
```

### 3. Push Notifications

#### Register Device Token
```http
POST /api/v1/notifications/devices
```

**Request Body:**
```json
{
  "deviceToken": "firebase_device_token",
  "platform": "android|ios|web",
  "deviceInfo": {
    "model": "iPhone 14",
    "osVersion": "17.0",
    "appVersion": "1.0.0"
  }
}
```

#### Send Push Notification
```http
POST /api/v1/notifications/push
```

**Request Body:**
```json
{
  "recipients": ["USER-001", "USER-002"],
  "title": "Critical Alert",
  "body": "High tremor detected for patient John Doe",
  "data": {
    "alertId": "ALT-001",
    "patientId": "PAT-001",
    "type": "high_tremor"
  },
  "priority": "high",
  "sound": "default",
  "badge": 1
}
```

---

## Profile & Settings

### 1. User Profile Management

#### Get User Profile
```http
GET /api/v1/users/{userId}/profile
```

**Response:**
```json
{
  "success": true,
  "profile": {
    "personalInfo": {
      "name": "Dr. Sarah Johnson",
      "email": "sarah.johnson@medusa.com",
      "phone": "+1 (555) 123-4567",
      "avatar": {
        "url": "https://api.example.com/avatars/user-001.jpg",
        "thumbnailUrl": "https://api.example.com/avatars/user-001-thumb.jpg"
      }
    },
    "professionalInfo": {
      "specialty": "Neurologist",
      "licenseNumber": "MD-12345678",
      "department": "Neurology Department",
      "hospital": "City General Hospital",
      "yearsOfExperience": 15,
      "certifications": [
        "Board Certified Neurologist",
        "Movement Disorders Specialist"
      ]
    },
    "preferences": {
      "language": "en",
      "timezone": "America/New_York",
      "dateFormat": "MM/DD/YYYY",
      "timeFormat": "12h"
    }
  }
}
```

#### Update User Profile
```http
PUT /api/v1/users/{userId}/profile
```

**Request Body:**
```json
{
  "personalInfo": {
    "name": "Dr. Sarah Johnson",
    "phone": "+1 (555) 123-4567"
  },
  "professionalInfo": {
    "specialty": "Neurologist",
    "department": "Neurology Department"
  },
  "preferences": {
    "language": "en",
    "timezone": "America/New_York"
  }
}
```

#### Upload Profile Picture
```http
POST /api/v1/users/{userId}/profile/avatar
```

**Request:** Multipart form data
```
avatar: binary (image file)
```

**Response:**
```json
{
  "success": true,
  "avatar": {
    "url": "https://api.example.com/avatars/user-001.jpg",
    "thumbnailUrl": "https://api.example.com/avatars/user-001-thumb.jpg",
    "uploadedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

### 2. Application Settings

#### Get User Settings
```http
GET /api/v1/users/{userId}/settings
```

**Response:**
```json
{
  "success": true,
  "settings": {
    "notifications": {
      "email": true,
      "push": true,
      "sms": false,
      "criticalAlerts": true,
      "dailyReports": true,
      "weeklyReports": false
    },
    "security": {
      "twoFactorEnabled": false,
      "biometricEnabled": true,
      "sessionTimeout": 30,
      "autoLogout": true,
      "loginNotifications": true
    },
    "display": {
      "theme": "light|dark|system",
      "language": "en",
      "dateFormat": "MM/DD/YYYY",
      "timeFormat": "12h|24h",
      "chartAnimations": true
    },
    "privacy": {
      "shareDataForResearch": false,
      "allowAnalytics": true,
      "locationTracking": true
    }
  }
}
```

#### Update User Settings
```http
PUT /api/v1/users/{userId}/settings
```

**Request Body:**
```json
{
  "notifications": {
    "email": true,
    "criticalAlerts": true
  },
  "security": {
    "sessionTimeout": 60,
    "autoLogout": false
  },
  "display": {
    "theme": "dark",
    "language": "en"
  }
}
```

### 3. Security Settings

#### Change Password
```http
POST /api/v1/users/{userId}/security/password
```

**Request Body:**
```json
{
  "currentPassword": "old_password",
  "newPassword": "new_password",
  "confirmPassword": "new_password"
}
```

#### Get Security Status
```http
GET /api/v1/users/{userId}/security/status
```

**Response:**
```json
{
  "success": true,
  "security": {
    "passwordStrength": "strong",
    "lastPasswordChange": "2024-01-01T00:00:00.000Z",
    "twoFactorEnabled": false,
    "recentLogins": [
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "ipAddress": "192.168.1.100",
        "location": "New York, NY",
        "device": "iPhone 14",
        "success": true
      }
    ],
    "activeSessions": [
      {
        "id": "SESSION-001",
        "device": "iPhone 14",
        "location": "New York, NY",
        "lastActivity": "2024-01-01T00:00:00.000Z",
        "current": true
      }
    ]
  }
}
```

#### Terminate Session
```http
DELETE /api/v1/users/{userId}/security/sessions/{sessionId}
```

#### Terminate All Sessions
```http
DELETE /api/v1/users/{userId}/security/sessions
```

---

## Real-time Data Streaming

### 1. WebSocket Connections

#### WebSocket Base URL
```
WebSocket URL: wss://localhost:7001/ws/v1
Authentication: Bearer token via query parameter or header
```

#### Connection Establishment
```javascript
// Connection URL format
wss://localhost:7001/ws/v1/connect?token=<jwt_token>&userId=<user_id>&role=<user_role>

// Connection Headers
Authorization: Bearer <jwt_token>
X-Client-Platform: flutter
X-Client-Version: 1.0.0
```

#### Connection Response
```json
{
  "type": "connection_established",
  "data": {
    "connectionId": "conn_12345",
    "userId": "USER-001",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "supportedChannels": [
      "medical_data",
      "device_status",
      "alerts",
      "messages",
      "system_status"
    ]
  }
}
```

### 2. Channel Subscriptions

#### Subscribe to Channels
```json
{
  "type": "subscribe",
  "data": {
    "channels": [
      {
        "name": "medical_data",
        "filters": {
          "patientId": "PAT-001",
          "deviceId": "DEV-001",
          "dataTypes": ["tremor", "heartRate", "temperature"]
        }
      },
      {
        "name": "alerts",
        "filters": {
          "severity": ["warning", "critical"],
          "patientIds": ["PAT-001", "PAT-002"]
        }
      }
    ]
  }
}
```

#### Subscription Confirmation
```json
{
  "type": "subscription_confirmed",
  "data": {
    "channel": "medical_data",
    "subscriptionId": "sub_12345",
    "filters": {
      "patientId": "PAT-001",
      "deviceId": "DEV-001"
    }
  }
}
```

### 3. Real-time Medical Data Stream

#### Medical Data Updates
```json
{
  "type": "medical_data",
  "channel": "medical_data",
  "data": {
    "patientId": "PAT-001",
    "deviceId": "DEV-001",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "readings": {
      "tremorScore": 4.2,
      "heartRate": 72,
      "temperature": 36.5,
      "bloodPressure": {
        "systolic": 120,
        "diastolic": 80
      },
      "accelerometer": {
        "x": 0.1,
        "y": 0.2,
        "z": 9.8
      },
      "gyroscope": {
        "x": 0.01,
        "y": 0.02,
        "z": 0.03
      }
    },
    "quality": "good",
    "batteryLevel": 85,
    "signalStrength": -45
  }
}
```

#### Bulk Data Stream
```json
{
  "type": "medical_data_batch",
  "channel": "medical_data",
  "data": {
    "patientId": "PAT-001",
    "deviceId": "DEV-001",
    "batchId": "batch_12345",
    "startTime": "2024-01-01T00:00:00.000Z",
    "endTime": "2024-01-01T00:01:00.000Z",
    "readings": [
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "tremorScore": 4.2,
        "heartRate": 72
      },
      {
        "timestamp": "2024-01-01T00:00:01.000Z",
        "tremorScore": 4.3,
        "heartRate": 73
      }
    ],
    "summary": {
      "totalReadings": 60,
      "averageTremorScore": 4.25,
      "averageHeartRate": 72.5
    }
  }
}
```

### 4. Device Status Updates

#### Device Connection Status
```json
{
  "type": "device_status",
  "channel": "device_status",
  "data": {
    "deviceId": "DEV-001",
    "patientId": "PAT-001",
    "status": "connected|disconnected|error|maintenance",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "batteryLevel": 85,
    "signalStrength": -45,
    "firmwareVersion": "1.2.3",
    "lastSeen": "2024-01-01T00:00:00.000Z",
    "location": {
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    "error": null
  }
}
```

#### Device Command Response
```json
{
  "type": "device_command_response",
  "channel": "device_status",
  "data": {
    "deviceId": "DEV-001",
    "commandId": "CMD-001",
    "command": "start_collection",
    "status": "success|failed|timeout",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "result": {
      "message": "Data collection started",
      "collectionRate": 100,
      "estimatedBatteryLife": 480
    },
    "error": null
  }
}
```

### 5. Real-time Alerts

#### Alert Notifications
```json
{
  "type": "alert",
  "channel": "alerts",
  "data": {
    "id": "ALT-001",
    "patientId": "PAT-001",
    "patientName": "John Doe",
    "type": "high_tremor|medication_reminder|sensor_offline|low_battery|system_alert",
    "severity": "info|warning|critical",
    "title": "High Tremor Detected",
    "message": "Tremor score of 8.2 exceeds threshold of 8.0",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "data": {
      "tremorScore": 8.2,
      "threshold": 8.0,
      "deviceId": "DEV-001",
      "location": "Home"
    },
    "actions": [
      {
        "type": "acknowledge",
        "label": "Acknowledge"
      },
      {
        "type": "contact_patient",
        "label": "Contact Patient"
      }
    ],
    "autoAcknowledge": false,
    "expiresAt": "2024-01-01T01:00:00.000Z"
  }
}
```

### 6. Live Messaging

#### Real-time Message Delivery
```json
{
  "type": "message",
  "channel": "messages",
  "data": {
    "id": "MSG-001",
    "conversationId": "CONV-001",
    "senderId": "DR-001",
    "senderName": "Dr. Smith",
    "senderRole": "doctor",
    "receiverId": "PAT-001",
    "receiverName": "John Doe",
    "receiverRole": "patient",
    "content": "How are you feeling today?",
    "type": "text|image|document|medical_report",
    "priority": "normal|high|urgent",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "attachments": [],
    "encrypted": true,
    "deliveryStatus": "sent|delivered|read"
  }
}
```

#### Typing Indicators
```json
{
  "type": "typing",
  "channel": "messages",
  "data": {
    "conversationId": "CONV-001",
    "userId": "DR-001",
    "userName": "Dr. Smith",
    "isTyping": true,
    "timestamp": "2024-01-01T00:00:00.000Z"
  }
}
```

### 7. Client Commands

#### Send Data to Server
```json
{
  "type": "command",
  "data": {
    "action": "device_command",
    "payload": {
      "deviceId": "DEV-001",
      "command": "start_collection",
      "parameters": {
        "duration": 3600,
        "samplingRate": 100
      }
    }
  }
}
```

#### Mark Alert as Read
```json
{
  "type": "command",
  "data": {
    "action": "mark_alert_read",
    "payload": {
      "alertId": "ALT-001"
    }
  }
}
```

#### Send Message
```json
{
  "type": "command",
  "data": {
    "action": "send_message",
    "payload": {
      "receiverId": "PAT-001",
      "content": "Hello, how are you feeling?",
      "type": "text",
      "priority": "normal"
    }
  }
}
```

### 8. Connection Management

#### Heartbeat/Ping
```json
{
  "type": "ping",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### Pong Response
```json
{
  "type": "pong",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "latency": 15
}
```

#### Unsubscribe from Channel
```json
{
  "type": "unsubscribe",
  "data": {
    "channels": ["medical_data", "alerts"]
  }
}
```

#### Connection Error
```json
{
  "type": "error",
  "data": {
    "code": "SUBSCRIPTION_FAILED",
    "message": "Failed to subscribe to medical_data channel",
    "details": "Patient PAT-001 not found or access denied",
    "timestamp": "2024-01-01T00:00:00.000Z"
  }
}
```

### 9. Server-Sent Events (SSE) Alternative

For clients that cannot use WebSockets, Server-Sent Events are available:

#### SSE Endpoint
```http
GET /api/v1/events/stream
```

**Headers:**
```http
Authorization: Bearer <jwt_token>
Accept: text/event-stream
Cache-Control: no-cache
```

**Query Parameters:**
```
channels: medical_data,alerts,messages
patientId: PAT-001 (optional)
deviceId: DEV-001 (optional)
```

**SSE Event Format:**
```
event: medical_data
data: {"patientId":"PAT-001","deviceId":"DEV-001","readings":{"tremorScore":4.2}}

event: alert
data: {"id":"ALT-001","type":"high_tremor","severity":"warning","message":"High tremor detected"}

event: heartbeat
data: {"timestamp":"2024-01-01T00:00:00.000Z","connectionId":"conn_12345"}
```

---

## Admin & System Management

### 1. System Settings

#### Get System Settings
```http
GET /api/v1/admin/settings
```

**Response:**
```json
{
  "success": true,
  "settings": {
    "general": {
      "systemName": "MeDUSA System",
      "version": "1.0.0",
      "maintenanceMode": false,
      "allowRegistration": true,
      "defaultUserRole": "patient"
    },
    "security": {
      "sessionTimeout": 30,
      "passwordMinLength": 8,
      "requireTwoFactor": false,
      "maxLoginAttempts": 5,
      "lockoutDuration": 15
    },
    "data": {
      "retentionPeriod": 2555,
      "backupFrequency": 7,
      "encryptionEnabled": true,
      "compressionEnabled": true
    },
    "notifications": {
      "emailEnabled": true,
      "smsEnabled": false,
      "pushEnabled": true,
      "alertThresholds": {
        "criticalTremor": 8.0,
        "lowBattery": 20,
        "deviceOffline": 300
      }
    }
  }
}
```

#### Update System Settings
```http
PUT /api/v1/admin/settings
```

**Request Body:**
```json
{
  "general": {
    "maintenanceMode": false,
    "allowRegistration": true
  },
  "security": {
    "sessionTimeout": 30,
    "requireTwoFactor": true
  },
  "notifications": {
    "alertThresholds": {
      "criticalTremor": 7.5
    }
  }
}
```

### 2. Audit Logs

#### Get Audit Logs
```http
GET /api/v1/admin/audit-logs
```

**Query Parameters:**
```
startDate: string (ISO date)
endDate: string (ISO date)
userId: string
action: login|logout|data_access|settings_change|user_created|user_deleted
severity: info|warning|error|critical
page: integer
limit: integer
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "AUDIT-001",
      "timestamp": "2024-01-01T00:00:00.000Z",
      "userId": "USR-001",
      "userName": "Dr. Smith",
      "action": "login|logout|data_access|settings_change|user_created|user_deleted",
      "severity": "info|warning|error|critical",
      "ipAddress": "192.168.1.100",
      "userAgent": "Mozilla/5.0...",
      "resource": "/api/v1/patients/PAT-001",
      "details": {
        "method": "GET",
        "statusCode": 200,
        "responseTime": 150,
        "additionalInfo": {}
      },
      "location": {
        "country": "US",
        "region": "NY",
        "city": "New York"
      }
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 100,
    "totalItems": 2000
  },
  "summary": {
    "totalEvents": 2000,
    "eventsByType": {
      "login": 450,
      "data_access": 1200,
      "settings_change": 50
    },
    "eventsBySeverity": {
      "info": 1800,
      "warning": 150,
      "error": 45,
      "critical": 5
    }
  }
}
```

#### Export Audit Logs
```http
POST /api/v1/admin/audit-logs/export
```

**Request Body:**
```json
{
  "format": "csv|json|excel",
  "startDate": "2024-01-01",
  "endDate": "2024-01-31",
  "filters": {
    "userId": "USR-001",
    "action": "data_access",
    "severity": "warning"
  }
}
```

**Response:**
```json
{
  "success": true,
  "exportId": "EXP-001",
  "status": "processing",
  "downloadUrl": "https://api.example.com/exports/EXP-001/download"
}
```

### 3. System Status

#### Get System Health
```http
GET /api/v1/admin/system/health
```

**Response:**
```json
{
  "success": true,
  "health": {
    "overall": "healthy|warning|critical",
    "uptime": 2592000,
    "version": "1.0.0",
    "environment": "production",
    "timestamp": "2024-01-01T00:00:00.000Z",
    "services": {
      "database": {
        "status": "healthy",
        "responseTime": 15,
        "connections": 45,
        "maxConnections": 100
      },
      "bluetooth": {
        "status": "healthy",
        "connectedDevices": 142,
        "maxDevices": 200
      },
      "fileStorage": {
        "status": "healthy",
        "usedSpace": 1073741824,
        "totalSpace": 10737418240,
        "usagePercent": 10
      },
      "messaging": {
        "status": "healthy",
        "queueSize": 12,
        "processedToday": 1420
      }
    },
    "performance": {
      "cpuUsage": 25.5,
      "memoryUsage": 68.2,
      "diskUsage": 45.0,
      "networkLatency": 12
    }
  }
}
```

---

## Data Models

### User Model
```json
{
  "id": "string",
  "email": "string",
  "name": "string",
  "role": "doctor|patient|admin",
  "lastLogin": "string (ISO date)",
  "isActive": "boolean",
  "profile": {
    "phone": "string",
    "address": "string",
    "dateOfBirth": "string (ISO date)",
    "gender": "male|female|other",
    "emergencyContact": {
      "name": "string",
      "phone": "string",
      "relationship": "string"
    }
  },
  "preferences": {
    "language": "string",
    "timezone": "string",
    "notifications": {
      "email": "boolean",
      "sms": "boolean",
      "push": "boolean"
    }
  },
  "security": {
    "twoFactorEnabled": "boolean",
    "lastPasswordChange": "string (ISO date)",
    "oauthProvider": "google|apple|microsoft|null"
  }
}
```

### Patient Model
```json
{
  "id": "string",
  "personalInfo": {
    "name": "string",
    "age": "number",
    "gender": "string",
    "phone": "string",
    "email": "string",
    "address": "string",
    "emergencyContact": {
      "name": "string",
      "phone": "string",
      "relationship": "string"
    }
  },
  "medicalInfo": {
    "condition": "string",
    "status": "stable|moderate|critical",
    "diagnosisDate": "string (ISO date)",
    "assignedDoctor": "string",
    "tremorScore": "number",
    "lastReading": "string (ISO date)",
    "medications": [
      {
        "name": "string",
        "dosage": "string",
        "frequency": "string",
        "startDate": "string (ISO date)",
        "endDate": "string (ISO date) | null"
      }
    ],
    "allergies": ["string"],
    "comorbidities": ["string"]
  },
  "deviceInfo": {
    "deviceId": "string",
    "status": "active|warning|inactive",
    "batteryLevel": "number",
    "lastSync": "string (ISO date)",
    "firmwareVersion": "string"
  }
}
```

### Medical Reading Model
```json
{
  "id": "string",
  "patientId": "string",
  "deviceId": "string",
  "timestamp": "string (ISO date)",
  "readings": {
    "tremorScore": "number",
    "heartRate": "number",
    "bloodPressure": {
      "systolic": "number",
      "diastolic": "number"
    },
    "activity": {
      "type": "walking|sitting|lying|standing",
      "duration": "number (seconds)",
      "steps": "number"
    },
    "medication": {
      "taken": "boolean",
      "time": "string (ISO date)",
      "medication": "string"
    }
  },
  "location": {
    "latitude": "number",
    "longitude": "number"
  },
  "quality": "good|fair|poor",
  "processed": "boolean",
  "alerts": [
    {
      "type": "high_tremor|low_heart_rate|medication_missed",
      "severity": "info|warning|critical",
      "threshold": "number",
      "value": "number"
    }
  ]
}
```

### Device Model
```json
{
  "id": "string",
  "name": "string",
  "type": "raspberry_pi|sensor|gateway",
  "model": "string",
  "status": "active|inactive|maintenance|error",
  "assignedPatient": "string | null",
  "location": "string",
  "lastSeen": "string (ISO date)",
  "batteryLevel": "number",
  "signalStrength": "number",
  "firmwareVersion": "string",
  "serialNumber": "string",
  "installationDate": "string (ISO date)",
  "specifications": {
    "sensors": ["string"],
    "connectivity": ["string"],
    "batteryType": "string",
    "operatingTemp": "string"
  },
  "configuration": {
    "samplingRate": "number",
    "sensitivity": "high|medium|low",
    "dataTransmissionInterval": "number",
    "powerSaveMode": "boolean",
    "alertThresholds": {
      "tremorScore": "number",
      "heartRate": {
        "min": "number",
        "max": "number"
      },
      "batteryLevel": "number"
    }
  },
  "statistics": {
    "totalReadings": "number",
    "uptime": "string",
    "lastMaintenance": "string (ISO date)",
    "averageDataQuality": "number"
  }
}
```

### Symptom Record Model
```json
{
  "id": "string",
  "patientId": "string",
  "timestamp": "string (ISO date)",
  "intensity": "number (1-5 scale)",
  "symptoms": ["string"],
  "trigger": "string",
  "notes": "string",
  "location": {
    "latitude": "number",
    "longitude": "number"
  },
  "attachments": [
    {
      "id": "string",
      "fileName": "string",
      "fileType": "string",
      "fileSize": "number",
      "thumbnailUrl": "string | null",
      "downloadUrl": "string"
    }
  ],
  "medicationTiming": {
    "lastTaken": "string (ISO date)",
    "medication": "string",
    "timeSinceLastDose": "number (minutes)"
  },
  "activityCorrelation": {
    "activityType": "string",
    "stressLevel": "number (1-10 scale)",
    "environmentalFactors": ["string"]
  },
  "processed": "boolean",
  "qualityScore": "number (1-10 scale)"
}
```

**Note**: The core symptom record structure includes:
- **Required fields**: `id`, `timestamp`, `intensity`, `symptoms`, `trigger`, `notes`
- **Optional fields**: `location`, `attachments`, `medicationTiming`, `activityCorrelation`
- **Intensity scale**: 1-5 (1=Very Mild, 2=Mild, 3=Moderate, 4=Severe, 5=Very Severe)
- **Common symptoms**: "Hand tremor", "Difficulty writing", "Rigidity", "Balance issues"
- **Common triggers**: "Stress", "Caffeine", "Fatigue", "Weather", "Medication timing"

### Alert Model
```json
{
  "id": "string",
  "patientId": "string | null",
  "patientName": "string | null",
  "type": "high_tremor|medication_reminder|sensor_offline|low_battery|system_alert",
  "severity": "info|warning|critical",
  "title": "string",
  "message": "string",
  "timestamp": "string (ISO date)",
  "isRead": "boolean",
  "isAcknowledged": "boolean",
  "acknowledgedBy": "string | null",
  "acknowledgedAt": "string (ISO date) | null",
  "data": {
    "tremorScore": "number | null",
    "threshold": "number | null",
    "deviceId": "string | null",
    "batteryLevel": "number | null",
    "location": "string | null"
  },
  "actions": [
    {
      "type": "string",
      "label": "string",
      "url": "string | null"
    }
  ],
  "expiresAt": "string (ISO date) | null"
}
```

### Message Model
```json
{
  "id": "string",
  "senderId": "string",
  "senderName": "string",
  "senderRole": "doctor|patient|admin",
  "receiverId": "string",
  "receiverName": "string",
  "receiverRole": "doctor|patient|admin",
  "content": "string",
  "type": "text|image|document|medical_report|appointment|prescription|reminder",
  "priority": "low|normal|high|urgent",
  "timestamp": "string (ISO date)",
  "isRead": "boolean",
  "attachments": [
    {
      "id": "string",
      "fileName": "string",
      "fileType": "string",
      "fileSize": "number",
      "thumbnailUrl": "string | null",
      "downloadUrl": "string"
    }
  ],
  "replyToMessageId": "string | null",
  "metadata": {
    "encrypted": "boolean",
    "deliveryStatus": "sent|delivered|read|failed",
    "retryCount": "number"
  }
}
```

---

## Error Handling

### Standard Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "string",
    "message": "string",
    "details": "string | object",
    "timestamp": "string (ISO date)",
    "path": "string",
    "requestId": "string"
  }
}
```

### Common Error Codes

#### Authentication Errors (401)
- `AUTH_TOKEN_MISSING`: Authorization token not provided
- `AUTH_TOKEN_INVALID`: Invalid or malformed token
- `AUTH_TOKEN_EXPIRED`: Token has expired
- `AUTH_CREDENTIALS_INVALID`: Invalid username/password
- `AUTH_2FA_REQUIRED`: 2FA verification required
- `AUTH_2FA_INVALID`: Invalid 2FA code

#### Authorization Errors (403)
- `AUTH_INSUFFICIENT_PERMISSIONS`: User lacks required permissions
- `AUTH_ROLE_REQUIRED`: Specific role required for this operation
- `AUTH_RESOURCE_FORBIDDEN`: Access to resource denied

#### Validation Errors (400)
- `VALIDATION_FAILED`: Request validation failed
- `VALIDATION_MISSING_FIELD`: Required field missing
- `VALIDATION_INVALID_FORMAT`: Invalid field format
- `VALIDATION_CONSTRAINT_VIOLATION`: Data constraint violation

#### Resource Errors (404)
- `RESOURCE_NOT_FOUND`: Requested resource not found
- `USER_NOT_FOUND`: User not found
- `PATIENT_NOT_FOUND`: Patient not found
- `DEVICE_NOT_FOUND`: Device not found
- `MESSAGE_NOT_FOUND`: Message not found

#### Business Logic Errors (422)
- `BUSINESS_RULE_VIOLATION`: Business rule violated
- `DEVICE_ALREADY_ASSIGNED`: Device already assigned to patient
- `PATIENT_ALREADY_HAS_DEVICE`: Patient already has assigned device
- `REPORT_GENERATION_FAILED`: Report generation failed

#### System Errors (500)
- `INTERNAL_SERVER_ERROR`: Internal server error
- `DATABASE_ERROR`: Database operation failed
- `EXTERNAL_SERVICE_ERROR`: External service unavailable
- `FILE_PROCESSING_ERROR`: File processing failed

#### Rate Limiting (429)
- `RATE_LIMIT_EXCEEDED`: API rate limit exceeded
- `TOO_MANY_REQUESTS`: Too many requests in time window

---

## Security Requirements

### 1. Authentication & Authorization
- **JWT Tokens**: All API calls require valid JWT token
- **Token Expiration**: Tokens expire after 1 hour
- **Refresh Tokens**: Long-lived refresh tokens for seamless experience
- **Role-Based Access**: Strict role-based permissions (Doctor, Patient, Admin)
- **2FA Support**: Optional two-factor authentication
- **OAuth Integration**: Support for Google, Apple, Microsoft sign-in

### 2. Data Protection
- **Encryption in Transit**: All API calls must use HTTPS/TLS 1.3
- **Encryption at Rest**: All sensitive data encrypted at rest
- **Data Anonymization**: Personal data anonymized in logs
- **HIPAA Compliance**: Full HIPAA compliance for medical data
- **Data Retention**: Configurable data retention policies

### 3. API Security
- **Rate Limiting**: Configurable rate limits per endpoint
- **Request Validation**: Strict input validation and sanitization
- **SQL Injection Protection**: Parameterized queries only
- **XSS Protection**: Content Security Policy headers
- **CSRF Protection**: CSRF tokens for state-changing operations

### 4. Audit & Monitoring
- **Comprehensive Logging**: All API calls logged with details
- **Security Event Monitoring**: Real-time security event detection
- **Anomaly Detection**: Unusual access pattern detection
- **Data Access Tracking**: Complete audit trail for medical data access
- **Export Capabilities**: Audit log export for compliance

### 5. Device Security
- **Secure Pairing**: Encrypted Bluetooth device pairing
- **Device Authentication**: Mutual authentication between app and devices
- **Command Validation**: Strict validation of device commands
- **Firmware Verification**: Device firmware integrity verification

### 6. File Security
- **Secure Upload**: Virus scanning and file type validation
- **Access Control**: File access based on user permissions
- **Temporary URLs**: Time-limited download URLs
- **File Encryption**: Medical files encrypted at rest

---

## Implementation Notes

### 1. Database Considerations
- Use appropriate indexing for patient queries
- Implement proper foreign key constraints
- Consider partitioning for large medical data tables
- Implement soft deletes for audit trail preservation

### 2. Performance Optimization
- Implement caching for frequently accessed data
- Use pagination for large datasets
- Optimize queries for medical data aggregation
- Consider read replicas for analytics queries

### 3. Real-time Features
- WebSocket connections for real-time device data
- Push notifications for critical alerts
- Real-time messaging between doctors and patients
- Live device status monitoring

### 4. Scalability
- Horizontal scaling capabilities
- Load balancing for high availability
- Database sharding for large deployments
- CDN for file storage and delivery

### 5. Compliance & Standards
- FHIR compatibility for medical data exchange
- HL7 standards for healthcare interoperability
- FDA cybersecurity guidelines compliance
- GDPR compliance for European users

### 6. Additional Features & Considerations

#### Real-time Data Streaming
- WebSocket connections for live medical data
- Server-Sent Events (SSE) for real-time alerts
- Real-time device status updates
- Live symptom monitoring dashboards

#### File Handling & Storage
- Secure file upload with virus scanning
- Image processing and thumbnail generation
- PDF report generation and storage
- Medical document attachment support
- Profile picture upload and management

#### Geolocation & Context
- Location-based symptom correlation
- Environmental factor tracking
- Timezone-aware scheduling
- Location-based device pairing

#### Advanced Analytics
- Machine learning integration for symptom prediction
- Trend analysis and pattern recognition
- Medication effectiveness correlation
- Risk assessment algorithms

#### Integration Capabilities
- Third-party medical device APIs
- Electronic Health Record (EHR) integration
- Pharmacy management system integration
- Insurance and billing system APIs

#### Mobile-Specific Features
- Offline data synchronization
- Background data collection
- Push notification scheduling
- Biometric authentication support

---

## API Endpoint Summary

### Total Endpoints: **83 API Endpoints + WebSocket/SSE**

#### By Category:
- **Authentication & Security**: 8 endpoints
- **User Management**: 8 endpoints  
- **Patient Management**: 6 endpoints
- **Symptoms Tracking**: 6 endpoints
- **Medical Data & Devices**: 10 endpoints
- **Reports & Analytics**: 7 endpoints
- **Messaging System**: 8 endpoints
- **Notifications & Alerts**: 9 endpoints
- **Profile & Settings**: 12 endpoints
- **Real-time Data Streaming**: 4 endpoints (WebSocket + SSE)
- **Admin & System Management**: 9 endpoints

#### Real-time Features:
- **WebSocket Channels**: 5 channels (medical_data, device_status, alerts, messages, system_status)
- **SSE Streams**: 1 endpoint with multiple event types
- **Live Data Types**: Medical readings, device status, alerts, messages, typing indicators

#### By HTTP Method:
- **GET**: 35 endpoints (data retrieval)
- **POST**: 25 endpoints (data creation)
- **PUT**: 12 endpoints (data updates)
- **DELETE**: 6 endpoints (data deletion)

#### By Security Level:
- **Public**: 3 endpoints (login, register, health check)
- **User Authenticated**: 45 endpoints (standard user operations)
- **Role-Based**: 20 endpoints (doctor/patient specific)
- **Admin Only**: 10 endpoints (system administration)

---

This comprehensive API documentation provides backend developers with complete specifications for implementing the MeDUSA Flutter application. All endpoints include proper error handling, validation, security measures, and compliance requirements as outlined in the security section.
