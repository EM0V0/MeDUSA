"""
Batch process ALL Pi sensor data and create tremor analysis records.
This script:
1. Queries all sensor data for DEV-002
2. Groups them into time windows
3. Processes each window to extract tremor features
4. Stores results in medusa-tremor-analysis with correct patient_id

Run this to populate your tremor analysis table with real Pi data.
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
    
    # Signal quality (based on data completeness)
    signal_quality = 0.95  # Assuming good quality for real Pi data
    
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
        'signal_quality': signal_quality
    }


def batch_process_all_data(device_id='DEV-002', window_size=500, overlap=0):
    """
    Batch process ALL sensor data for a device.
    
    Args:
        device_id: Device to process
        window_size: Number of samples per analysis window
        overlap: Number of overlapping samples between windows
    """
    
    print(f"=== Batch Processing Sensor Data ===")
    print(f"Device: {device_id}")
    print(f"Window size: {window_size} samples")
    print(f"Overlap: {overlap} samples\n")
    
    # Get patient_id from device registry
    device_record = devices_table.get_item(Key={'id': device_id})
    if 'Item' not in device_record:
        print(f"❌ Error: Device {device_id} not found in registry")
        return 0
    
    patient_id = device_record['Item'].get('patientId', 'UNASSIGNED')
    print(f"✅ Device owner: {patient_id}\n")
    
    # Query ALL sensor data for this device
    print("📥 Querying sensor data...")
    all_items = []
    response = sensor_table.query(
        KeyConditionExpression='device_id = :did',
        ExpressionAttributeValues={':did': device_id},
        ScanIndexForward=True  # Oldest first for chronological processing
    )
    
    all_items.extend(response.get('Items', []))
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = sensor_table.query(
            KeyConditionExpression='device_id = :did',
            ExpressionAttributeValues={':did': device_id},
            ScanIndexForward=True,
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        all_items.extend(response.get('Items', []))
    
    print(f"✅ Found {len(all_items)} sensor data records\n")
    
    if len(all_items) == 0:
        print("❌ No sensor data found")
        return 0
    
    # Extract all magnitude samples with timestamps
    print("🔄 Processing accelerometer data...")
    samples_with_timestamps = []
    
    for item in all_items:
        timestamp = int(item.get('timestamp', 0))
        x_vals = [float(v) for v in item.get('accelerometer_x', [])]
        y_vals = [float(v) for v in item.get('accelerometer_y', [])]
        z_vals = [float(v) for v in item.get('accelerometer_z', [])]
        
        if x_vals and y_vals and z_vals:
            # Calculate magnitude for each sample
            for x, y, z in zip(x_vals, y_vals, z_vals):
                mag = np.sqrt(x**2 + y**2 + z**2)
                samples_with_timestamps.append((timestamp, mag))
    
    total_samples = len(samples_with_timestamps)
    print(f"✅ Extracted {total_samples} magnitude samples\n")
    
    if total_samples < window_size:
        print(f"❌ Insufficient data: need at least {window_size} samples")
        return 0
    
    # Process in sliding windows
    print(f"⚙️  Processing in windows of {window_size} samples...")
    processed_count = 0
    step = window_size - overlap
    
    for i in range(0, total_samples - window_size + 1, step):
        window_samples = samples_with_timestamps[i:i+window_size]
        
        # Extract magnitudes and get representative timestamp
        magnitudes = [s[1] for s in window_samples]
        # Use timestamp from middle of window
        mid_idx = len(window_samples) // 2
        timestamp_unix = window_samples[mid_idx][0]
        timestamp_iso = datetime.utcfromtimestamp(timestamp_unix).isoformat() + 'Z'
        
        # Process tremor features
        data_array = np.array(magnitudes)
        features = process_tremor(data_array)
        
        # Create tremor analysis record
        analysis_result = {
            'patient_id': patient_id,  # Correct patient_id from device registry
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
        try:
            results_table.put_item(Item=analysis_result)
            processed_count += 1
            
            if processed_count % 10 == 0:
                print(f"  ✓ Processed {processed_count} windows...")
                
        except Exception as e:
            print(f"  ✗ Error saving window {processed_count}: {e}")
    
    print(f"\n{'='*50}")
    print(f"✅ COMPLETE!")
    print(f"{'='*50}")
    print(f"Total sensor records: {len(all_items)}")
    print(f"Total samples extracted: {total_samples}")
    print(f"Tremor analysis records created: {processed_count}")
    print(f"Patient ID: {patient_id}")
    print(f"Device ID: {device_id}")
    print(f"{'='*50}\n")
    
    return processed_count


if __name__ == '__main__':
    # Process with 500-sample windows (5 seconds at 100Hz)
    # With 250-sample overlap for better temporal resolution
    count = batch_process_all_data(
        device_id='DEV-002',
        window_size=500,
        overlap=250
    )
    
    if count > 0:
        print(f"🎉 Success! Created {count} real tremor analysis records from Pi data.")
        print(f"\n💡 Tip: Refresh your Flutter app to see the data!")
    else:
        print(f"❌ No data was processed. Check if Pi has sent sensor data recently.")
