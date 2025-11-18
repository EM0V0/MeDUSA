"""
Generate recent tremor data (last 1 hour) for existing patient.
This ensures data shows up in the 1h time range.
"""

import boto3
import numpy as np
from datetime import datetime, timedelta
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
analysis_table = dynamodb.Table('medusa-tremor-analysis')

PATIENT_ID = 'usr_8537f43b'  # kdu9@jh.edu

def generate_tremor_features(is_parkinsonian=False):
    """Generate realistic tremor analysis features."""
    if is_parkinsonian:
        # Parkinsonian tremor: 3-6 Hz, higher amplitude
        frequency = np.random.uniform(3.5, 5.5)
        amplitude = np.random.uniform(0.4, 0.8)
        rms = np.random.uniform(0.3, 0.6)
        tremor_score = np.random.uniform(60, 95)
    else:
        # Normal movement: lower frequency, lower amplitude
        frequency = np.random.uniform(1.0, 3.0)
        amplitude = np.random.uniform(0.1, 0.3)
        rms = np.random.uniform(0.05, 0.15)
        tremor_score = np.random.uniform(5, 40)
    
    return {
        'tremor_frequency': Decimal(str(round(frequency, 2))),
        'tremor_amplitude': Decimal(str(round(amplitude, 3))),
        'rms': Decimal(str(round(rms, 3))),
        'tremor_score': Decimal(str(round(tremor_score, 1))),
        'is_parkinsonian': is_parkinsonian
    }

def generate_recent_hour_data():
    """Generate data for the last hour with 5-minute intervals."""
    now = datetime.utcnow()
    print(f"Current UTC time: {now.isoformat()}")
    
    # Generate 12 data points (every 5 minutes for 1 hour)
    num_points = 12
    interval_minutes = 5
    
    print(f"\nGenerating {num_points} data points for patient {PATIENT_ID}")
    print(f"Time range: {(now - timedelta(hours=1)).isoformat()} to {now.isoformat()}")
    
    items_written = 0
    
    for i in range(num_points):
        # Calculate timestamp (going backwards from now)
        minutes_ago = (num_points - 1 - i) * interval_minutes
        timestamp = now - timedelta(minutes=minutes_ago)
        
        # 20% chance of Parkinsonian episode
        is_parkinsonian = np.random.random() < 0.2
        
        features = generate_tremor_features(is_parkinsonian)
        
        item = {
            'patient_id': PATIENT_ID,
            'timestamp': timestamp.isoformat() + 'Z',  # Primary sort key
            'tremor_score': features['tremor_score'],
            'tremor_frequency': features['tremor_frequency'],
            'tremor_amplitude': features['tremor_amplitude'],
            'is_parkinsonian': features['is_parkinsonian'],
            'features': {
                'rms': features['rms'],
                'frequency': features['tremor_frequency'],
                'amplitude': features['tremor_amplitude']
            }
        }
        
        # Write to DynamoDB
        analysis_table.put_item(Item=item)
        items_written += 1
        
        status = "⚠️ Parkinsonian" if is_parkinsonian else "✓ Normal"
        print(f"  [{i+1:2d}] {timestamp.strftime('%H:%M:%S')} - Score: {float(features['tremor_score']):5.1f} - {status}")
    
    print(f"\n✅ Successfully wrote {items_written} records to medusa-tremor-analysis")
    print(f"\nTo verify, run:")
    print(f"  flutter run -d windows")
    print(f"  Login as: kdu9@jh.edu")
    print(f"  Select: 1H time range")

if __name__ == '__main__':
    generate_recent_hour_data()
