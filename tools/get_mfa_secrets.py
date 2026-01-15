import boto3
from boto3.dynamodb.conditions import Key
import sys

try:
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('medusa-users-prod')
    
    emails = ["zsun54@jh.edu", "andysun12@outlook.com"]
    
    print("Retrieving MFA secrets...")
    print("-" * 50)
    
    for email in emails:
        try:
            resp = table.query(
                IndexName='email-index',
                KeyConditionExpression=Key('email').eq(email)
            )
            
            if resp['Items']:
                u = resp['Items'][0]
                secret = u.get('mfa_secret', 'NOT_SET')
                enabled = u.get('mfa_enabled', False)
                print(f"User:   {email}")
                print(f"Secret: {secret}")
                print(f"Status: {'Active' if enabled else 'Disabled'}")
                print("-" * 50)
            else:
                print(f"User:   {email}")
                print("Status: Not Found")
                print("-" * 50)
                
        except Exception as e:
            print(f"Error checking {email}: {e}")

except Exception as e:
    print(f"Global Error: {e}")
