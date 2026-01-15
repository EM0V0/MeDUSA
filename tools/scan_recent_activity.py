import boto3
from datetime import datetime, timedelta

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')

def scan_latest_activity():
    print("Scanning for ANY recent sensor data (last 24 hours)...")
    
    # Since we don't know the PK (device_id), we have to Scan.
    # To be efficient, we'll just scan a segment or limit the results, 
    # but since we want *recent* data and Scan doesn't order by time, 
    # we might have to scan a bit and filter.
    # Ideally, we'd use a GSI on timestamp, but I don't know if one exists.
    
    # Let's try to check the table description first to see if there's a GSI.
    try:
        print("Table GSIs:", sensor_table.global_secondary_indexes)
    except:
        pass

    # Fallback: Scan with a limit and look for recent timestamps.
    # This is inefficient but necessary if we don't know the device_id.
    
    try:
        # Scan the first 1000 items (arbitrary limit to avoid full table scan if huge)
        response = sensor_table.scan(Limit=1000)
        items = response.get('Items', [])
        
        print(f"Scanned {len(items)} items.")
        
        # Sort by timestamp descending
        # Timestamps are usually numbers (milliseconds)
        items.sort(key=lambda x: float(x.get('timestamp', 0)), reverse=True)
        
        if not items:
            print("No items found in table.")
            return

        print("\nTop 10 most recent records found:")
        for i, item in enumerate(items[:10]):
            ts = float(item.get('timestamp', 0))
            dt = datetime.fromtimestamp(ts / 1000.0)
            print(f"{i+1}. Device: {item.get('device_id')} | Time: {dt} | TS: {ts}")
            
    except Exception as e:
        print(f"Error scanning table: {e}")

if __name__ == '__main__':
    scan_latest_activity()
