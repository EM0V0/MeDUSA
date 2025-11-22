import boto3

def cleanup_analysis():
    dynamodb = boto3.resource('dynamodb')
    table_name = 'medusa-tremor-analysis'
    
    print(f"Cleaning up table: {table_name}")
    table = dynamodb.Table(table_name)
    
    # Scan and delete
    try:
        scan = table.scan()
        with table.batch_writer() as batch:
            for each in scan['Items']:
                batch.delete_item(
                    Key={
                        'patient_id': each['patient_id'],
                        'timestamp': each['timestamp']
                    }
                )
        print(f"Successfully cleaned up {table_name}")
    except Exception as e:
        print(f"Error cleaning up {table_name}: {e}")

if __name__ == "__main__":
    cleanup_analysis()
