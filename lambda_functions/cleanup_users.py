import boto3
import json

dynamodb = boto3.resource('dynamodb')

def clear_table(table_name, key_name='id'):
    print(f"Clearing table {table_name}...")
    table = dynamodb.Table(table_name)
    
    # Scan and delete
    response = table.scan()
    items = response.get('Items', [])
    
    while items:
        with table.batch_writer() as batch:
            for item in items:
                key_value = item[key_name]
                print(f"Deleting {key_value} from {table_name}")
                batch.delete_item(Key={key_name: key_value})
        
        # Check for more items (pagination)
        if 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items = response.get('Items', [])
        else:
            items = []
            
    print(f"Table {table_name} cleared.")

# Clear Users
clear_table('medusa-users-prod', 'id')

# Clear Patient Profiles
clear_table('medusa-patient-profiles-prod', 'userId')

# Clear Refresh Tokens
clear_table('medusa-refresh-tokens-prod', 'token')

print("All user data cleared successfully.")
