import boto3
import numpy as np
from datetime import datetime, timedelta
import time
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

DEVICE_ID = 'medusa-pi-01'

def generate_raw_data():
    print(f"Generating RAW sensor data for {DEVICE_ID}...")
    
    # Generate 10 seconds of data at 10Hz (100 points)
    # This mimics the Pi sending data
    
    start_time = datetime.utcnow()
    
    for i in range(100):
        # Timestamp in milliseconds
        ts = start_time + timedelta(milliseconds=i*100)
        ts_ms = int(ts.timestamp() * 1000)
        
        # Simulate tremor (sine wave)
        t = i * 0.1
        x = 0.5 * np.sin(2 * np.pi * 4 * t) # 4Hz tremor
        y = 0.5 * np.cos(2 * np.pi * 4 * t)
        z = 9.8 + 0.1 * np.random.randn() # Gravity + noise
        
        item = {
            'device_id': DEVICE_ID,
            'timestamp': ts_ms,
            'accel_x': Decimal(str(round(x, 4))),
            'accel_y': Decimal(str(round(y, 4))),
            'accel_z': Decimal(str(round(z, 4))),
            'ttl': int(ts.timestamp()) + (7 * 24 * 60 * 60)
        }
        
        sensor_table.put_item(Item=item)
        if i % 10 == 0:
            print(f"Sent point {i}/100", end='\r')
            
    print("\nDone generating raw data.")

if __name__ == '__main__':
    generate_raw_data()
