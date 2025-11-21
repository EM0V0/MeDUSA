import boto3
import json

def invoke_medusa_api():
    client = boto3.client('lambda')
    
    # Simulate API Gateway event
    event = {
        "resource": "/{proxy+}",
        "path": "/api/v1/tremor/analysis",
        "httpMethod": "GET",
        "headers": {
            "Accept": "*/*"
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
                    "sub": "usr_694c4028",  # Simulate logged in as the patient
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
