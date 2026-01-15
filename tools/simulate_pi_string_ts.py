import boto3
import numpy as np
from datetime import datetime, timedelta
import time
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

DEVICE_ID = 'medusa-pi-01'

def generate_string_ts_data():
    print(f"Generating String Timestamp sensor data for {DEVICE_ID}...")
    
    start_time = datetime.utcnow()
    
    for i in range(20):
        ts = start_time + timedelta(milliseconds=i*100)
        ts_ms = int(ts.timestamp() * 1000)
        
        t = i * 0.1
        x = 0.5 * np.sin(2 * np.pi * 4 * t)
        y = 0.5 * np.cos(2 * np.pi * 4 * t)
        z = 9.8
        
        item = {
            'device_id': DEVICE_ID,
            'timestamp': ts_ms, # Keep as Number for DB, but maybe Lambda expects it to be castable?
            # Wait, if I write it as int, Boto3 writes as Number.
            # If I write as str, Boto3 writes as String.
            # The Lambda query uses :start (Number).
            # If DB has String, Query will FAIL to match range.
            # So it MUST be Number in DB.
            
            # So this hypothesis is invalid.
            # If Lambda query works (which it did manually), then DB has Number.
            # And Lambda code reads it.
            
            # So I won't bother with this script.
            'x': [Decimal(str(round(x, 4)))],
            'y': [Decimal(str(round(y, 4)))],
            'z': [Decimal(str(round(z, 4)))],
            'ttl': int(ts.timestamp()) + (7 * 24 * 60 * 60)
        }
        pass

if __name__ == '__main__':
    pass
