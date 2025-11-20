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

def generate_recent_data():
    """Generate data for the last 24 hours."""
    now = datetime.utcnow()
    print(f"Current UTC time: {now.isoformat()}")
    
    items_written = 0
    
    # 1. Generate high density data for last 1 hour (every 2 minutes = 30 points)
    print(f"\nGenerating high density data for last 1 hour...")
    for i in range(30):
        minutes_ago = 60 - (i * 2)
        timestamp = now - timedelta(minutes=minutes_ago)
        _generate_and_write_point(timestamp)
        items_written += 1

    # 2. Generate lower density data for 1h-24h ago (every 15 minutes = ~92 points)
    print(f"\nGenerating standard data for last 24 hours...")
    for i in range(92):
        minutes_ago = 60 + (i * 15)
        timestamp = now - timedelta(minutes=minutes_ago)
        _generate_and_write_point(timestamp)
        items_written += 1
        
    print(f"\n✅ Successfully wrote {items_written} records to medusa-tremor-analysis")

def _generate_and_write_point(timestamp):
    # 20% chance of Parkinsonian episode
    is_parkinsonian = np.random.random() < 0.2
    features = generate_tremor_features(is_parkinsonian)
    
    # Calculate tremor_index (0-1) from score (0-100)
    tremor_index = float(features['tremor_score']) / 100.0
    
    item = {
        'patient_id': PATIENT_ID,
        'timestamp': timestamp.isoformat() + 'Z',
        'analysis_timestamp': int(timestamp.timestamp()), # Add Unix timestamp
        'tremor_score': features['tremor_score'],
        'tremor_index': Decimal(str(round(tremor_index, 4))), # Add legacy field
        'tremor_frequency': features['tremor_frequency'],
        'tremor_amplitude': features['tremor_amplitude'],
        'is_parkinsonian': features['is_parkinsonian'],
        'features': {
            'rms': features['rms'],
            'frequency': features['tremor_frequency'],
            'amplitude': features['tremor_amplitude']
        }
    }
    
    analysis_table.put_item(Item=item)
    
    status = "⚠️" if is_parkinsonian else "✓"
    print(f"  {timestamp.strftime('%H:%M')} - Score: {float(features['tremor_score']):4.1f} {status}", end='\r')

if __name__ == '__main__':
    generate_recent_data()
