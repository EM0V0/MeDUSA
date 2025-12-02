"""
Process real Pi sensor data and generate tremor analysis with correct patient_id.
This script reads from medusa-sensor-data and writes to medusa-tremor-analysis.
"""

import boto3
from decimal import Decimal
from datetime import datetime
import numpy as np
from scipy.signal import butter, filtfilt
from scipy.fft import rfft, rfftfreq

dynamodb = boto3.resource('dynamodb')
sensor_table = dynamodb.Table('medusa-sensor-data')
results_table = dynamodb.Table('medusa-tremor-analysis')
devices_table = dynamodb.Table('medusa-devices-prod')


def butter_lowpass_filter(data, cutoff=12, fs=100, order=4):
    """Apply Butterworth low-pass filter."""
    nyq = 0.5 * fs
    normal_cutoff = cutoff / nyq
    b, a = butter(order, normal_cutoff, btype='low', analog=False)
    return filtfilt(b, a, data)


def process_tremor(data_array, fs=100):
    """Extract tremor features from accelerometer data."""
    # Apply low-pass filter
    filtered_data = butter_lowpass_filter(data_array, cutoff=12, fs=fs)
    
    # Calculate RMS
    rms = float(np.sqrt(np.mean(np.square(filtered_data))))
    
    # Compute FFT
    fft_values = rfft(filtered_data)
    freqs = rfftfreq(len(filtered_data), 1 / fs)
    fft_magnitude = np.abs(fft_values)
    
    # Skip DC component
    fft_magnitude_no_dc = fft_magnitude[1:]
    freqs_no_dc = freqs[1:]
    
    # Tremor band (3-6 Hz)
    tremor_mask = (freqs_no_dc >= 3) & (freqs_no_dc <= 6)
    tremor_power = float(np.sum(fft_magnitude_no_dc[tremor_mask] ** 2)) if np.any(tremor_mask) else 0
    
    # Dominant frequency
    dom_idx = np.argmax(fft_magnitude_no_dc)
    dominant_freq = float(freqs_no_dc[dom_idx]) if dom_idx < len(freqs_no_dc) else 0
    
    # Tremor index
    total_power = float(np.sum(fft_magnitude_no_dc ** 2))
    tremor_index = tremor_power / total_power if total_power > 0 else 0
    
    # Is Parkinsonian
    is_parkinsonian = bool(3 <= dominant_freq <= 6 and tremor_index > 0.3)
    
    return {
        'rms_value': rms,
        'dominant_frequency': dominant_freq,
        'tremor_power': tremor_power,
        'total_power': total_power,
        'tremor_index': tremor_index,
        'tremor_score': tremor_index * 100,
        'is_parkinsonian': is_parkinsonian,
        'signal_quality': 0.95  # Assuming good quality
    }


def process_pi_data(device_id='DEV-002', num_windows=20):
    """Process real Pi sensor data."""
    
    print(f"Processing sensor data for device: {device_id}")
    
    # Get patient_id from device registry
    device_record = devices_table.get_item(Key={'id': device_id})
    if 'Item' not in device_record:
        print(f"Error: Device {device_id} not found in registry")
        return 0
    
    patient_id = device_record['Item'].get('patientId', 'UNASSIGNED')
    print(f"Device owner: {patient_id}")
    
    # Query sensor data
    response = sensor_table.query(
        KeyConditionExpression='device_id = :did',
        ExpressionAttributeValues={':did': device_id},
        ScanIndexForward=False,  # Newest first
        Limit=num_windows * 100  # Get enough data for multiple windows
    )
    
    items = response.get('Items', [])
    print(f"Found {len(items)} sensor data records")
    
    if len(items) < 100:
        print(f"Insufficient data: need at least 100 samples")
        return 0
    
    # Process in windows of 100 samples
    processed_count = 0
    for i in range(0, min(len(items), num_windows * 100), 100):
        window = items[i:i+100]
        if len(window) < 100:
            break
        
        # Extract accelerometer magnitude
        magnitudes = []
        for item in window:
            x_vals = [float(v) for v in item.get('accelerometer_x', [])]
            y_vals = [float(v) for v in item.get('accelerometer_y', [])]
            z_vals = [float(v) for v in item.get('accelerometer_z', [])]
            
            if x_vals and y_vals and z_vals:
                # Calculate magnitude for each sample
                mag = [np.sqrt(x**2 + y**2 + z**2) for x, y, z in zip(x_vals, y_vals, z_vals)]
                magnitudes.extend(mag)
        
        if len(magnitudes) < 100:
            continue
        
        # Take first 100 samples
        data_array = np.array(magnitudes[:100])
        
        # Process tremor features
        features = process_tremor(data_array)
        
        # Use timestamp from the middle of the window
        mid_item = window[len(window)//2]
        timestamp_unix = int(mid_item.get('timestamp', 0))
        timestamp_iso = datetime.utcfromtimestamp(timestamp_unix).isoformat() + 'Z'
        
        # Create tremor analysis record
        analysis_result = {
            'patient_id': patient_id,  # Use correct patient_id from device registry
            'timestamp': timestamp_iso,
            'device_id': device_id,
            'rms_value': Decimal(str(round(features['rms_value'], 4))),
            'dominant_frequency': Decimal(str(round(features['dominant_frequency'], 2))),
            'tremor_power': Decimal(str(round(features['tremor_power'], 2))),
            'total_power': Decimal(str(round(features['total_power'], 2))),
            'tremor_index': Decimal(str(round(features['tremor_index'], 4))),
            'tremor_score': Decimal(str(round(features['tremor_score'], 2))),
            'is_parkinsonian': features['is_parkinsonian'],
            'signal_quality': Decimal(str(features['signal_quality'])),
            'ttl': timestamp_unix + (90 * 24 * 60 * 60)  # 90 days retention
        }
        
        # Store in DynamoDB
        results_table.put_item(Item=analysis_result)
        processed_count += 1
        
        if processed_count % 5 == 0:
            print(f"  Processed {processed_count} windows...")
    
    print(f"✅ Successfully created {processed_count} tremor analysis records")
    print(f"   Patient ID: {patient_id}")
    print(f"   Device ID: {device_id}")
    
    return processed_count


if __name__ == '__main__':
    count = process_pi_data(device_id='DEV-002', num_windows=20)
    print(f"\n🎉 Done! Created {count} real tremor analysis records from Pi sensor data.")
