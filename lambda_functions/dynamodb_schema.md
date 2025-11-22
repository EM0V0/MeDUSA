# DynamoDB Table Schema for MeDUSA Tremor Monitoring System

## Overview
This document defines the DynamoDB tables used in the MeDUSA tremor monitoring system.
The design prioritizes:
1. **Patient-centric queries** - Primary access pattern is by patient_id
2. **Time-series data** - Efficient range queries on timestamps
3. **Cost optimization** - On-demand billing for variable workloads
4. **Data lifecycle** - Automatic TTL-based deletion

---

## Table 1: medusa-sensor-data

Stores raw accelerometer readings from wearable devices.

### Primary Key
- **Partition Key**: `device_id` (String) - Device identifier
- **Sort Key**: `timestamp` (Number) - Unix timestamp (milliseconds) when data was collected

### Attributes

| Attribute Name | Type | Description | Required |
|----------------|------|-------------|----------|
| `device_id` | String | Device identifier (e.g., "DEV-001") | Yes |
| `timestamp` | Number | Unix timestamp (milliseconds) | Yes |
| `patient_id` | String | Patient identifier (e.g., "PAT-001") | Yes |
| `accel_x` | Number | X-axis acceleration sample | Yes |
| `accel_y` | Number | Y-axis acceleration sample | Yes |
| `accel_z` | Number | Z-axis acceleration sample | Yes |
| `sampling_rate` | Number | Sampling frequency (Hz), typically 100 | No |
| `battery_level` | Number | Device battery percentage (0-100) | No |
| `signal_strength` | Number | Bluetooth signal strength (dBm) | No |
| `device_status` | String | Device status (active/low_battery/error) | No |

### Purpose
- Stores raw sensor data for Lambda processing
- Retention: 30 days (no TTL, managed by Lambda or manual cleanup)
- Write pattern: High frequency (100Hz per device)
- Read pattern: Lambda batch processing (query recent data)

---

## Table 2: medusa-tremor-analysis

Stores processed tremor analysis results.

### Primary Key
- **Partition Key**: `patient_id` (String) - Patient identifier
- **Sort Key**: `timestamp` (String) - ISO 8601 timestamp (e.g., "2023-10-27T10:00:00Z")

### Attributes

| Attribute Name | Type | Description | Required |
|----------------|------|-------------|----------|
| `patient_id` | String | Patient identifier (e.g., "PAT-001") | Yes |
| `timestamp` | String | ISO 8601 timestamp | Yes |
| `analysis_timestamp` | Number | Unix timestamp (seconds) | Yes |
| `device_id` | String | Device identifier (e.g., "DEV-001") | Yes |
| `tremor_index` | Number | Tremor power ratio (0-1), higher = more tremor | Yes |
| `tremor_score` | Number | Tremor score (0-100), derived from index | Yes |
| `dominant_freq` | Number | Dominant frequency in spectrum (Hz) | Yes |
| `is_parkinsonian` | Boolean | True if tremor in 3-6 Hz band with index > 0.3 | Yes |
| `rms` | Number | Root mean square of filtered acceleration | Yes |
| `tremor_power` | Number | Spectral power in 3-6 Hz tremor band | Yes |
| `ttl` | Number | Time-to-live timestamp for auto-deletion (90 days) | Yes |

### Global Secondary Indexes

#### DeviceIndex (Optional but recommended)
- **Partition Key**: `device_id` (String)
- **Sort Key**: `timestamp` (String)
- **Projection**: ALL
- **Purpose**: Query all analyses for a specific device (useful for device diagnostics)
- **Use case**: Monitor device behavior, detect sensor failures

### Access Patterns

1. **Get patient tremor history** (Primary)
   - Query: `patient_id = "PAT-001"` AND `timestamp BETWEEN start_iso AND end_iso`
   - Uses: Primary key
   - Typical limit: 500 records (last 24 hours at 5-min intervals)

2. **Get device-specific data** (Secondary)
   - Query: `device_id = "DEV-001"` AND `timestamp BETWEEN start_iso AND end_iso`
   - Uses: DeviceIndex GSI
   - Use case: Device troubleshooting

3. **Get latest reading for patient** (Common)
   - Query: `patient_id = "PAT-001"` ORDER BY `timestamp DESC` LIMIT 1
   - Uses: Primary key with ScanIndexForward=False

### AWS CLI Creation Commands

#### Create sensor-data table
```bash
aws dynamodb create-table \
  --table-name medusa-sensor-data \
  --attribute-definitions \
    AttributeName=patient_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
  --key-schema \
    AttributeName=patient_id,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 \
  --tags Key=Project,Value=MeDUSA Key=Environment,Value=Production
```

#### Create tremor-analysis table
```bash
aws dynamodb create-table \
  --table-name medusa-tremor-analysis \
  --attribute-definitions \
    AttributeName=patient_id,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
    AttributeName=device_id,AttributeType=S \
  --key-schema \
    AttributeName=patient_id,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --global-secondary-indexes \
    "[
      {
        \"IndexName\": \"DeviceIndex\",
        \"KeySchema\": [
          {\"AttributeName\":\"device_id\",\"KeyType\":\"HASH\"},
          {\"AttributeName\":\"timestamp\",\"KeyType\":\"RANGE\"}
        ],
        \"Projection\": {\"ProjectionType\":\"ALL\"}
      }
    ]" \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 \
  --tags Key=Project,Value=MeDUSA Key=Environment,Value=Production
```

#### Enable TTL on tremor-analysis
```bash
aws dynamodb update-time-to-live \
  --table-name medusa-tremor-analysis \
  --time-to-live-specification \
    Enabled=true,AttributeName=ttl \
  --region us-east-1
```
          {\"AttributeName\":\"analysis_timestamp\",\"KeyType\":\"RANGE\"}
        ],
        \"Projection\": {\"ProjectionType\":\"ALL\"}
      }
    ]" \
  --billing-mode PAY_PER_REQUEST
```

### Query Examples

#### Get all analyses for a device
```bash
aws dynamodb query \
  --table-name medusa-tremor-analysis \
  --key-condition-expression "device_id = :did" \
  --expression-attribute-values '{":did":{"S":"device_001"}}'
```

#### Get analyses for a device in time range
```bash
aws dynamodb query \
  --table-name medusa-tremor-analysis \
  --key-condition-expression "device_id = :did AND analysis_timestamp BETWEEN :start AND :end" \
  --expression-attribute-values '{
    ":did":{"S":"device_001"},
    ":start":{"N":"1700000000"},
    ":end":{"N":"1700100000"}
  }'
```

#### Get all analyses for a patient (using GSI)
```bash
aws dynamodb query \
  --table-name medusa-tremor-analysis \
  --index-name patient-analysis-index \
  --key-condition-expression "patient_id = :pid" \
  --expression-attribute-values '{":pid":{"S":"patient_123"}}'
```

#### Get only Parkinsonian detections for a patient
```bash
aws dynamodb query \
  --table-name medusa-tremor-analysis \
  --index-name patient-analysis-index \
  --key-condition-expression "patient_id = :pid" \
  --filter-expression "is_parkinsonian = :true" \
  --expression-attribute-values '{
    ":pid":{"S":"patient_123"},
    ":true":{"BOOL":true}
  }'
```

### Sample Item
```json
{
  "device_id": "device_001",
  "analysis_timestamp": 1700000000,
  "patient_id": "patient_123",
  "patient_name": "John Doe",
  "window_start": 1699999700,
  "window_end": 1700000000,
  "sample_count": 150,
  "sampling_rate": 100,
  "rms": 9.8359,
  "dominant_freq": 4.60,
  "tremor_power": 15532.6681,
  "tremor_index": 0.8551,
  "is_parkinsonian": true,
  "processed_at": 1700000005,
  "ttl": 1707776005
}
```

### Access Patterns

1. **Query by device and time**: Use primary key
2. **Query by patient**: Use `patient-analysis-index` GSI
3. **Get latest analysis for device**: Query with `ScanIndexForward=False` and `Limit=1`
4. **Count tremor episodes**: Use filter expression on `is_parkinsonian`

### Performance Considerations

- **Partition**: Device ID ensures even distribution if devices are balanced
- **TTL**: Automatically deletes data after 90 days (7,776,000 seconds)
- **Billing**: On-demand mode recommended for variable workload
- **GSI**: Patient index allows efficient patient-level queries

### Monitoring

Monitor these CloudWatch metrics:
- `ConsumedReadCapacityUnits`
- `ConsumedWriteCapacityUnits`
- `UserErrors` (throttling)
- `SystemErrors`

Set alarms on throttling if using provisioned capacity.
