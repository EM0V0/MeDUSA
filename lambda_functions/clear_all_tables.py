import boto3
import time

def clear_tables():
    dynamodb = boto3.resource('dynamodb')
    sensor_table = dynamodb.Table('medusa-sensor-data')
    analysis_table = dynamodb.Table('medusa-tremor-analysis')
    
    print("Clearing medusa-sensor-data...")
    clear_table(sensor_table)
    
    print("\nClearing medusa-tremor-analysis...")
    clear_table(analysis_table)

def clear_table(table):
    try:
        # Scan to get keys
        # Note: For large tables, this is inefficient, but for dev/test it's fine.
        # For production, it's better to delete and recreate the table.
        response = table.scan(
            ProjectionExpression='#k1, #k2',
            ExpressionAttributeNames={'#k1': table.key_schema[0]['AttributeName'], '#k2': table.key_schema[1]['AttributeName']}
        )
        items = response['Items']
        
        while 'LastEvaluatedKey' in response:
            response = table.scan(
                ProjectionExpression='#k1, #k2',
                ExpressionAttributeNames={'#k1': table.key_schema[0]['AttributeName'], '#k2': table.key_schema[1]['AttributeName']},
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response['Items'])
            
        print(f"Found {len(items)} items to delete.")
        
        if not items:
            return

        with table.batch_writer() as batch:
            count = 0
            for item in items:
                batch.delete_item(Key=item)
                count += 1
                if count % 100 == 0:
                    print(f"Deleted {count} items...", end='\r')
        
        print(f"\nSuccessfully deleted {count} items.")
        
    except Exception as e:
        print(f"Error clearing table: {e}")

if __name__ == "__main__":
    clear_tables()
