import boto3
from datetime import datetime, timedelta
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

DEVICE_ID = 'medusa-pi-01'

def generate_mag_data():
    print(f"Generating Magnitude sensor data for {DEVICE_ID}...")
    
    start_time = datetime.utcnow()
    
    for i in range(20):
        ts = start_time + timedelta(milliseconds=i*100)
        ts_ms = int(ts.timestamp() * 1000)
        
        item = {
            'device_id': DEVICE_ID,
            'timestamp': ts_ms,
            'magnitude': Decimal('9.8'),
            'ttl': int(ts.timestamp()) + (7 * 24 * 60 * 60)
        }
        
        sensor_table.put_item(Item=item)
        print(f"Sent Mag point {i+1}/20", end='\r')
            
    print("\nDone generating Mag data.")

if __name__ == '__main__':
    generate_mag_data()
