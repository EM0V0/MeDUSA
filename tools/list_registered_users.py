import boto3
import os

def list_users():
    print("Scanning medusa-users-prod table...")
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('medusa-users-prod')

    try:
        response = table.scan()
        items = response.get('Items', [])
        
        print(f"\nFound {len(items)} registered users:")
        print("-" * 80)
        print(f"{'Email':<40} | {'ID':<20} | {'Role':<10}")
        print("-" * 80)
        
        for item in items:
            email = item.get('email', 'N/A')
            user_id = item.get('id', 'N/A')
            role = item.get('role', 'N/A')
            print(f"{email:<40} | {user_id:<20} | {role:<10}")
        print("-" * 80)
            
    except Exception as e:
        print(f"Error scanning table: {e}")

if __name__ == "__main__":
    list_users()
