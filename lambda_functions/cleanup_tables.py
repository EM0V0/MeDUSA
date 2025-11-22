import boto3
import sys

def cleanup_tables():
    dynamodb = boto3.resource('dynamodb')
    tables = ['medusa-sensor-data', 'medusa-tremor-analysis']
    
    for table_name in tables:
        print(f"Cleaning up table: {table_name}")
        table = dynamodb.Table(table_name)
        
        # Scan and delete
        try:
            scan = table.scan()
            with table.batch_writer() as batch:
                for each in scan['Items']:
                    # Determine key based on table schema
                    # medusa-sensor-data: device_id (PK), timestamp (SK)
                    # medusa-tremor-analysis: patient_id (PK), timestamp (SK)
                    
                    key = {}
                    if table_name == 'medusa-sensor-data':
                        key['device_id'] = each['device_id']
                        key['timestamp'] = each['timestamp']
                    elif table_name == 'medusa-tremor-analysis':
                        key['patient_id'] = each['patient_id']
                        key['timestamp'] = each['timestamp']
                    
                    batch.delete_item(Key=key)
            
            print(f"Successfully cleaned up {table_name}")
            
        except Exception as e:
            print(f"Error cleaning up {table_name}: {e}")

if __name__ == "__main__":
    cleanup_tables()
