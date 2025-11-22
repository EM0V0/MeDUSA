# Lambda Functions for MeDUSA Sensor Data Processing

## Overview

This directory contains AWS Lambda functions for processing sensor data from Parkinson's disease monitoring devices.

## Functions

### 1. `process_sensor_data.py`
Processes accelerometer data to extract Parkinson's tremor features using signal processing algorithms.

**Features Extracted:**
- **RMS**: Root mean square of filtered acceleration
- **Dominant Frequency**: Peak frequency in FFT spectrum
- **Tremor Power**: Power in 3-6 Hz band (Parkinson's tremor range)
- **Tremor Index**: Ratio of tremor band power to total power
- **Is Parkinsonian**: Boolean classification based on thresholds

**Input Event Format:**
```json
{
  "device_id": "device_001",
  "patient_id": "patient_123",
  "start_timestamp": 1700000000,
  "end_timestamp": 1700000300,
  "window_size": 100,
  "sampling_rate": 100
}
```

**Output:**
```json
{
  "statusCode": 200,
  "body": {
    "status": "success",
    "device_id": "device_001",
    "patient_id": "patient_123",
    "analysis": {
      "rms": 0.45,
      "dominant_freq": 4.5,
      "tremor_power": 0.23,
      "tremor_index": 0.42,
      "is_parkinsonian": true
    },
    "samples_processed": 150
  }
}
```

### 2. `enrich_code/lambda_function.py` (Enrichment Lambda)
Enriches raw IoT sensor data with patient information from the `medusa-device-patient-mapping` table.

**Trigger:**
- AWS IoT Core Rule (Topic: `medusa/+/sensor/data`)

**Input Event Format (from IoT Core):**
```json
{
  "device_id": "medusa-pi-01",
  "timestamp": 1700000000123,
  "accel_x": 0.12,
  "accel_y": 0.05,
  "accel_z": 9.81,
  "magnitude": 9.81,
  "sequence": 123,
  "ttl": 1702592000
}
```

**Output (to DynamoDB `medusa-sensor-data`):**
- Adds `patient_id`, `patient_name`, `assignment_timestamp`, `enriched_at`.

## Deployment

### Prerequisites
- AWS CLI configured
- IAM role with permissions:
  - `dynamodb:Query` on `medusa-sensor-data`
  - `dynamodb:PutItem` on `medusa-tremor-analysis`
  - CloudWatch Logs access

### Create Deployment Package

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create deployment package
mkdir package
pip install -r requirements.txt -t package/
cp process_sensor_data.py package/
cd package
zip -r ../process_sensor_data.zip .
cd ..
```

### Deploy Lambda

```bash
aws lambda create-function \
  --function-name medusa-process-sensor-data \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR_ACCOUNT:role/medusa-lambda-role \
  --handler process_sensor_data.lambda_handler \
  --zip-file fileb://process_sensor_data.zip \
  --timeout 60 \
  --memory-size 512
```

### Create DynamoDB Table for Results

```bash
aws dynamodb create-table \
  --table-name medusa-tremor-analysis \
  --attribute-definitions \
    AttributeName=device_id,AttributeType=S \
    AttributeName=analysis_timestamp,AttributeType=N \
  --key-schema \
    AttributeName=device_id,KeyType=HASH \
    AttributeName=analysis_timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --time-to-live-specification \
    Enabled=true,AttributeName=ttl
```

### Schedule Periodic Processing (Optional)

Create EventBridge rule to trigger analysis every 5 minutes:

```bash
aws events put-rule \
  --name medusa-periodic-analysis \
  --schedule-expression "rate(5 minutes)"

aws events put-targets \
  --rule medusa-periodic-analysis \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT:function:medusa-process-sensor-data"
```

## Testing

### Manual Invocation

```bash
aws lambda invoke \
  --function-name medusa-process-sensor-data \
  --payload '{"device_id":"device_001","window_size":100}' \
  response.json

cat response.json
```

### Test Locally

```python
import json
from process_sensor_data import lambda_handler

event = {
    "device_id": "device_001",
    "patient_id": "patient_123",
    "window_size": 100
}

result = lambda_handler(event, None)
print(json.dumps(result, indent=2))
```

## Algorithm Details

### Butterworth Low-Pass Filter
- **Order**: 4th order
- **Cutoff**: 12 Hz
- **Type**: Zero-phase filtfilt (forward-backward)
- **Purpose**: Remove high-frequency noise while preserving tremor signal

### Tremor Detection
- **Frequency Band**: 3-6 Hz (typical Parkinson's rest tremor)
- **Threshold**: tremor_index > 0.3 AND dominant_freq in [3, 6] Hz
- **FFT**: Real FFT (rfft) optimized for real-valued signals

### Classification Logic
A sample is classified as Parkinsonian tremor if:
1. Dominant frequency falls in 3-6 Hz range
2. Tremor index (tremor power / total power) > 0.3

## Performance Considerations

- **Memory**: 512 MB recommended (scipy/numpy are memory-intensive)
- **Timeout**: 60 seconds (allows processing ~10,000 samples)
- **Batch Size**: Process 100-1000 samples per invocation
- **Cold Start**: ~3-5 seconds due to scipy/numpy imports

## Monitoring

- CloudWatch Logs: `/aws/lambda/medusa-process-sensor-data`
- Metrics: Invocations, Duration, Errors, Throttles
- Alarms: Set on error rate > 1%

## Troubleshooting

**"insufficient_data" response:**
- Increase time window or reduce `window_size` parameter
- Check if device is actively sending data

**Import errors (scipy/numpy):**
- Ensure dependencies are packaged correctly
- Use Lambda layer for large dependencies (recommended)

**Timeout errors:**
- Reduce batch size
- Increase Lambda timeout setting
- Consider parallel processing for multiple devices

## Future Enhancements

- [ ] Real-time streaming analysis with Kinesis
- [ ] ML model integration for advanced classification
- [ ] Multi-axis tremor analysis (separate X, Y, Z)
- [ ] Trend analysis over time windows
- [ ] Alert notifications for high tremor episodes
