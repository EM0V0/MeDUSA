"""
Lambda function to get patients assigned to a doctor.

API Endpoint: GET /api/v1/doctor/patients
Query Parameters:
  - doctor_id (required): Doctor ID

Response Format:
{
  "success": true,
  "patients": [
    {
      "patient_id": "usr_xxx",
      "email": "patient@example.com",
      "name": "John Doe",
      "assigned_at": "2025-11-18T21:00:00Z"
    }
  ],
  "count": 5
}
"""

import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
users_table = dynamodb.Table('medusa-users-prod')
profiles_table = dynamodb.Table('medusa-patient-profiles-prod')


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert Decimal to float for JSON serialization."""
    
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def lambda_handler(event, context):
    """
    Get patients assigned to a doctor.
    
    Args:
        event: API Gateway event object
        context: Lambda context object
        
    Returns:
        API Gateway response with patient list
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        doctor_id = params.get('doctor_id')
        
        print(f"Get patients for doctor: {doctor_id}")
        
        # Validate required parameters
        if not doctor_id:
            return create_response(400, {
                'success': False,
                'error': 'doctor_id is required'
            })
        
        # Query patient profiles by doctor_id using GSI
        try:
            response = profiles_table.query(
                IndexName='DoctorIndex',
                KeyConditionExpression='doctor_id = :doctor_id',
                ExpressionAttributeValues={':doctor_id': doctor_id}
            )
        except Exception as e:
            print(f"Error querying DoctorIndex: {e}")
            # Fallback to scan if index doesn't exist
            response = profiles_table.scan(
                FilterExpression='doctor_id = :doctor_id',
                ExpressionAttributeValues={':doctor_id': doctor_id}
            )
        
        profiles = response.get('Items', [])
        print(f"Found {len(profiles)} patient profiles")
        
        # Get full patient information
        patients = []
        for profile in profiles:
            patient_id = profile.get('userId')  # Match DynamoDB schema
            try:
                user_response = users_table.get_item(Key={'id': patient_id})
                if 'Item' in user_response:
                    user = user_response['Item']
                    patients.append({
                        'patient_id': patient_id,
                        'email': user.get('email', ''),
                        'name': user.get('name', ''),
                        'assigned_at': profile.get('assigned_at', ''),
                        'status': profile.get('status', 'active'),
                    })
            except Exception as e:
                print(f"Error fetching user {patient_id}: {e}")
                continue
        
        return create_response(200, {
            'success': True,
            'patients': patients,
            'count': len(patients)
        })
        
    except Exception as e:
        print(f"Error getting patients: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return create_response(500, {
            'success': False,
            'error': 'Internal server error',
            'details': str(e)
        })


def create_response(status_code, body):
    """
    Create API Gateway response with CORS headers.
    
    Args:
        status_code: HTTP status code
        body: Response body (will be JSON encoded)
        
    Returns:
        API Gateway response object
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        },
        'body': json.dumps(body, cls=DecimalEncoder)
    }
