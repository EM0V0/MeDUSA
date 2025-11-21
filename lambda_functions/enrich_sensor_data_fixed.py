"""
Enhanced version of medusa-enrich-sensor-data Lambda.
Fixes:
1. Query from medusa-devices-prod instead of medusa-device-patient-mapping
2. Handle array format accelerometer data (batch mode)
3. Store with correct patient_id

This Lambda receives data from AWS IoT Rule and stores it in medusa-sensor-data table.
"""

import json
import boto3
import os
from decimal import Decimal
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
devices_table = dynamodb.Table('medusa-devices-prod')
sensor_table = dynamodb.Table('medusa-sensor-data')


def lambda_handler(event, context):
    """
    Enrich IoT sensor data with patient info from device registry.
    
    Handles two formats:
    1. Single-value mode: {accel_x: float, accel_y: float, accel_z: float}
    2. Array mode: {accel_x: [float...], accel_y: [float...], accel_z: [float...]}
    
    Args:
        event: IoT Rule event with device data
        context: Lambda context
        
    Returns:
        Status response
    """
    
    print(f"Received event: {json.dumps(event, default=str)}")
    
    device_id = event.get('device_id')
    if not device_id:
        print("ERROR: Missing device_id in event")
        return {'statusCode': 400, 'body': 'Missing device_id'}
    
    # Query device registry for patient assignment
    try:
        device_record = devices_table.get_item(Key={'id': device_id})
        
        if 'Item' not in device_record:
            print(f"WARNING: Device {device_id} not found in registry")
            patient_id = "UNASSIGNED"
            patient_name = None
        else:
            device_item = device_record['Item']
            patient_id = device_item.get('patientId', 'UNASSIGNED')
            patient_name = device_item.get('patientName')
            device_status = device_item.get('status', 'unknown')
            
            print(f"Device {device_id} -> Patient {patient_id} (status: {device_status})")
        
        # Detect data format (single-value vs array)
        accel_x = event.get('accel_x')
        accel_y = event.get('accel_y')
        accel_z = event.get('accel_z')
        
        is_array_mode = isinstance(accel_x, list)
        
        if is_array_mode:
            print(f"Array mode detected: {len(accel_x)} samples per axis")
            
            # Store array data
            enriched_data = {
                'device_id': device_id,
                'timestamp': int(event['timestamp']),
                'accelerometer_x': [Decimal(str(x)) for x in accel_x],
                'accelerometer_y': [Decimal(str(y)) for y in accel_y],
                'accelerometer_z': [Decimal(str(z)) for z in accel_z],
                'sampling_rate': event.get('sampling_rate', 100),
                'ttl': event.get('ttl', int(event['timestamp']) + 2592000),  # 30 days default
                
                # Patient enrichment
                'patient_id': patient_id,
                'patient_name': patient_name,
                'enriched_at': int(datetime.utcnow().timestamp())
            }
            
            # Optional fields
            if 'battery_level' in event:
                enriched_data['battery_level'] = int(event['battery_level'])
            if 'temperature' in event and event['temperature'] is not None:
                enriched_data['temperature'] = Decimal(str(event['temperature']))
            if 'sequence' in event:
                enriched_data['sequence'] = int(event['sequence'])
            if 'device_status' in event:
                enriched_data['device_status'] = event['device_status']
        
        else:
            print("Single-value mode detected")
            
            # Store single-value data (legacy format)
            enriched_data = {
                'device_id': device_id,
                'timestamp': int(event['timestamp']),
                'accel_x': Decimal(str(accel_x)),
                'accel_y': Decimal(str(accel_y)),
                'accel_z': Decimal(str(accel_z)),
                'ttl': event.get('ttl', int(event['timestamp']) + 2592000),
                
                # Patient enrichment
                'patient_id': patient_id,
                'patient_name': patient_name,
                'enriched_at': int(datetime.utcnow().timestamp())
            }
            
            # Optional fields
            if 'magnitude' in event and event['magnitude'] is not None:
                enriched_data['magnitude'] = Decimal(str(event['magnitude']))
            if 'temperature' in event and event['temperature'] is not None:
                enriched_data['temperature'] = Decimal(str(event['temperature']))
            if 'sequence' in event:
                enriched_data['sequence'] = int(event['sequence'])
        
        # Write to sensor table
        sensor_table.put_item(Item=enriched_data)
        
        print(f"✅ Successfully stored sensor data for device {device_id} (patient: {patient_id})")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'device_id': device_id,
                'patient_id': patient_id,
                'status': 'stored',
                'mode': 'array' if is_array_mode else 'single',
                'timestamp': event['timestamp']
            })
        }
        
    except Exception as e:
        print(f"❌ Error enriching data: {str(e)}")
        import traceback
        traceback.print_exc()
        return {'statusCode': 500, 'body': str(e)}
