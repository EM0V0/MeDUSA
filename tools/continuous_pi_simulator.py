#!/usr/bin/env python3
"""
MeDUSA Pi Data Simulator - Continuous Mode
Simulates realistic Parkinson's tremor sensor data from a Raspberry Pi device.

Usage:
    python continuous_pi_simulator.py --patient-id <patient_id> --duration 3600
    python continuous_pi_simulator.py --generate-historical --days 7
    
Author: Zhicheng Sun
"""

import boto3
import numpy as np
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import time
import argparse
import signal
import sys

# AWS Configuration
AWS_REGION = 'us-east-1'
SENSOR_TABLE = 'medusa-sensor-data'
ANALYSIS_TABLE = 'medusa-tremor-analysis'
DEFAULT_DEVICE_ID = 'medusa-pi-01'

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
sensor_table = dynamodb.Table(SENSOR_TABLE)
analysis_table = dynamodb.Table(ANALYSIS_TABLE)

# Global flag for graceful shutdown
running = True

def signal_handler(sig, frame):
    global running
    print("\n[INFO] Shutting down gracefully...")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


class TremorSimulator:
    """
    Simulates realistic Parkinson's tremor patterns.
    
    Parkinson's tremor characteristics:
    - Frequency: 3-6 Hz (typical rest tremor)
    - Amplitude: Variable, increases with fatigue
    - Pattern: Often asymmetric, pill-rolling motion
    """
    
    def __init__(self, patient_id: str, device_id: str = DEFAULT_DEVICE_ID):
        self.patient_id = patient_id
        self.device_id = device_id
        self.base_frequency = np.random.uniform(4.0, 5.5)  # Patient's characteristic frequency
        self.severity_level = np.random.choice(['mild', 'moderate', 'severe'], p=[0.4, 0.4, 0.2])
        
    def generate_raw_accelerometer(self, timestamp: datetime) -> dict:
        """Generate raw accelerometer data (X, Y, Z axes)"""
        t = timestamp.timestamp()
        
        # Base tremor signal (sinusoidal with patient-specific frequency)
        freq_variation = np.random.normal(0, 0.3)
        current_freq = self.base_frequency + freq_variation
        
        # Amplitude varies based on severity
        if self.severity_level == 'mild':
            base_amplitude = np.random.uniform(0.15, 0.30)
        elif self.severity_level == 'moderate':
            base_amplitude = np.random.uniform(0.30, 0.55)
        else:
            base_amplitude = np.random.uniform(0.55, 0.85)
        
        # Add natural variation
        amplitude = base_amplitude * (1 + 0.2 * np.sin(2 * np.pi * 0.1 * t))
        
        # Generate tremor components
        tremor_x = amplitude * np.sin(2 * np.pi * current_freq * t)
        tremor_y = amplitude * np.cos(2 * np.pi * current_freq * t + np.pi/4)  # Phase shifted
        tremor_z = amplitude * 0.3 * np.sin(2 * np.pi * current_freq * t + np.pi/2)  # Smaller Z component
        
        # Add sensor noise
        noise_x = np.random.normal(0, 0.02)
        noise_y = np.random.normal(0, 0.02)
        noise_z = np.random.normal(0, 0.02)
        
        # Gravity component (Z axis primarily)
        gravity = 9.81
        
        return {
            'device_id': self.device_id,
            'timestamp': int(timestamp.timestamp() * 1000),
            'accel_x': Decimal(str(round(tremor_x + noise_x, 4))),
            'accel_y': Decimal(str(round(tremor_y + noise_y, 4))),
            'accel_z': Decimal(str(round(gravity + tremor_z + noise_z, 4))),
            'magnitude': Decimal(str(round(np.sqrt(tremor_x**2 + tremor_y**2 + (gravity + tremor_z)**2), 4))),
            'sequence': int(t * 1000) % 1000000,
            'ttl': int(timestamp.timestamp()) + (7 * 24 * 60 * 60)  # 7 days TTL
        }
    
    def generate_analysis_data(self, timestamp: datetime) -> dict:
        """Generate processed tremor analysis data"""
        # Simulate analysis results based on severity
        if self.severity_level == 'mild':
            tremor_score = np.random.uniform(15, 40)
            is_parkinsonian = np.random.random() < 0.3
        elif self.severity_level == 'moderate':
            tremor_score = np.random.uniform(40, 70)
            is_parkinsonian = np.random.random() < 0.6
        else:
            tremor_score = np.random.uniform(70, 95)
            is_parkinsonian = np.random.random() < 0.85
        
        freq_variation = np.random.normal(0, 0.2)
        frequency = self.base_frequency + freq_variation
        
        amplitude = tremor_score / 100.0 * np.random.uniform(0.6, 0.9)
        rms = tremor_score / 100.0 * np.random.uniform(0.3, 0.6)
        tremor_index = tremor_score / 100.0
        
        return {
            'patient_id': self.patient_id,
            'timestamp': timestamp.strftime('%Y-%m-%dT%H:%M:%S.') + f"{timestamp.microsecond // 1000:03d}Z",
            'device_id': self.device_id,
            'tremor_score': Decimal(str(round(tremor_score, 1))),
            'tremor_index': Decimal(str(round(tremor_index, 4))),
            'tremor_frequency': Decimal(str(round(frequency, 2))),
            'tremor_amplitude': Decimal(str(round(amplitude, 3))),
            'dominant_freq': Decimal(str(round(frequency, 2))),
            'rms': Decimal(str(round(rms, 3))),
            'is_parkinsonian': is_parkinsonian,
            'severity': self.severity_level,
            'ttl': int(timestamp.timestamp()) + (90 * 24 * 60 * 60)  # 90 days TTL
        }


def run_continuous_simulation(patient_id: str, device_id: str, interval: float = 1.0):
    """Run continuous real-time simulation"""
    simulator = TremorSimulator(patient_id, device_id)
    
    print(f"[INFO] Starting continuous simulation for patient: {patient_id}")
    print(f"[INFO] Device: {device_id}, Severity: {simulator.severity_level}")
    print(f"[INFO] Data interval: {interval}s. Press Ctrl+C to stop.\n")
    
    count = 0
    while running:
        try:
            now = datetime.now(timezone.utc)
            
            # Generate and store raw sensor data (10 Hz burst)
            for i in range(10):
                raw_data = simulator.generate_raw_accelerometer(now + timedelta(milliseconds=i*100))
                sensor_table.put_item(Item=raw_data)
            
            # Generate and store analysis data (1 Hz)
            analysis_data = simulator.generate_analysis_data(now)
            analysis_table.put_item(Item=analysis_data)
            
            count += 1
            score = float(analysis_data['tremor_score'])
            status = "PARKINSONIAN" if analysis_data['is_parkinsonian'] else "NORMAL"
            print(f"[{now.strftime('%H:%M:%S')}] Point #{count:5d} | Score: {score:5.1f} | {status:12s}", end='\r')
            
            time.sleep(interval)
            
        except Exception as e:
            print(f"\n[ERROR] {e}")
            time.sleep(1)
    
    print(f"\n[INFO] Simulation stopped. Total points: {count}")


def generate_historical_data(patient_id: str, device_id: str, days: int = 7, points_per_hour: int = 60):
    """Generate historical data for testing"""
    simulator = TremorSimulator(patient_id, device_id)
    
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(days=days)
    
    total_points = days * 24 * points_per_hour
    print(f"[INFO] Generating {total_points} historical data points over {days} days...")
    print(f"[INFO] Patient: {patient_id}, Severity: {simulator.severity_level}")
    
    current_time = start_time
    count = 0
    
    while current_time < end_time:
        analysis_data = simulator.generate_analysis_data(current_time)
        analysis_table.put_item(Item=analysis_data)
        
        count += 1
        if count % 100 == 0:
            progress = (count / total_points) * 100
            print(f"[PROGRESS] {progress:.1f}% ({count}/{total_points})", end='\r')
        
        current_time += timedelta(seconds=3600 / points_per_hour)
    
    print(f"\n[DONE] Generated {count} historical data points.")


def create_test_patient(email: str, role: str = "patient") -> str:
    """Create a test patient in the users table and return the user ID"""
    import hashlib
    import uuid
    
    users_table = dynamodb.Table('medusa-users-prod')
    
    # Check if user exists
    try:
        response = users_table.query(
            IndexName='email-index',
            KeyConditionExpression='email = :email',
            ExpressionAttributeValues={':email': email}
        )
        if response.get('Items'):
            user = response['Items'][0]
            print(f"[INFO] User already exists: {user['id']}")
            return user['id']
    except Exception as e:
        print(f"[WARN] Could not check existing user: {e}")
    
    # Create new user
    user_id = f"usr_{uuid.uuid4().hex[:8]}"
    
    # Use argon2id via the backend's hash function (simplified here)
    # In production, use the actual hash_pw function from auth.py
    password_hash = "$argon2id$v=19$m=65536,t=3,p=4$test_hash"  # Placeholder
    
    user = {
        'id': user_id,
        'email': email,
        'role': role,
        'name': email.split('@')[0],
        'password': password_hash,
        'createdAt': datetime.now(timezone.utc).isoformat()
    }
    
    users_table.put_item(Item=user)
    print(f"[INFO] Created test user: {user_id} ({email})")
    
    return user_id


def main():
    parser = argparse.ArgumentParser(description='MeDUSA Pi Data Simulator')
    parser.add_argument('--patient-id', type=str, help='Patient ID (user ID from medusa-users-prod)')
    parser.add_argument('--device-id', type=str, default=DEFAULT_DEVICE_ID, help='Device ID')
    parser.add_argument('--interval', type=float, default=1.0, help='Data generation interval in seconds')
    parser.add_argument('--generate-historical', action='store_true', help='Generate historical data instead of realtime')
    parser.add_argument('--days', type=int, default=7, help='Days of historical data to generate')
    parser.add_argument('--create-test-user', type=str, help='Create a test user with this email')
    
    args = parser.parse_args()
    
    # Create test user if requested
    if args.create_test_user:
        patient_id = create_test_patient(args.create_test_user)
        print(f"[INFO] Use this patient ID: {patient_id}")
        if not args.patient_id:
            args.patient_id = patient_id
    
    if not args.patient_id:
        print("[ERROR] --patient-id is required. Use --create-test-user to create one first.")
        sys.exit(1)
    
    if args.generate_historical:
        generate_historical_data(args.patient_id, args.device_id, args.days)
    else:
        run_continuous_simulation(args.patient_id, args.device_id, args.interval)


if __name__ == '__main__':
    main()
