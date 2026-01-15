import boto3
from datetime import datetime, timedelta
import time

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

def check_recent_sensor_data():
    print("Checking for recent sensor data (last 1 hour)...")
    
    # We can't easily query by timestamp without a device_id if we don't know it.
    # But we can scan the last few items or query known device IDs.
    
    known_devices = ['medusa-pi-01', 'DEV-002', 'raspberry-pi-01']
    
    found_data = False
    
    for device_id in known_devices:
        print(f"Checking device: {device_id}")
        
        now = datetime.utcnow()
        one_hour_ago = now - timedelta(hours=1)
        start_ts = int(one_hour_ago.timestamp() * 1000)
        end_ts = int(now.timestamp() * 1000)
        
        try:
            response = sensor_table.query(
                KeyConditionExpression='device_id = :did AND #ts BETWEEN :start AND :end',
                ExpressionAttributeNames={'#ts': 'timestamp'},
                ExpressionAttributeValues={
                    ':did': device_id,
                    ':start': start_ts,
                    ':end': end_ts
                },
                ScanIndexForward=False, # Newest first
                Limit=5
            )
            
            items = response.get('Items', [])
            if items:
                found_data = True
                print(f"  Found {len(items)} records for {device_id}.")
                print(f"  Latest record timestamp: {items[0]['timestamp']}")
                print(f"  Sample data: {items[0]}")
            else:
                print(f"  No data found in the last hour.")
                
        except Exception as e:
            print(f"  Error querying {device_id}: {e}")

    if not found_data:
        print("\nNo recent data found for known devices.")
        print("This suggests the Pi is not successfully sending data to DynamoDB 'medusa-sensor-data'.")

if __name__ == '__main__':
    check_recent_sensor_data()
