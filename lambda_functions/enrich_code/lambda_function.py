import json
import boto3
import os
from decimal import Decimal
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
mapping_table = dynamodb.Table('medusa-device-patient-mapping')
sensor_table = dynamodb.Table('medusa-sensor-data')

def lambda_handler(event, context):
    """
    Enrich IoT sensor data with patient info from device-patient mapping.
    Handles:
    - Device reassignments (queries latest active assignment)
    - Unassigned devices (stores with patient_id=null)
    - Multiple patients using same device over time
    """
    
    device_id = event.get('device_id')
    if not device_id:
        return {'statusCode': 400, 'body': 'Missing device_id'}
    
    # Query for current active assignment
    try:
        response = mapping_table.query(
            KeyConditionExpression='device_id = :did',
            FilterExpression='attribute_not_exists(assignment_end) OR assignment_end = :null',
            ExpressionAttributeValues={
                ':did': device_id,
                ':null': None
            },
            ScanIndexForward=False,  # Latest first
            Limit=1
        )
        
        # Get patient info if device is assigned
        patient_id = "UNASSIGNED"
        patient_name = None
        assignment_timestamp = None
        
        if response['Items']:
            assignment = response['Items'][0]
            if assignment.get('status') == 'active':
                patient_id = assignment.get('patient_id')
                patient_name = assignment.get('patient_name')
                assignment_timestamp = assignment.get('assignment_timestamp')
        
        # Enrich sensor data
        enriched_data = {
            'device_id': device_id,
            'timestamp': event['timestamp'],
            'accel_x': Decimal(str(event['accel_x'])),
            'accel_y': Decimal(str(event['accel_y'])),
            'accel_z': Decimal(str(event['accel_z'])),
            'magnitude': Decimal(str(event['magnitude'])),
            'sequence': event['sequence'],
            'ttl': event['ttl'],
            
            # Patient enrichment
            'patient_id': patient_id,  # null if unassigned
            'patient_name': patient_name,  # null if unassigned
            'assignment_timestamp': assignment_timestamp,  # tracks which assignment
            'enriched_at': int(datetime.utcnow().timestamp())
        }
        
        # Add optional temperature
        if 'temperature' in event and event['temperature'] is not None:
            enriched_data['temperature'] = Decimal(str(event['temperature']))
        
        # Write to sensor table
        sensor_table.put_item(Item=enriched_data)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'device_id': device_id,
                'patient_id': patient_id,
                'status': 'stored'
            })
        }
        
    except Exception as e:
        print(f"Error enriching data: {str(e)}")
        return {'statusCode': 500, 'body': str(e)}