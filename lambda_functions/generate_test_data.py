"""
Generate test tremor data for MeDUSA system.

This script creates synthetic sensor data and writes it to DynamoDB tables:
1. medusa-sensor-data: Raw accelerometer readings
2. medusa-tremor-analysis: Processed tremor features

Run this after deploying DynamoDB tables to populate them with test data.
"""

import boto3
import numpy as np
import time
from datetime import datetime, timedelta
from decimal import Decimal
import argparse

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')
analysis_table = dynamodb.Table('medusa-tremor-analysis')


def generate_tremor_signal(duration_seconds=5, sampling_rate=100, tremor_freq=4.5, amplitude=0.5):
    """
    Generate synthetic tremor signal (Parkinsonian pattern).
    
    Args:
        duration_seconds: Length of signal in seconds
        sampling_rate: Sampling frequency (Hz)
        tremor_freq: Tremor frequency (Hz) - typical Parkinson's is 3-6 Hz
        amplitude: Tremor amplitude
        
    Returns:
        numpy array of accelerometer values
    """
    num_samples = int(duration_seconds * sampling_rate)
    t = np.linspace(0, duration_seconds, num_samples)
    
    # Base tremor signal (sinusoidal)
    tremor = amplitude * np.sin(2 * np.pi * tremor_freq * t)
    
    # Add some variability (amplitude modulation)
    modulation = 0.3 * np.sin(2 * np.pi * 0.5 * t)
    tremor = tremor * (1 + modulation)
    
    # Add noise
    noise = 0.05 * np.random.randn(num_samples)
    
    return tremor + noise


def generate_normal_movement(duration_seconds=5, sampling_rate=100):
    """
    Generate normal movement signal (low frequency, minimal tremor).
    
    Returns:
        numpy array of accelerometer values
    """
    num_samples = int(duration_seconds * sampling_rate)
    t = np.linspace(0, duration_seconds, num_samples)
    
    # Low frequency movement (0.5-1 Hz)
    movement = 0.2 * np.sin(2 * np.pi * 0.8 * t)
    
    # Add noise
    noise = 0.1 * np.random.randn(num_samples)
    
    return movement + noise


def write_sensor_data(patient_id, device_id, timestamp, accel_data):
    """Write raw sensor data to DynamoDB."""
    
    # Convert numpy arrays to Python lists (DynamoDB doesn't support numpy)
    item = {
        'patient_id': patient_id,
        'timestamp': int(timestamp),
        'device_id': device_id,
        'accelerometer_x': [Decimal(str(round(x, 4))) for x in accel_data['x']],
        'accelerometer_y': [Decimal(str(round(y, 4))) for y in accel_data['y']],
        'accelerometer_z': [Decimal(str(round(z, 4))) for z in accel_data['z']],
        'sampling_rate': 100,
        'battery_level': np.random.randint(70, 100),
        'signal_strength': np.random.randint(-60, -40),
        'device_status': 'active'
    }
    
    sensor_table.put_item(Item=item)
    return item


def calculate_tremor_features(accel_x):
    """
    Calculate tremor features from accelerometer data.
    This mimics the Lambda function's processing.
    """
    from scipy.signal import butter, filtfilt
    from scipy.fft import rfft, rfftfreq
    
    # Apply Butterworth filter
    nyq = 0.5 * 100  # 100 Hz sampling rate
    normal_cutoff = 12 / nyq
    b, a = butter(4, normal_cutoff, btype='low', analog=False)
    filtered = filtfilt(b, a, accel_x)
    
    # Calculate RMS
    rms = float(np.sqrt(np.mean(filtered ** 2)))
    
    # FFT analysis
    fft_vals = rfft(filtered)
    fft_freqs = rfftfreq(len(filtered), 1/100)
    
    # Remove DC component
    fft_vals[0] = 0
    
    # Power spectrum
    power_spectrum = np.abs(fft_vals) ** 2
    
    # Find tremor band (3-6 Hz)
    tremor_mask = (fft_freqs >= 3) & (fft_freqs <= 6)
    tremor_power = float(np.sum(power_spectrum[tremor_mask]))
    total_power = float(np.sum(power_spectrum[1:]))  # Exclude DC
    
    # Tremor index
    tremor_index = tremor_power / total_power if total_power > 0 else 0
    
    # Dominant frequency
    dominant_idx = np.argmax(power_spectrum[1:]) + 1
    dominant_freq = float(fft_freqs[dominant_idx])
    
    # Classification
    is_parkinsonian = tremor_index > 0.3 and 3 <= dominant_freq <= 6
    
    return {
        'tremor_index': tremor_index,
        'rms_value': rms,
        'dominant_frequency': dominant_freq,
        'tremor_power': tremor_power,
        'total_power': total_power,
        'is_parkinsonian': is_parkinsonian,
        'signal_quality': 0.9 + np.random.random() * 0.1  # Mock quality score
    }


def write_analysis_data(patient_id, device_id, timestamp, features):
    """Write tremor analysis results to DynamoDB."""
    
    # Calculate TTL (90 days from now)
    ttl = int((datetime.now() + timedelta(days=90)).timestamp())
    
    # Convert timestamp to ISO 8601 string if it's a number
    if isinstance(timestamp, (int, float)):
        timestamp_str = datetime.fromtimestamp(timestamp).isoformat() + 'Z'
    else:
        timestamp_str = timestamp
    
    item = {
        'patient_id': patient_id,
        'timestamp': timestamp_str,
        'device_id': device_id,
        'tremor_index': Decimal(str(round(features['tremor_index'], 4))),
        'tremor_score': Decimal(str(round(features['tremor_index'] * 100, 2))),
        'rms_value': Decimal(str(round(features['rms_value'], 4))),
        'dominant_frequency': Decimal(str(round(features['dominant_frequency'], 2))),
        'tremor_power': Decimal(str(round(features['tremor_power'], 4))),
        'total_power': Decimal(str(round(features['total_power'], 4))),
        'is_parkinsonian': features['is_parkinsonian'],
        'signal_quality': Decimal(str(round(features['signal_quality'], 2))),
        'ttl': ttl
    }
    
    analysis_table.put_item(Item=item)
    return item


def generate_patient_data(patient_id, device_id, hours=24, points_per_hour=12):
    """
    Generate complete test dataset for one patient.
    
    Args:
        patient_id: Patient identifier (e.g., 'PAT-001')
        device_id: Device identifier (e.g., 'DEV-001')
        hours: Number of hours of historical data
        points_per_hour: Data points per hour (12 = every 5 minutes)
    """
    
    print(f"\nGenerating data for {patient_id} ({device_id})...")
    print(f"  Time range: {hours} hours")
    print(f"  Data points: {hours * points_per_hour}")
    
    now = datetime.now()
    total_points = hours * points_per_hour
    
    for i in range(total_points):
        # Calculate timestamp (going backwards from now)
        minutes_ago = (total_points - i - 1) * (60 // points_per_hour)
        timestamp = (now - timedelta(minutes=minutes_ago)).timestamp()
        
        # Alternate between tremor and normal movement
        if i % 3 == 0:  # 33% tremor episodes
            accel_x = generate_tremor_signal(
                tremor_freq=4.5 + np.random.uniform(-0.5, 0.5),
                amplitude=0.5 + np.random.uniform(-0.1, 0.1)
            )
        else:  # 67% normal movement
            accel_x = generate_normal_movement()
        
        # Generate Y and Z axes (correlated but different)
        accel_y = accel_x * 0.8 + np.random.randn(len(accel_x)) * 0.05
        accel_z = accel_x * 0.6 + np.random.randn(len(accel_x)) * 0.05
        
        accel_data = {
            'x': accel_x,
            'y': accel_y,
            'z': accel_z
        }
        
        # Write sensor data
        write_sensor_data(patient_id, device_id, timestamp, accel_data)
        
        # Calculate and write analysis
        features = calculate_tremor_features(accel_x)
        write_analysis_data(patient_id, device_id, timestamp, features)
        
        # Progress indicator
        if (i + 1) % 10 == 0:
            progress = (i + 1) / total_points * 100
            print(f"  Progress: {progress:.0f}% ({i+1}/{total_points})", end='\r')
    
    print(f"\n✓ Completed {total_points} data points for {patient_id}")


def main():
    parser = argparse.ArgumentParser(description='Generate test tremor data for MeDUSA')
    parser.add_argument('--patients', type=int, default=1, help='Number of patients (default: 1)')
    parser.add_argument('--hours', type=int, default=24, help='Hours of data per patient (default: 24)')
    parser.add_argument('--rate', type=int, default=12, help='Data points per hour (default: 12)')
    parser.add_argument('--check-tables', action='store_true', help='Check if tables exist')
    
    args = parser.parse_args()
    
    print("========================================")
    print("MeDUSA Test Data Generator")
    print("========================================")
    
    # Check if tables exist
    if args.check_tables:
        print("\nChecking DynamoDB tables...")
        try:
            sensor_table.table_status
            print(f"✓ Table exists: medusa-sensor-data")
        except:
            print(f"✗ Table NOT found: medusa-sensor-data")
            print("  Create it first: aws dynamodb create-table ...")
            return
        
        try:
            analysis_table.table_status
            print(f"✓ Table exists: medusa-tremor-analysis")
        except:
            print(f"✗ Table NOT found: medusa-tremor-analysis")
            print("  Create it first: aws dynamodb create-table ...")
            return
    
    # Generate data
    print(f"\nGenerating test data:")
    print(f"  Patients: {args.patients}")
    print(f"  Duration: {args.hours} hours per patient")
    print(f"  Rate: {args.rate} points/hour ({60//args.rate} minutes apart)")
    print(f"  Total points: {args.patients * args.hours * args.rate}")
    
    start_time = time.time()
    
    for p in range(args.patients):
        patient_id = f"PAT-{p+1:03d}"  # PAT-001, PAT-002, etc.
        device_id = f"DEV-{p+1:03d}"
        
        generate_patient_data(
            patient_id=patient_id,
            device_id=device_id,
            hours=args.hours,
            points_per_hour=args.rate
        )
    
    elapsed = time.time() - start_time
    
    print("\n========================================")
    print("Data Generation Complete!")
    print("========================================")
    print(f"Time elapsed: {elapsed:.1f} seconds")
    print(f"Total records written: {args.patients * args.hours * args.rate * 2}")
    print(f"  - Sensor data: {args.patients * args.hours * args.rate}")
    print(f"  - Analysis data: {args.patients * args.hours * args.rate}")
    print("\nNext steps:")
    print("  1. Query the API to verify data:")
    print(f"     curl 'https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/api/v1/tremor/analysis?patient_id=PAT-001'")
    print("  2. Run the Flutter app to see the charts")
    print("")


if __name__ == '__main__':
    main()
