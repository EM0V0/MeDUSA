import boto3
import numpy as np
from datetime import datetime, timedelta
import time
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

DEVICE_ID = 'medusa-pi-01'

def generate_data():
    print(f"Generating sensor data for {DEVICE_ID}...")
    
    start_time = datetime.utcnow()
    
    # 1. Send single value data (simulating Pi with new fix)
    print("Sending single-value data (accel_x format)...")
    for i in range(10):
        ts = start_time + timedelta(milliseconds=i*100)
        ts_ms = int(ts.timestamp() * 1000)
        
        t = i * 0.1
        x = 0.5 * np.sin(2 * np.pi * 4 * t)
        
        item = {
            'device_id': DEVICE_ID,
            'timestamp': ts_ms,
            'accel_x': Decimal(str(round(x, 4))),
            'accel_y': Decimal('0.0'),
            'accel_z': Decimal('9.8'),
            'ttl': int(ts.timestamp()) + (7 * 24 * 60 * 60)
        }
        sensor_table.put_item(Item=item)
        
    # 2. Send array data (simulating other devices)
    print("Sending array data (accelerometer_x format)...")
    for i in range(10):
        ts = start_time + timedelta(seconds=2) + timedelta(milliseconds=i*100)
        ts_ms = int(ts.timestamp() * 1000)
        
        item = {
            'device_id': DEVICE_ID,
            'timestamp': ts_ms,
            'accelerometer_x': [Decimal('0.1'), Decimal('0.2')],
            'accelerometer_y': [Decimal('0.0'), Decimal('0.0')],
            'accelerometer_z': [Decimal('9.8'), Decimal('9.8')],
            'ttl': int(ts.timestamp()) + (7 * 24 * 60 * 60)
        }
        sensor_table.put_item(Item=item)

    print("\nDone generating data.")

if __name__ == '__main__':
    generate_data()
