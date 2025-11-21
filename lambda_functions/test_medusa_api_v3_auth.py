import boto3
import json
import jwt
import time
from datetime import datetime, timedelta

# Secret from Lambda environment variables
JWT_SECRET = "your-super-secret-jwt-key-minimum-32-characters-long-for-HS256"

def generate_token(user_id, email, role):
    payload = {
        "sub": user_id,
        "email": email,
        "role": role,
        "exp": int(time.time()) + 3600,
        "iat": int(time.time())
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def invoke_medusa_api():
    client = boto3.client('lambda')
    
    token = generate_token("usr_694c4028", "test@example.com", "patient")
    print(f"Generated Token: {token}")
    
    # Simulate API Gateway event
    event = {
        "resource": "/{proxy+}",
        "path": "/api/v1/tremor/analysis",
        "httpMethod": "GET",
        "headers": {
            "Accept": "*/*",
            "Authorization": f"Bearer {token}"
        },
        "queryStringParameters": {
            "patient_id": "usr_694c4028",
            "limit": "5"
        },
        "pathParameters": {
            "proxy": "api/v1/tremor/analysis"
        },
        "requestContext": {
            "authorizer": {
                "claims": {
                    "sub": "usr_694c4028",
                    "email": "test@example.com",
                    "custom:role": "patient"
                }
            },
            "identity": {
                "sourceIp": "127.0.0.1"
            }
        }
    }
    
    print("Invoking medusa-api-v3...")
    response = client.invoke(
        FunctionName='medusa-api-v3',
        InvocationType='RequestResponse',
        Payload=json.dumps(event)
    )
    
    payload = response['Payload'].read().decode('utf-8')
    result = json.loads(payload)
    
    print(f"Status Code: {result.get('statusCode')}")
    print("Body:")
    
    try:
        body = json.loads(result.get('body', '{}'))
        print(json.dumps(body, indent=2))
    except:
        print(result.get('body'))

if __name__ == "__main__":
    invoke_medusa_api()
