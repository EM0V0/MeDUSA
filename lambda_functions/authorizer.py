import json
import os
import jwt
import time

# Configuration
JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret")

def lambda_handler(event, context):
    """
    Lambda Authorizer for API Gateway
    """
    print(f"Authorizer event: {json.dumps(event)}")
    
    # Get the token from the event
    # API Gateway sends the token in 'authorizationToken' for Token Authorizers
    token = event.get('authorizationToken')
    
    if not token:
        print("No token provided")
        raise Exception('Unauthorized')
    
    # Remove 'Bearer ' prefix if present
    if token.lower().startswith('bearer '):
        token = token[7:]
        
    try:
        # Verify the token
        claims = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        print(f"Token verified for user: {claims.get('sub')}")
        
        # Generate IAM Policy
        # We allow access to all resources in this API for valid users
        # In a more complex scenario, we could restrict based on 'role' claim
        principal_id = claims.get('sub', 'user')
        effect = 'Allow'
        resource = event['methodArn']
        
        # To avoid caching issues with methodArn (which includes the specific method/path),
        # we can construct a wildcard resource for this API
        # methodArn format: arn:aws:execute-api:region:account-id:api-id/stage/method/resource-path
        # We want to allow: arn:aws:execute-api:region:account-id:api-id/stage/*/*
        
        arn_parts = resource.split(':')
        api_gateway_arn_tmp = arn_parts[5].split('/')
        api_gateway_arn = f"arn:aws:execute-api:{arn_parts[3]}:{arn_parts[4]}:{api_gateway_arn_tmp[0]}/{api_gateway_arn_tmp[1]}/*/*"
        
        policy = generate_policy(principal_id, effect, api_gateway_arn, claims)
        return policy
        
    except jwt.ExpiredSignatureError:
        print("Token expired")
        raise Exception('Unauthorized')
    except jwt.InvalidTokenError as e:
        print(f"Invalid token: {str(e)}")
        raise Exception('Unauthorized')
    except Exception as e:
        print(f"Error verifying token: {str(e)}")
        raise Exception('Unauthorized')

def generate_policy(principal_id, effect, resource, context=None):
    """
    Generates an IAM policy
    """
    auth_response = {}
    auth_response['principalId'] = principal_id
    
    if effect and resource:
        policy_document = {}
        policy_document['Version'] = '2012-10-17'
        statement = []
        statement_one = {}
        statement_one['Action'] = 'execute-api:Invoke'
        statement_one['Effect'] = effect
        statement_one['Resource'] = resource
        statement.append(statement_one)
        policy_document['Statement'] = statement
        auth_response['policyDocument'] = policy_document
    
    # Optional: Pass claims to the backend Lambda via context
    if context:
        # Context keys must be strings and values must be strings, numbers, or booleans
        auth_context = {}
        for key, value in context.items():
            auth_context[key] = str(value)
        auth_response['context'] = auth_context
        
    return auth_response
