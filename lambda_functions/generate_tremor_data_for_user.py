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

def generate_tremor_data(patient_id, device_id='DEV-002', days=7):
    """
    Generate tremor analysis records for a patient over a specified number of days.
    
    Args:
        patient_id: Patient ID
        device_id: Device ID
        days: Number of days of history to generate
    """
    
    print(f"Generating {days} days of tremor analysis records for {patient_id}...")
    
    # Generate data up to 10 minutes in the FUTURE to ensure it appears on the chart
    # even if there is slight clock skew or processing delay
    end_time = datetime.utcnow() + timedelta(minutes=10)
    start_time = datetime.utcnow() - timedelta(minutes=5) # Start 5 mins ago
    
    records_created = 0
    current_time = start_time
    
    # Generate HIGH FREQUENCY data for immediate visibility
    interval = timedelta(seconds=5) 
    
    while current_time <= end_time:
        # Calculate timestamp
        timestamp_iso = current_time.isoformat() + 'Z'
        timestamp_unix = int(current_time.timestamp())
        
        # FORCE HIGH TREMOR for visibility
        base_tremor = 0.8 + (0.15 * random.random())  # 0.8 to 0.95 (Very High)
            
        tremor_index = Decimal(str(round(base_tremor, 4)))
        tremor_score = Decimal(str(round(base_tremor * 100, 2)))
        
        # Dominant frequency (3-6 Hz is Parkinsonian range)
        is_parkinsonian = base_tremor > 0.5  # Correlate with tremor score
        
        if is_parkinsonian:
            dominant_freq = Decimal(str(round(3.5 + random.random() * 2.5, 2)))  # 3.5-6 Hz
        else:
            dominant_freq = Decimal(str(round(1.0 + random.random() * 8.0, 2)))  # 1-9 Hz
        
        # RMS value (correlated with tremor score)
        rms_value = Decimal(str(round(base_tremor * 0.8 + random.random() * 0.1, 4)))
        
        # Tremor power
        tremor_power = Decimal(str(round(base_tremor * 5000, 2)))
        
        # Create record
        item = {
            'patient_id': patient_id,
            'timestamp': timestamp_iso,
            'device_id': device_id,
            'tremor_index': tremor_index,
            # 'tremor_score': tremor_score, # Removed to reduce redundancy
            'dominant_frequency': dominant_freq,
            'is_parkinsonian': True, # Force True
            'rms': rms_value, # Use 'rms' to match processor
            'tremor_power': tremor_power,
            'ttl': timestamp_unix + (90 * 24 * 60 * 60)
        }
        
        try:
            table.put_item(Item=item)
            records_created += 1
            if records_created % 10 == 0: # Print more often
                print(f"  Created {records_created} records... (Current: {current_time})")
        except Exception as e:
            print(f"Error creating record: {e}")
            
        current_time += interval
    
    print(f"✅ Successfully created {records_created} tremor analysis records")
    print(f"   Patient ID: {patient_id}")
    print(f"   Device ID: {device_id}")
    
    return records_created


if __name__ == '__main__':
    # Generate data for the user from the logs
    patient_id = 'usr_694c4028'
    device_id = 'DEV-002'
    
    count = generate_tremor_data(
        patient_id=patient_id,
        device_id=device_id,
        days=7
    )
    
    print(f"\n🎉 Done! Created {count} records.")
    print(f"\nYou can now query the data:")
    print(f"aws dynamodb query --table-name medusa-tremor-analysis \\")
    print(f"  --key-condition-expression \"patient_id = :pid\" \\")
    print(f"  --expression-attribute-values '{{\":pid\": {{\"S\": \"{patient_id}\"}}}}' \\")
    print(f"  --limit 5")
