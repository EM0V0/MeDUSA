"""
Lambda function to assign a patient to a doctor.

API Endpoint: POST /api/v1/doctor/assign-patient
Body:
{
  "doctor_id": "usr_xxx",
  "patient_email": "patient@example.com"
}

Response Format:
{
  "success": true,
  "message": "Patient assigned successfully",
  "assignment": {
    "doctor_id": "usr_xxx",
    "patient_id": "usr_yyy",
    "assigned_at": "2025-11-18T21:00:00Z"
  }
}
"""

import json
import boto3
from datetime import datetime
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
    Assign a patient to a doctor.
    
    Args:
        event: API Gateway event object
        context: Lambda context object
        
    Returns:
        API Gateway response
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else event.get('body', {})
        
        doctor_id = body.get('doctor_id')
        patient_email = body.get('patient_email')
        
        print(f"Assignment request: doctor_id={doctor_id}, patient_email={patient_email}")
        
        # Validate required parameters
        if not doctor_id or not patient_email:
            return create_response(400, {
                'success': False,
                'error': 'doctor_id and patient_email are required'
            })
        
        # Verify doctor exists and has doctor role
        doctor_response = users_table.get_item(Key={'id': doctor_id})
        if 'Item' not in doctor_response:
            return create_response(404, {
                'success': False,
                'error': 'Doctor not found'
            })
        
        doctor = doctor_response['Item']
        if doctor.get('role') != 'doctor':
            return create_response(403, {
                'success': False,
                'error': 'User is not a doctor'
            })
        
        # Find patient by email
        patient_response = users_table.scan(
            FilterExpression='email = :email',
            ExpressionAttributeValues={':email': patient_email}
        )
        
        if not patient_response['Items']:
            return create_response(404, {
                'success': False,
                'error': f'Patient with email {patient_email} not found'
            })
        
        patient = patient_response['Items'][0]
        patient_id = patient.get('id')
        
        # Verify patient has patient role
        if patient.get('role') != 'patient':
            return create_response(400, {
                'success': False,
                'error': 'User is not a patient'
            })
        
        # Update or create patient profile with doctor assignment
        assigned_at = datetime.utcnow().isoformat() + 'Z'
        
        try:
            # Try to update existing profile
            profiles_table.update_item(
                Key={'userId': patient_id},
                UpdateExpression='SET doctor_id = :doctor_id, assigned_at = :assigned_at, updated_at = :updated_at',
                ExpressionAttributeValues={
                    ':doctor_id': doctor_id,
                    ':assigned_at': assigned_at,
                    ':updated_at': assigned_at,
                },
                ConditionExpression='attribute_exists(userId)'
            )
            print(f"Updated existing profile for patient {patient_id}")
        except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
            # Create new profile if it doesn't exist
            profiles_table.put_item(
                Item={
                    'userId': patient_id,
                    'doctor_id': doctor_id,
                    'assigned_at': assigned_at,
                    'created_at': assigned_at,
                    'updated_at': assigned_at,
                    'status': 'active',
                }
            )
            print(f"Created new profile for patient {patient_id}")
        
        return create_response(200, {
            'success': True,
            'message': 'Patient assigned successfully',
            'assignment': {
                'doctor_id': doctor_id,
                'patient_id': patient_id,
                'patient_email': patient_email,
                'patient_name': patient.get('name', ''),
                'assigned_at': assigned_at
            }
        })
        
    except ValueError as e:
        print(f"Validation error: {str(e)}")
        return create_response(400, {
            'success': False,
            'error': f'Invalid parameter: {str(e)}'
        })
        
    except Exception as e:
        print(f"Error assigning patient: {str(e)}")
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
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        },
        'body': json.dumps(body, cls=DecimalEncoder)
    }
