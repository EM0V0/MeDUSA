"""
Lambda function to get tremor statistics for a patient.

This provides aggregated statistics over a time period, complementing
the detailed time-series data from query_tremor_data.py.

API Endpoint: GET /api/v1/tremor/statistics
Query Parameters:
  - patient_id (required): Patient ID to query
  - start_time (optional): Start timestamp (Unix seconds)
  - end_time (optional): End timestamp (Unix seconds)

Response Format:
{
  "success": true,
  "statistics": {
    "patient_id": "PAT-001",
    "time_range": {
      "start": 1700230000,
      "end": 1700234567
    },
    "total_readings": 288,
    "parkinsonian_episodes": 42,
    "tremor_scores": {
      "average": 4.5,
      "min": 2.1,
      "max": 8.9,
      "median": 4.3
    },
    "frequency_analysis": {
      "avg_dominant_freq": 4.6,
      "parkinsonian_percentage": 14.6
    },
    "severity_distribution": {
      "minimal": 120,
      "mild": 95,
      "moderate": 50,
      "severe": 20,
      "very_severe": 3
    }
  }
}
"""

import json
import boto3
from decimal import Decimal
from datetime import datetime
from boto3.dynamodb.conditions import Key
import statistics

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('medusa-tremor-analysis')


def check_authorization(event, target_patient_id):
    """
    Verify if the caller is authorized to access the data.
    """
    request_context = event.get('requestContext', {})
    authorizer = request_context.get('authorizer', {})
    
    if not authorizer:
        print("Warning: No authorizer context found.")
        return True

    caller_id = authorizer.get('sub')
    caller_role = authorizer.get('role')
    
    print(f"Authorization check: Caller={caller_id}, Role={caller_role}, Target={target_patient_id}")
    
    if caller_role in ['admin', 'doctor', 'nurse']:
        return True
        
    if caller_role == 'patient':
        if caller_id == target_patient_id:
            return True
        
    print(f"Access denied for user {caller_id} with role {caller_role}")
    return False


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert Decimal to float for JSON serialization."""
    
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def classify_severity(tremor_score):
    """
    Classify tremor severity based on score (0-100 scale).
    
    Args:
        tremor_score: Tremor score (0-100)
        
    Returns:
        Severity category string
    """
    if tremor_score < 20:
        return 'minimal'
    elif tremor_score < 40:
        return 'mild'
    elif tremor_score < 60:
        return 'moderate'
    elif tremor_score < 80:
        return 'severe'
    else:
        return 'very_severe'


def lambda_handler(event, context):
    """
    Get tremor statistics from DynamoDB.
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        
        patient_id = params.get('patient_id')
        start_time = params.get('start_time')
        end_time = params.get('end_time')
        
        print(f"Query params: patient_id={patient_id}, start_time={start_time}, end_time={end_time}")
        
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
            # Convert Unix timestamps to ISO 8601 strings
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
        
        print(f"Querying DynamoDB with key condition: {key_condition}")
        
        # Query all data (no limit for statistics)
        response = table.query(KeyConditionExpression=key_condition)
        
        items = response.get('Items', [])
        print(f"Found {len(items)} tremor analysis records")
        
        # If no data, return empty statistics
        if not items:
            return create_response(200, {
                'success': True,
                'statistics': {
                    'patient_id': patient_id,
                    'total_readings': 0,
                    'message': 'No tremor data found for the specified time range'
                }
            })
        
        # Calculate statistics
        tremor_scores = []
        for item in items:
            if 'tremor_score' in item:
                tremor_scores.append(float(item['tremor_score']))
            else:
                # Fallback to tremor_index * 100 (convert 0-1 ratio to percentage)
                tremor_scores.append(float(item.get('tremor_index', 0)) * 100)
                
        dominant_freqs = [float(item.get('dominant_frequency', 0)) for item in items]
        parkinsonian_count = sum(1 for item in items if item.get('is_parkinsonian', False))
        
        # Get time range from data (ISO 8601 strings)
        timestamps = [item.get('timestamp', '') for item in items]
        timestamps = [ts for ts in timestamps if ts]  # Filter empty strings
        actual_start = min(timestamps) if timestamps else ''
        actual_end = max(timestamps) if timestamps else ''
        
        # Calculate severity distribution
        severity_counts = {
            'minimal': 0,
            'mild': 0,
            'moderate': 0,
            'severe': 0,
            'very_severe': 0
        }
        
        for score in tremor_scores:
            severity = classify_severity(score)
            severity_counts[severity] += 1
        
        # Calculate median
        sorted_scores = sorted(tremor_scores)
        median_score = statistics.median(sorted_scores) if sorted_scores else 0
        
        # Calculate duration (timestamps are ISO 8601 strings, convert to datetime for calculation)
        try:
            if actual_start and actual_end:
                start_dt = datetime.fromisoformat(actual_start.replace('Z', '+00:00'))
                end_dt = datetime.fromisoformat(actual_end.replace('Z', '+00:00'))
                duration_hours = round((end_dt - start_dt).total_seconds() / 3600, 1)
            else:
                duration_hours = 0
        except:
            duration_hours = 0
        
        # Build statistics response
        stats = {
            'patient_id': patient_id,
            'time_range': {
                'start': actual_start,
                'end': actual_end,
                'duration_hours': duration_hours
            },
            'total_readings': len(items),
            'parkinsonian_episodes': parkinsonian_count,
            'tremor_scores': {
                'average': round(sum(tremor_scores) / len(tremor_scores), 2),
                'min': round(min(tremor_scores), 2),
                'max': round(max(tremor_scores), 2),
                'median': round(median_score, 2),
                'std_dev': round(statistics.stdev(tremor_scores), 2) if len(tremor_scores) > 1 else 0
            },
            'frequency_analysis': {
                'avg_dominant_freq': round(sum(dominant_freqs) / len(dominant_freqs), 2),
                'parkinsonian_percentage': round((parkinsonian_count / len(items)) * 100, 1)
            },
            'severity_distribution': severity_counts,
            'latest_reading': {
                'timestamp': actual_end,
                'tremor_score': round(tremor_scores[-1] if tremor_scores else 0, 2),
                'is_parkinsonian': items[-1].get('is_parkinsonian', False) if items else False
            }
        }
        
        print(f"Calculated statistics: parkinsonian={parkinsonian_count}/{len(items)} ({stats['frequency_analysis']['parkinsonian_percentage']}%)")
        
        return create_response(200, {
            'success': True,
            'statistics': stats
        })
        
    except ValueError as e:
        print(f"Validation error: {str(e)}")
        return create_response(400, {
            'success': False,
            'error': f'Invalid parameter: {str(e)}'
        })
        
    except Exception as e:
        print(f"Error calculating statistics: {str(e)}")
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
