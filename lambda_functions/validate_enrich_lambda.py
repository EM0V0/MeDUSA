"""
Quick validation script to test if the fixed enrich Lambda is working correctly.
This simulates Pi sending data and checks if it's enriched with correct patient_id.
"""

import boto3
import json
from datetime import datetime

lambda_client = boto3.client('lambda')
dynamodb = boto3.resource('dynamodb')
sensor_table = dynamodb.Table('medusa-sensor-data')


def test_enrich_lambda_single_mode():
    """Test enrich Lambda with single-value mode (legacy format)."""
    
    print("\n" + "="*60)
    print("Test 1: Single-Value Mode")
    print("="*60 + "\n")
    
    test_event = {
        'device_id': 'DEV-002',
        'timestamp': int(datetime.utcnow().timestamp()),
        'accel_x': 0.123,
        'accel_y': 0.234,
        'accel_z': 0.345,
        'magnitude': 0.456,
        'temperature': 25.5,
        'sequence': 999,
        'ttl': int(datetime.utcnow().timestamp()) + 3600
    }
    
    print(f"📤 Invoking Lambda with single-value data...")
    print(f"Device: {test_event['device_id']}")
    print(f"Timestamp: {test_event['timestamp']}\n")
    
    response = lambda_client.invoke(
        FunctionName='medusa-enrich-sensor-data',
        InvocationType='RequestResponse',
        Payload=json.dumps(test_event)
    )
    
    result = json.loads(response['Payload'].read())
    print(f"📥 Lambda Response:")
    print(f"Status Code: {result.get('statusCode')}")
    print(f"Body: {result.get('body')}\n")
    
    if result.get('statusCode') == 200:
        body = json.loads(result['body'])
        print(f"✅ SUCCESS!")
        print(f"   Device ID: {body.get('device_id')}")
        print(f"   Patient ID: {body.get('patient_id')}")
        print(f"   Mode: {body.get('mode')}")
        
        if body.get('patient_id') == 'usr_694c4028':
            print(f"\n🎉 CORRECT patient_id! (usr_694c4028)")
            return True
        else:
            print(f"\n❌ WRONG patient_id: {body.get('patient_id')} (expected: usr_694c4028)")
            return False
    else:
        print(f"❌ FAILED: Lambda returned error")
        return False


def test_enrich_lambda_array_mode():
    """Test enrich Lambda with array mode (batch format)."""
    
    print("\n" + "="*60)
    print("Test 2: Array Mode (Batch)")
    print("="*60 + "\n")
    
    # Generate 10 sample points
    test_event = {
        'device_id': 'DEV-002',
        'timestamp': int(datetime.utcnow().timestamp()),
        'accel_x': [0.1 + i*0.01 for i in range(10)],
        'accel_y': [0.2 + i*0.01 for i in range(10)],
        'accel_z': [0.3 + i*0.01 for i in range(10)],
        'sampling_rate': 100,
        'battery_level': 85,
        'sequence': 1000,
        'device_status': 'active',
        'ttl': int(datetime.utcnow().timestamp()) + 3600
    }
    
    print(f"📤 Invoking Lambda with array data...")
    print(f"Device: {test_event['device_id']}")
    print(f"Samples: {len(test_event['accel_x'])} per axis")
    print(f"Timestamp: {test_event['timestamp']}\n")
    
    response = lambda_client.invoke(
        FunctionName='medusa-enrich-sensor-data',
        InvocationType='RequestResponse',
        Payload=json.dumps(test_event)
    )
    
    result = json.loads(response['Payload'].read())
    print(f"📥 Lambda Response:")
    print(f"Status Code: {result.get('statusCode')}")
    print(f"Body: {result.get('body')}\n")
    
    if result.get('statusCode') == 200:
        body = json.loads(result['body'])
        print(f"✅ SUCCESS!")
        print(f"   Device ID: {body.get('device_id')}")
        print(f"   Patient ID: {body.get('patient_id')}")
        print(f"   Mode: {body.get('mode')}")
        
        if body.get('patient_id') == 'usr_694c4028':
            print(f"\n🎉 CORRECT patient_id! (usr_694c4028)")
            return True
        else:
            print(f"\n❌ WRONG patient_id: {body.get('patient_id')} (expected: usr_694c4028)")
            return False
    else:
        print(f"❌ FAILED: Lambda returned error")
        return False


def verify_stored_data(timestamp):
    """Verify data was stored correctly in DynamoDB."""
    
    print("\n" + "="*60)
    print("Test 3: Verify DynamoDB Storage")
    print("="*60 + "\n")
    
    print(f"🔍 Querying sensor-data table for recent records...")
    
    response = sensor_table.query(
        KeyConditionExpression='device_id = :did',
        ExpressionAttributeValues={':did': 'DEV-002'},
        ScanIndexForward=False,
        Limit=1
    )
    
    if response['Items']:
        item = response['Items'][0]
        print(f"\n📋 Most recent record:")
        print(f"   Device ID: {item.get('device_id')}")
        print(f"   Timestamp: {item.get('timestamp')}")
        print(f"   Patient ID: {item.get('patient_id')}")
        print(f"   Enriched At: {item.get('enriched_at')}")
        
        if 'accelerometer_x' in item:
            print(f"   Format: Array (samples: {len(item['accelerometer_x'])})")
        else:
            print(f"   Format: Single-value")
        
        if item.get('patient_id') == 'usr_694c4028':
            print(f"\n✅ Stored with CORRECT patient_id!")
            return True
        else:
            print(f"\n❌ Stored with WRONG patient_id: {item.get('patient_id')}")
            return False
    else:
        print(f"❌ No records found in sensor-data table")
        return False


if __name__ == '__main__':
    print("\n" + "🧪 "*20)
    print("MeDUSA Enrich Lambda Validation Test")
    print("🧪 "*20)
    
    results = []
    
    # Test 1: Single-value mode
    results.append(test_enrich_lambda_single_mode())
    
    # Test 2: Array mode
    results.append(test_enrich_lambda_array_mode())
    
    # Wait a moment for DynamoDB write
    import time
    time.sleep(2)
    
    # Test 3: Verify storage
    results.append(verify_stored_data(int(datetime.utcnow().timestamp())))
    
    # Summary
    print("\n" + "="*60)
    print("📊 Test Summary")
    print("="*60)
    print(f"Single-Value Mode: {'✅ PASS' if results[0] else '❌ FAIL'}")
    print(f"Array Mode:        {'✅ PASS' if results[1] else '❌ FAIL'}")
    print(f"DynamoDB Storage:  {'✅ PASS' if results[2] else '❌ FAIL'}")
    print("="*60)
    
    if all(results):
        print("\n🎉 ALL TESTS PASSED!")
        print("✅ Enrich Lambda is working correctly")
        print("✅ Patient ID mapping is correct (usr_694c4028)")
        print("✅ Data is being stored properly\n")
    else:
        print("\n⚠️  SOME TESTS FAILED")
        print("Please review the errors above\n")
