"""
Generate tremor analysis test data for a specific user.
This script creates realistic tremor data directly in the medusa-tremor-analysis table.
"""

import boto3
from decimal import Decimal
from datetime import datetime, timedelta
import random

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('medusa-tremor-analysis')

def generate_tremor_data(patient_id, device_id='DEV-002', num_records=50):
    """
    Generate tremor analysis records for a patient.
    
    Args:
        patient_id: Patient ID (e.g., 'usr_694c4028')
        device_id: Device ID
        num_records: Number of records to generate
    """
    
    print(f"Generating {num_records} tremor analysis records for {patient_id}...")
    
    # Start from 1 hour ago and create records every 2 minutes
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)
    time_delta = timedelta(minutes=2)
    
    records_created = 0
    
    for i in range(num_records):
        # Calculate timestamp
        timestamp = start_time + (time_delta * i)
        timestamp_iso = timestamp.isoformat() + 'Z'
        timestamp_unix = int(timestamp.timestamp())
        
        # Generate realistic tremor metrics
        # Simulate varying tremor severity
        base_tremor = 0.3 + (0.4 * random.random())  # 0.3 to 0.7
        tremor_index = Decimal(str(round(base_tremor, 4)))
        tremor_score = Decimal(str(round(base_tremor * 100, 2)))
        
        # Dominant frequency (3-6 Hz is Parkinsonian range)
        is_parkinsonian = random.random() > 0.6  # 40% Parkinsonian episodes
        if is_parkinsonian:
            dominant_freq = Decimal(str(round(3.5 + random.random() * 2.5, 2)))  # 3.5-6 Hz
        else:
            dominant_freq = Decimal(str(round(1.0 + random.random() * 8.0, 2)))  # 1-9 Hz
        
        # RMS value
        rms_value = Decimal(str(round(0.2 + random.random() * 0.5, 4)))
        
        # Tremor and total power
        tremor_power = Decimal(str(round(1000 + random.random() * 5000, 2)))
        total_power = Decimal(str(round(float(tremor_power) / float(tremor_index) if tremor_index > 0 else 10000, 2)))
        
        # Signal quality
        signal_quality = Decimal(str(round(0.85 + random.random() * 0.14, 2)))  # 0.85-0.99
        
        # Create record
        item = {
            'patient_id': patient_id,
            'timestamp': timestamp_iso,
            'device_id': device_id,
            'tremor_index': tremor_index,
            'tremor_score': tremor_score,
            'dominant_frequency': dominant_freq,
            'is_parkinsonian': is_parkinsonian,
            'rms_value': rms_value,
            'tremor_power': tremor_power,
            'total_power': total_power,
            'signal_quality': signal_quality,
            'ttl': timestamp_unix + (90 * 24 * 60 * 60)  # 90 days retention
        }
        
        try:
            table.put_item(Item=item)
            records_created += 1
            if (i + 1) % 10 == 0:
                print(f"  Created {i + 1} records...")
        except Exception as e:
            print(f"Error creating record {i}: {e}")
    
    print(f"✅ Successfully created {records_created} tremor analysis records")
    print(f"   Patient ID: {patient_id}")
    print(f"   Device ID: {device_id}")
    print(f"   Time range: {start_time.isoformat()} to {end_time.isoformat()}")
    
    return records_created


if __name__ == '__main__':
    # Generate data for the user from the logs
    patient_id = 'usr_694c4028'
    device_id = 'DEV-002'
    
    count = generate_tremor_data(
        patient_id=patient_id,
        device_id=device_id,
        num_records=50  # Last hour with 2-minute intervals
    )
    
    print(f"\n🎉 Done! Created {count} records.")
    print(f"\nYou can now query the data:")
    print(f"aws dynamodb query --table-name medusa-tremor-analysis \\")
    print(f"  --key-condition-expression \"patient_id = :pid\" \\")
    print(f"  --expression-attribute-values '{{\":pid\": {{\"S\": \"{patient_id}\"}}}}' \\")
    print(f"  --limit 5")
