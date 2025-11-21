import json
import boto3
import os
import numpy as np
from decimal import Decimal
from datetime import datetime
from scipy.signal import butter, filtfilt
from scipy.fft import rfft, rfftfreq

dynamodb = boto3.resource('dynamodb')
sensor_table = dynamodb.Table('medusa-sensor-data')
results_table = dynamodb.Table('medusa-tremor-analysis')  # Store analysis results
devices_table = dynamodb.Table('medusa-devices-prod')     # Device registry for ownership lookup


class ButterworthLowPass:
    """Butterworth low-pass filter implementation."""

    def __init__(self, cutoff, fs, order=4):
        self.cutoff = cutoff
        self.fs = fs
        self.order = order

    def apply(self, data):
        """Apply Butterworth low-pass filter to data."""
        nyq = 0.5 * self.fs
        normal_cutoff = self.cutoff / nyq
        b, a = butter(self.order, normal_cutoff, btype='low', analog=False)
        return filtfilt(b, a, data)


class TremorProcessor:
    """Extract features relevant to Parkinson's tremor detection."""

    def __init__(self, fs=100, tremor_band=(3, 6), filter_cutoff=12):
        """
        Initialize tremor processor.

        Args:
            fs: Sampling frequency (Hz).
            tremor_band: Frequency range for Parkinson's tremor (Hz).
            filter_cutoff: Low-pass filter cutoff frequency (Hz).
        """
        self.fs = fs
        self.tremor_band = tremor_band
        self.filter = ButterworthLowPass(filter_cutoff, fs)

    def process(self, data_array):
        """
        Process sensor data to extract tremor features.

        Args:
            data_array: Array of raw accelerometer values.

        Returns:
            Dictionary of extracted features:
              - rms: RMS value of the filtered data.
              - dominant_freq: Frequency with highest amplitude.
              - tremor_power: Power in the 3–6 Hz band.
              - tremor_index: Ratio of tremor band power to total power.
              - is_parkinsonian: Boolean decision based on thresholds.
        """
        # Apply low-pass filter
        filtered_data = self.filter.apply(data_array)

        # Calculate RMS value
        rms = np.sqrt(np.mean(np.square(filtered_data)))

        # Compute FFT
        fft_values = rfft(filtered_data)
        freqs = rfftfreq(len(filtered_data), 1 / self.fs)
        fft_magnitude = np.abs(fft_values)

        # Skip DC component (index 0) for peak detection
        fft_magnitude_no_dc = fft_magnitude[1:]
        freqs_no_dc = freqs[1:]

        # Tremor band (3-6 Hz)
        tremor_mask = (freqs_no_dc >= self.tremor_band[0]) & (freqs_no_dc <= self.tremor_band[1])
        tremor_power = np.sum(fft_magnitude_no_dc[tremor_mask] ** 2) if np.any(tremor_mask) else 0

        # Dominant frequency (excluding DC)
        dom_idx = np.argmax(fft_magnitude_no_dc)
        dominant_freq = freqs_no_dc[dom_idx] if dom_idx < len(freqs_no_dc) else 0

        # Tremor index: ratio of tremor band power to total power
        total_power = np.sum(fft_magnitude_no_dc ** 2)
        tremor_index = tremor_power / total_power if total_power > 0 else 0

        return {
            'rms': float(rms),
            'dominant_freq': float(dominant_freq),
            'tremor_power': float(tremor_power),
            'tremor_index': float(tremor_index),
            'is_parkinsonian': bool(self.tremor_band[0] <= dominant_freq <= self.tremor_band[1] and tremor_index > 0.3)
        }


def decimal_to_float(obj):
    """Convert DynamoDB Decimal objects to float for numpy processing."""
    if isinstance(obj, list):
        return [decimal_to_float(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: decimal_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj


def lambda_handler(event, context):
    """
    Process sensor data from DynamoDB to extract Parkinson's tremor features.
    
    Triggered by:
    - Scheduled EventBridge rule (batch processing)
    - Manual invocation with specific device_id and time range
    
    Args:
        event: Dict containing:
            - device_id: Device to process (required)
            - patient_id: Patient filter (optional)
            - start_timestamp: Start time for data window (optional, default: last 5 minutes)
            - end_timestamp: End time for data window (optional, default: now)
            - window_size: Minimum samples needed for analysis (default: 100)
            - sampling_rate: Expected sampling rate in Hz (default: 100)
    
    Returns:
        Status and analysis results
    """
    
    # Parse input parameters
    device_id = event.get('device_id')
    patient_id = event.get('patient_id')
    window_size = event.get('window_size', 100)  # Minimum 100 samples for FFT
    sampling_rate = event.get('sampling_rate', 100)  # 100 Hz default
    
    if not device_id:
        return {'statusCode': 400, 'body': 'Missing device_id'}
    
    # Lookup patient_id from device registry if not provided
    # This ensures data is correctly attributed to the current owner
    if not patient_id or patient_id == "UNASSIGNED":
        try:
            device_record = devices_table.get_item(Key={'id': device_id})
            if 'Item' in device_record:
                patient_id = device_record['Item'].get('patientId')
                print(f"Resolved patient_id {patient_id} for device {device_id}")
        except Exception as e:
            print(f"Error looking up device owner: {e}")

    # Time range (default: last 5 minutes)
    now = int(datetime.utcnow().timestamp())
    end_timestamp = event.get('end_timestamp', now)
    start_timestamp = event.get('start_timestamp', now - 300)  # 5 min window
    
    try:
        # Prepare query parameters
        query_params = {
            'KeyConditionExpression': 'device_id = :did AND #ts BETWEEN :start AND :end',
            'ExpressionAttributeNames': {
                '#ts': 'timestamp'  # 'timestamp' is a reserved word
            },
            'ExpressionAttributeValues': {
                ':did': device_id,
                ':start': start_timestamp,
                ':end': end_timestamp
            },
            'ScanIndexForward': True  # Oldest first for time series
        }
        
        # DON'T filter by patient_id in sensor data since it may be outdated
        # We use the patient_id from device registry (resolved above) for the analysis result
        # This allows us to process old sensor data with incorrect patient_ids
        
        response = sensor_table.query(**query_params)
        items = response['Items']
        
        # Handle pagination if more than 1MB of data
        while 'LastEvaluatedKey' in response:
            query_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
            response = sensor_table.query(**query_params)
            items.extend(response['Items'])
        
        if len(items) < window_size:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'status': 'insufficient_data',
                    'message': f'Only {len(items)} samples found, need {window_size}',
                    'device_id': device_id
                })
            }
        
        # Convert Decimal to float for numpy processing
        items = decimal_to_float(items)
        
        # Extract accelerometer magnitude time series
        # Data format: accelerometer_x/y/z are Lists of values
        magnitude_data = []
        
        for item in items:
            x_vals = item.get('accelerometer_x', [])
            y_vals = item.get('accelerometer_y', [])
            z_vals = item.get('accelerometer_z', [])
            
            # Calculate magnitude for each sample in this record
            if x_vals and y_vals and z_vals:
                for x, y, z in zip(x_vals, y_vals, z_vals):
                    mag = np.sqrt(x**2 + y**2 + z**2)
                    magnitude_data.append(mag)
        
        magnitude_data = np.array(magnitude_data)
        
        if len(magnitude_data) < window_size:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'status': 'insufficient_data',
                    'message': f'Only {len(magnitude_data)} samples found, need {window_size}',
                    'device_id': device_id
                })
            }
        
        # Initialize tremor processor
        processor = TremorProcessor(
            fs=sampling_rate,
            tremor_band=(3, 6),  # Parkinson's tremor frequency range
            filter_cutoff=12
        )
        
        # Process data and extract features
        features = processor.process(magnitude_data)
        
        # Prepare analysis result for storage
        # Use end_timestamp as the analysis timestamp so historical processing is accurate
        analysis_ts = end_timestamp
        
        # Use the resolved patient_id, fallback to item's patient_id, then UNASSIGNED
        final_patient_id = patient_id if patient_id else items[0].get('patient_id', 'UNASSIGNED')
        
        analysis_result = {
            'device_id': device_id,
            'patient_id': final_patient_id,
            'patient_name': items[0].get('patient_name'),
            'analysis_timestamp': int(analysis_ts),
            'timestamp': datetime.utcfromtimestamp(int(analysis_ts)).isoformat() + 'Z', # Add ISO timestamp for querying
            'window_start': start_timestamp,
            'window_end': end_timestamp,
            'sample_count': len(items),
            'sampling_rate': sampling_rate,
            
            # Tremor features (convert to Decimal for DynamoDB)
            'rms': Decimal(str(features['rms'])),
            'dominant_freq': Decimal(str(features['dominant_freq'])),
            'tremor_power': Decimal(str(features['tremor_power'])),
            'tremor_index': Decimal(str(features['tremor_index'])),
            'tremor_score': Decimal(str(features['tremor_index'] * 100)),
            'is_parkinsonian': features['is_parkinsonian'],
            
            # Metadata
            'processed_at': int(datetime.utcnow().timestamp()),
            'ttl': int(datetime.utcnow().timestamp()) + (90 * 24 * 60 * 60)  # 90 days retention
        }
        
        # Store analysis result in DynamoDB
        results_table.put_item(Item=analysis_result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'device_id': device_id,
                'patient_id': analysis_result['patient_id'],
                'analysis': {
                    'rms': features['rms'],
                    'dominant_freq': features['dominant_freq'],
                    'tremor_power': features['tremor_power'],
                    'tremor_index': features['tremor_index'],
                    'is_parkinsonian': features['is_parkinsonian']
                },
                'samples_processed': len(items)
            })
        }
        
    except Exception as e:
        print(f"Error processing sensor data: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': str(e),
                'device_id': device_id
            })
        }
