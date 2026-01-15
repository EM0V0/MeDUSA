import boto3
import numpy as np
from datetime import datetime, timedelta
from decimal import Decimal
import time

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
analysis_table = dynamodb.Table('medusa-tremor-analysis')

PATIENT_ID = 'usr_694c4028'

def generate_tremor_features(is_parkinsonian=False):
    if is_parkinsonian:
        frequency = np.random.uniform(3.5, 5.5)
        amplitude = np.random.uniform(0.4, 0.8)
        rms = np.random.uniform(0.3, 0.6)
        tremor_score = np.random.uniform(60, 95)
    else:
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

def generate_realtime_data():
    now = datetime.utcnow()
    print(f"Generating realtime data for patient {PATIENT_ID} starting from {now.isoformat()}")
    
    # Generate data for the last 2 minutes, every 1 second
    for i in range(120):
        seconds_ago = 120 - i
        timestamp = now - timedelta(seconds=seconds_ago)
        
        is_parkinsonian = np.random.random() < 0.2
        features = generate_tremor_features(is_parkinsonian)
        tremor_index = float(features['tremor_score']) / 100.0
        
        item = {
            'patient_id': PATIENT_ID,
            'timestamp': timestamp.isoformat() + 'Z',
            'device_id': 'medusa-pi-01',
            'tremor_score': features['tremor_score'],
            'tremor_index': Decimal(str(round(tremor_index, 4))),
            'tremor_frequency': features['tremor_frequency'],
            'tremor_amplitude': features['tremor_amplitude'],
            'is_parkinsonian': features['is_parkinsonian'],
            'rms': features['rms'],
            'ttl': int(timestamp.timestamp()) + (90 * 24 * 60 * 60)
        }
        
        analysis_table.put_item(Item=item)
        print(f"Generated point at {timestamp.strftime('%H:%M:%S')} - Score: {features['tremor_score']}", end='\r')
    
    print("\nDone generating data.")

if __name__ == '__main__':
    generate_realtime_data()
