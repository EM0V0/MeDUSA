import boto3

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
devices_table = dynamodb.Table('medusa-devices-prod')

def list_devices():
    print("Scanning medusa-devices-prod...")
    try:
        response = devices_table.scan()
        items = response.get('Items', [])
        
        print(f"Found {len(items)} devices:")
        for item in items:
            print(f"  ID: {item.get('id')} | Owner: {item.get('patientId')} | Name: {item.get('name')}")
            
    except Exception as e:
        print(f"Error scanning devices: {e}")

if __name__ == '__main__':
    list_devices()
