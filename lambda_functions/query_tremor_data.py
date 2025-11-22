"""
Lambda function to query tremor analysis data from DynamoDB.

This Lambda is designed to be invoked by API Gateway to serve
tremor analysis data to the Flutter frontend.

API Endpoint: GET /api/v1/tremor/analysis
Query Parameters:
  - patient_id (required): Patient ID to query
  - device_id (optional): Filter by device ID
  - start_time (optional): Start timestamp (Unix seconds)
  - end_time (optional): End timestamp (Unix seconds)
  - limit (optional): Maximum results (default 100, max 500)

Response Format:
{
  "success": true,
  "data": [
    {
      "patient_id": "PAT-001",
      "timestamp": 1700234567,
      "device_id": "DEV-001",
      "tremor_index": 0.8551,
      "dominant_frequency": 4.6,
      "is_parkinsonian": true,
      "rms_value": 0.67,
      "signal_quality": 0.95,
      "tremor_power": 0.45,
      "total_power": 0.53
    }
  ],
  "count": 10
}
"""

import json
import boto3
from decimal import Decimal
from datetime import datetime
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('medusa-tremor-analysis')


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert Decimal to float for JSON serialization."""
    
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def check_authorization(event, target_patient_id):
    """
    Verify if the caller is authorized to access the data.
    """
    request_context = event.get('requestContext', {})
    # API Gateway Lambda Authorizer context is usually in 'authorizer'
    # For custom authorizers, claims are in 'authorizer'
    authorizer = request_context.get('authorizer', {})
    
    if not authorizer:
        # If no authorizer context is present, it might be a direct invocation or test
        # In production with API Gateway, this should be populated
        print("Warning: No authorizer context found.")
        return True # Or False if you want to be strict

    caller_id = authorizer.get('sub')
    caller_role = authorizer.get('role')
    
    print(f"Authorization check: Caller={caller_id}, Role={caller_role}, Target={target_patient_id}")
    
    # 1. Admins and Doctors can access any patient data
    if caller_role in ['admin', 'doctor', 'nurse']:
        return True
        
    # 2. Patients can only access their own data
    # Note: We assume patient_id in token matches patient_id in query
    # You might need to map user_id to patient_id if they differ
    if caller_role == 'patient':
        if caller_id == target_patient_id:
            return True
        # Also check if caller_id is an email and target is a PAT-ID
        # This mapping logic depends on your user system
        
    print(f"Access denied for user {caller_id} with role {caller_role}")
    return False


def lambda_handler(event, context):
    """
    Query tremor analysis data from DynamoDB.
    
    Args:
        event: API Gateway event object
        context: Lambda context object
        
    Returns:
        API Gateway response with tremor analysis data
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse query parameters from API Gateway
        params = event.get('queryStringParameters', {}) or {}
        
        patient_id = params.get('patient_id')
        device_id = params.get('device_id')
        start_time = params.get('start_time')
        end_time = params.get('end_time')
        limit = int(params.get('limit', 100))
        
        print(f"Query params: patient_id={patient_id}, device_id={device_id}, "
              f"start_time={start_time}, end_time={end_time}, limit={limit}")
        
        # Validate required parameters
        if not patient_id:
            return create_response(400, {
                'success': False,
                'error': 'patient_id is required'
            })
            
        # Authorization Check
        if not check_authorization(event, patient_id):
            return create_response(403, {
                'success': False,
                'error': 'Access denied: You do not have permission to view this data'
            })
        
        # Build DynamoDB query
        key_condition = Key('patient_id').eq(patient_id)
        
        # Add time range filter if provided
        # Note: Timestamps in DynamoDB are stored as ISO 8601 strings
        # but API receives Unix timestamps (seconds), so we need to convert
        if start_time and end_time:
            start_iso = datetime.utcfromtimestamp(int(start_time)).isoformat() + 'Z'
            end_iso = datetime.utcfromtimestamp(int(end_time)).isoformat() + 'Z'
            key_condition = key_condition & Key('timestamp').between(start_iso, end_iso)
            print(f"Time range filter: {start_iso} to {end_iso}")
        elif start_time:
            start_iso = datetime.utcfromtimestamp(int(start_time)).isoformat() + 'Z'
            key_condition = key_condition & Key('timestamp').gte(start_iso)
            print(f"Start time filter: {start_iso}")
        elif end_time:
            end_iso = datetime.utcfromtimestamp(int(end_time)).isoformat() + 'Z'
            key_condition = key_condition & Key('timestamp').lte(end_iso)
            print(f"End time filter: {end_iso}")
        
        # Prepare query parameters
        query_params = {
            'KeyConditionExpression': key_condition,
            'Limit': min(limit, 2000),  # Cap at 2000 to prevent excessive reads
            'ScanIndexForward': False  # Sort by timestamp DESC (newest first)
        }
        
        # Add filter expression for device_id if provided
        if device_id:
            query_params['FilterExpression'] = Attr('device_id').eq(device_id)
        
        print(f"Querying DynamoDB with KeyConditionExpression: {key_condition}")
        
        # Execute query
        response = table.query(**query_params)
        
        items = response.get('Items', [])
        print(f"Found {len(items)} tremor analysis records")
        
        # Log sample item for debugging
        if items:
            print(f"Sample item: {json.dumps(items[0], cls=DecimalEncoder)}")
        
        # Normalize field names to match frontend expectations
        normalized_items = []
        for item in items:
            normalized_item = {
                'patient_id': item.get('patient_id'),
                'timestamp': item.get('timestamp'),
                'device_id': item.get('device_id'),
                
                # Normalize field names
                'rms': item.get('rms_value', item.get('rms', 0)),  # Map rms_value to rms
                'dominant_frequency': item.get('dominant_frequency', item.get('dominant_freq', 0)),
                'tremor_power': item.get('tremor_power', 0),
                
                # Handle both tremor_score (0-100) and tremor_index (0-1)
                # We only return tremor_index (0-1) to the frontend to avoid redundancy
                'tremor_index': item.get('tremor_index', 0),
                
                'is_parkinsonian': item.get('is_parkinsonian', False),
            }
            normalized_items.append(normalized_item)
        
        # Return success response
        return create_response(200, {
            'success': True,
            'data': normalized_items,
            'count': len(normalized_items),
            'has_more': 'LastEvaluatedKey' in response
        })
        
    except ValueError as e:
        print(f"Validation error: {str(e)}")
        return create_response(400, {
            'success': False,
            'error': f'Invalid parameter: {str(e)}'
        })
        
    except Exception as e:
        print(f"Error querying tremor data: {str(e)}")
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


def get_statistics(patient_id, start_time=None, end_time=None):
    """
    Calculate statistics for a patient's tremor data.
    
    This is a helper function that can be called separately
    to get aggregated statistics.
    
    Args:
        patient_id: Patient ID
        start_time: Start timestamp (Unix seconds, optional)
        end_time: End timestamp (Unix seconds, optional)
        
    Returns:
        Dictionary with statistics
    """
    
    # Build query
    key_condition = Key('patient_id').eq(patient_id)
    
    # Convert Unix timestamps to ISO 8601 strings if provided
    if start_time and end_time:
        start_iso = datetime.utcfromtimestamp(int(start_time)).isoformat() + 'Z'
        end_iso = datetime.utcfromtimestamp(int(end_time)).isoformat() + 'Z'
        key_condition = key_condition & Key('timestamp').between(start_iso, end_iso)
    
    # Query all data (without limit for statistics)
    response = table.query(KeyConditionExpression=key_condition)
    items = response.get('Items', [])
    
    if not items:
        return {
            'patient_id': patient_id,
            'count': 0,
            'avg_tremor_score': 0,
            'max_tremor_score': 0,
            'min_tremor_score': 0,
            'parkinsonian_episodes': 0
        }
    
    # Calculate statistics
    tremor_scores = []
    for item in items:
        if 'tremor_score' in item:
            tremor_scores.append(float(item['tremor_score']))
        else:
            # Fallback to tremor_index * 100 (convert 0-1 ratio to percentage)
            tremor_scores.append(float(item.get('tremor_index', 0)) * 100)
            
    parkinsonian_count = sum(1 for item in items if item.get('is_parkinsonian', False))
    
    return {
        'patient_id': patient_id,
        'count': len(items),
        'avg_tremor_score': round(sum(tremor_scores) / len(tremor_scores), 2),
        'max_tremor_score': round(max(tremor_scores), 2),
        'min_tremor_score': round(min(tremor_scores), 2),
        'parkinsonian_episodes': parkinsonian_count,
        'start_time': int(start_time) if start_time else None,
        'end_time': int(end_time) if end_time else None
    }
