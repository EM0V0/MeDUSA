import boto3
from datetime import datetime
import sys

def check_device_data(device_id):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('medusa-sensor-data')
    
    print(f"Checking data for device: {device_id}")
    
    try:
        response = table.query(
            KeyConditionExpression='device_id = :did',
            ExpressionAttributeValues={
                ':did': device_id
            },
            ScanIndexForward=False,  # Newest first
            Limit=5
        )
        
        items = response.get('Items', [])
        
        if not items:
            print(f"❌ No data found for device {device_id}")
            return
            
        print(f"✅ Found {len(items)} recent records for {device_id}")
        for item in items:
            ts = int(item['timestamp'])
            dt = datetime.fromtimestamp(ts / 1000.0)
            print(f"  - Time: {dt} (Timestamp: {ts})")
            print(f"    Data keys: {list(item.keys())}")
            # Print a sample of data to verify it looks real
            if 'accelerometer_x' in item:
                print(f"    Accel X (sample): {item['accelerometer_x'][:3]}...")
            elif 'x' in item:
                print(f"    X (sample): {item['x'][:3]}...")
                
    except Exception as e:
        print(f"Error querying DynamoDB: {e}")

if __name__ == "__main__":
    device_id = 'medusa-pi-01'
    if len(sys.argv) > 1:
        device_id = sys.argv[1]
    check_device_data(device_id)
