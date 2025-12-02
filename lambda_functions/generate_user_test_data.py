"""
Generate test tremor data for a specific user ID.
This allows testing with actual user accounts instead of hardcoded PAT-XXX IDs.

Usage:
    python generate_user_test_data.py <user_id_or_email> [--hours 24] [--rate 12]

Examples:
    python generate_user_test_data.py kdu9@jh.edu --hours 24
    python generate_user_test_data.py 550e8400-e29b-41d4-a716-446655440000 --hours 48
"""

import boto3
import numpy as np
import time
from datetime import datetime, timedelta
from decimal import Decimal
import argparse
import sys

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
users_table = dynamodb.Table('medusa-users-prod')
sensor_table = dynamodb.Table('medusa-sensor-data')
analysis_table = dynamodb.Table('medusa-tremor-analysis')


def get_user_id(email_or_id):
    """Get user id from email or validate id exists."""
    # Check if it's an email
    if '@' in email_or_id:
        try:
            # Use scan since EmailIndex might not exist
            print(f"Searching for user with email: {email_or_id}")
            response = users_table.scan(
                FilterExpression='email = :email',
                ExpressionAttributeValues={':email': email_or_id}
            )
            if response['Items']:
                user = response['Items'][0]
                user_id = user.get('id')
                print(f"✓ Found user: {user.get('name', '')} ({user.get('email')})")
                print(f"  User ID: {user_id}")
                print(f"  Role: {user.get('role', 'unknown')}")
                return user_id
            else:
                print(f"✗ No user found with email: {email_or_id}")
                return None
        except Exception as e:
            print(f"✗ Error querying user by email: {e}")
            return None
    else:
        # Assume it's a user id, validate it exists
        try:
            response = users_table.get_item(Key={'id': email_or_id})
            if 'Item' in response:
                user = response['Item']
                print(f"✓ Found user: {user.get('name', '')} ({user.get('email')})")
                print(f"  User ID: {user['id']}")
                print(f"  Role: {user.get('role', 'unknown')}")
                return email_or_id
            else:
                print(f"✗ No user found with ID: {email_or_id}")
                return None
        except Exception as e:
            print(f"✗ Error querying user by ID: {e}")
            return None


def generate_tremor_signal(duration_seconds=5, sampling_rate=100, tremor_freq=4.5, amplitude=0.5):
    """Generate synthetic tremor signal (Parkinsonian pattern)."""
    num_samples = int(duration_seconds * sampling_rate)
    t = np.linspace(0, duration_seconds, num_samples)
    
    # Base tremor signal
    tremor = amplitude * np.sin(2 * np.pi * tremor_freq * t)
    
    # Add variability
    modulation = 0.3 * np.sin(2 * np.pi * 0.5 * t)
    tremor = tremor * (1 + modulation)
    
    # Add noise
    noise = 0.05 * np.random.randn(num_samples)
    
    return tremor + noise


def write_sensor_data(patient_id, device_id, timestamp_unix, accel_data):
    """Write sensor data to DynamoDB."""
    sensor_table.put_item(
        Item={
            'device_id': device_id,  # Primary key
            'timestamp': timestamp_unix,  # Range key - Unix timestamp as NUMBER
            'patient_id': patient_id,
            'accel_x': accel_data[0],
            'accel_y': accel_data[1],
            'accel_z': accel_data[2],
            'created_at': datetime.utcnow().isoformat() + 'Z'
        }
    )


def calculate_features(signal):
    """Calculate tremor features from signal."""
    return {
        'mean': float(np.mean(signal)),
        'std': float(np.std(signal)),
        'max': float(np.max(signal)),
        'min': float(np.min(signal)),
        'rms': float(np.sqrt(np.mean(signal**2)))
    }


def write_analysis_data(patient_id, device_id, timestamp_str, features):
    """Write analysis data to DynamoDB."""
    
    # Convert numpy floats to Decimal for DynamoDB
    def to_decimal(value):
        if isinstance(value, dict):
            return {k: to_decimal(v) for k, v in value.items()}
        return Decimal(str(value)) if isinstance(value, (int, float)) else value
    
    analysis_table.put_item(
        Item={
            'patient_id': patient_id,
            'timestamp': timestamp_str,  # ISO string format
            'device_id': device_id,
            'tremor_score': to_decimal(features['tremor_score']),
            'tremor_frequency': to_decimal(features['tremor_frequency']),
            'tremor_amplitude': to_decimal(features['tremor_amplitude']),
            'signal_quality': to_decimal(features['signal_quality']),
            'is_parkinsonian': features['is_parkinsonian'],
            'features': to_decimal(features['raw_features']),
            'created_at': datetime.utcnow().isoformat() + 'Z'
        }
    )


def generate_user_data(user_id, device_id='DEV-TEST-001', hours=24, points_per_hour=12):
    """Generate test data for a specific user."""
    print(f"\n{'='*60}")
    print(f"Generating data for user: {user_id}")
    print(f"Device: {device_id}")
    print(f"Duration: {hours} hours")
    print(f"Rate: {points_per_hour} points/hour ({60//points_per_hour} min apart)")
    print(f"{'='*60}\n")
    
    now = datetime.utcnow()
    total_points = hours * points_per_hour
    time_delta = timedelta(hours=hours)
    start_time = now - time_delta
    
    point_interval = timedelta(hours=1.0/points_per_hour)
    
    for i in range(total_points):
        timestamp = start_time + (i * point_interval)
        timestamp_str = timestamp.isoformat() + 'Z'  # ISO format for analysis table
        timestamp_unix = int(timestamp.timestamp())  # Unix for sensor table
        
        # Generate tremor signal (5 seconds at 100 Hz)
        tremor = generate_tremor_signal(
            duration_seconds=5,
            sampling_rate=100,
            tremor_freq=np.random.uniform(3.5, 5.5),  # Typical PD range
            amplitude=np.random.uniform(0.3, 0.8)
        )
        
        # Calculate features
        tremor_freq = np.random.uniform(3.5, 5.5)
        tremor_amp = np.abs(tremor).max()
        
        features = {
            'tremor_score': min(100, max(0, tremor_amp * 100 + np.random.uniform(-10, 10))),
            'tremor_frequency': tremor_freq,
            'tremor_amplitude': tremor_amp,
            'signal_quality': np.random.uniform(0.7, 0.99),
            'is_parkinsonian': tremor_freq >= 3.0 and tremor_freq <= 6.0,
            'raw_features': calculate_features(tremor)
        }
        
        # Simulated accelerometer data
        accel_data = {
            0: Decimal(str(np.random.uniform(-2, 2))),
            1: Decimal(str(np.random.uniform(-2, 2))),
            2: Decimal(str(np.random.uniform(8, 12)))  # Gravity + tremor
        }
        
        # Write to DynamoDB
        write_sensor_data(user_id, device_id, timestamp_unix, accel_data)
        write_analysis_data(user_id, device_id, timestamp_str, features)
        
        if (i + 1) % 10 == 0:
            progress = (i + 1) / total_points * 100
            print(f"Progress: {i+1}/{total_points} ({progress:.1f}%)")
    
    print(f"\n✓ Completed {total_points} data points for user {user_id}")
    print(f"  Latest timestamp: {timestamp_str} (Unix: {timestamp_unix})")
    print(f"  Sensor data table: medusa-sensor-data")
    print(f"  Analysis data table: medusa-tremor-analysis")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Generate test tremor data for a specific user',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Generate 24 hours of data for user by email:
    python generate_user_test_data.py kdu9@jh.edu

  Generate 48 hours of data for user by ID:
    python generate_user_test_data.py 550e8400-e29b-41d4-a716-446655440000 --hours 48

  Generate 7 days of data at 6 points/hour:
    python generate_user_test_data.py kdu9@jh.edu --hours 168 --rate 6
        """
    )
    
    parser.add_argument('user', help='User ID or email address')
    parser.add_argument('--hours', type=int, default=24, help='Hours of data to generate (default: 24)')
    parser.add_argument('--rate', type=int, default=12, help='Points per hour (default: 12)')
    parser.add_argument('--device', default='DEV-TEST-001', help='Device ID (default: DEV-TEST-001)')
    
    args = parser.parse_args()
    
    print("MeDUSA Test Data Generator - User-Specific")
    print("=" * 60)
    
    # Get user_id
    user_id = get_user_id(args.user)
    if not user_id:
        sys.exit(1)
    
    # Confirm before generating
    print(f"\nAbout to generate:")
    print(f"  {args.hours} hours × {args.rate} points/hour = {args.hours * args.rate} data points")
    print(f"  This will write {args.hours * args.rate * 2} records to DynamoDB")
    
    response = input("\nContinue? (y/N): ")
    if response.lower() != 'y':
        print("Cancelled.")
        sys.exit(0)
    
    start_time = time.time()
    generate_user_data(user_id, args.device, args.hours, args.rate)
    elapsed = time.time() - start_time
    
    print("\n" + "=" * 60)
    print("Data Generation Complete!")
    print("=" * 60)
    print(f"Time elapsed: {elapsed:.1f} seconds")
    print(f"Total records: {args.hours * args.rate * 2}")
    print(f"\nTest the API:")
    print(f"  curl 'https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod/api/v1/tremor/analysis?patient_id={user_id}&limit=10'")
    print(f"\nNow login to the Flutter app with this account to see the data!")
