import boto3
from boto3.dynamodb.conditions import Key
import datetime
import json
from decimal import Decimal

# Helper to convert Decimal to float for JSON serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('medusa-tremor-analysis')

# We need a patient_id to query. From the logs: usr_694c4028
patient_id = 'usr_694c4028'

print(f"Querying latest tremor analysis for patient: {patient_id}")

try:
    response = table.query(
        KeyConditionExpression=Key('patient_id').eq(patient_id),
        ScanIndexForward=False, # Descending order (newest first)
        Limit=5
    )

    items = response.get('Items', [])
    if not items:
        print("No items found.")
    else:
        print(f"Found {len(items)} items.")
        for item in items:
            print(json.dumps(item, cls=DecimalEncoder, indent=2))
            
            # Check timestamp
            ts_str = item.get('timestamp')
            print(f"Timestamp: {ts_str}")
            
            # Compare with now
            try:
                ts = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                now = datetime.datetime.now(datetime.timezone.utc)
                diff = now - ts
                print(f"Age: {diff}")
            except Exception as e:
                print(f"Error parsing timestamp: {e}")
            print("-" * 20)

except Exception as e:
    print(f"Error querying table: {e}")
