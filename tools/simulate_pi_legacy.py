import boto3
import numpy as np
from datetime import datetime, timedelta
import time
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

DEVICE_ID = 'medusa-pi-01'

def generate_legacy_data():
    print(f"Generating LEGACY sensor data for {DEVICE_ID}...")
    
    start_time = datetime.utcnow()
    
    for i in range(20): # Generate 20 points
        ts = start_time + timedelta(milliseconds=i*100)
        ts_ms = int(ts.timestamp() * 1000)
        
        t = i * 0.1
        x = 0.5 * np.sin(2 * np.pi * 4 * t)
        y = 0.5 * np.cos(2 * np.pi * 4 * t)
        z = 9.8
        
        item = {
            'device_id': DEVICE_ID,
            'timestamp': ts_ms,
            'accelerometer_x': [Decimal(str(round(x, 4)))],
            'accelerometer_y': [Decimal(str(round(y, 4)))],
            'accelerometer_z': [Decimal(str(round(z, 4)))],
            'ttl': int(ts.timestamp()) + (7 * 24 * 60 * 60)
        }
        
        sensor_table.put_item(Item=item)
        print(f"Sent legacy point {i+1}/20", end='\r')
            
    print("\nDone generating legacy data.")

if __name__ == '__main__':
    generate_legacy_data()
