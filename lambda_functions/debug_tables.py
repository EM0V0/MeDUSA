import boto3
import json
from boto3.dynamodb.conditions import Key
from decimal import Decimal

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

dynamodb = boto3.resource('dynamodb')
analysis_table = dynamodb.Table('medusa-tremor-analysis')

def debug_tables():
    print("Debugging DynamoDB Tables...")
    
    # 1. Scan Tremor Analysis Table to find all unique patient IDs
    print("\nScanning Tremor Analysis Table for unique Patient IDs...")
    try:
        response = analysis_table.scan(
            ProjectionExpression='patient_id',
            Limit=1000
        )
        items = response['Items']
        patient_ids = set()
        for item in items:
            if 'patient_id' in item:
                patient_ids.add(item['patient_id'])
        
        print(f"Found {len(patient_ids)} unique patients in analysis table:")
        for pid in patient_ids:
            print(f" - {pid}")
            
    except Exception as e:
        print(f"Error scanning analysis table: {e}")

    # 2. Check specific patient data
    target_patient = "usr_694c4028"
    print(f"\nChecking data for {target_patient}...")
    
    try:
        response = analysis_table.query(
            KeyConditionExpression=Key('patient_id').eq(target_patient),
            Limit=5,
            ScanIndexForward=False # Latest first
        )
        items = response['Items']
        print(f"Found {len(items)} recent records:")
        for item in items:
            idx = item.get('tremor_index', 'N/A')
            score = item.get('tremor_score', 'N/A')
            ts = item.get('timestamp', 'N/A')
            print(f" - Time: {ts}, Index: {idx}, Score: {score}")
            
    except Exception as e:
        print(f"Error querying patient: {e}")

# Example usage:
debug_tables()
