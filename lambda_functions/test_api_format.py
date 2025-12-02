"""
Test end-to-end data flow from DynamoDB to API Gateway format.
This script simulates what the QueryTremorData Lambda returns to Flutter.
"""

import boto3
import json
from decimal import Decimal
from datetime import datetime
from boto3.dynamodb.conditions import Key


class DecimalEncoder(json.JSONEncoder):
    """Convert Decimal to float for JSON serialization."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def test_api_response_format(patient_id='usr_694c4028', limit=10):
    """
    Simulate the QueryTremorData Lambda response format.
    This is exactly what the Flutter app will receive.
    """
    
    print(f"\n{'='*60}")
    print(f"Testing API Response Format")
    print(f"{'='*60}\n")
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('medusa-tremor-analysis')
    
    # Query data (same as Lambda does)
    response = table.query(
        KeyConditionExpression=Key('patient_id').eq(patient_id),
        Limit=limit,
        ScanIndexForward=False  # Newest first
    )
    
    items = response.get('Items', [])
    print(f"✅ Found {len(items)} records in DynamoDB\n")
    
    if not items:
        print("❌ No data found!")
        return
    
    # Normalize field names (same as Lambda does)
    normalized_items = []
    for item in items:
        normalized_item = {
            'patient_id': item.get('patient_id'),
            'timestamp': item.get('timestamp'),
            'device_id': item.get('device_id'),
            
            # Field normalization: rms_value → rms
            'rms': item.get('rms_value', item.get('rms', 0)),
            'dominant_frequency': item.get('dominant_frequency', item.get('dominant_freq', 0)),
            'tremor_power': item.get('tremor_power', 0),
            'total_power': item.get('total_power', 0),
            
            # Both tremor_index and tremor_score
            'tremor_index': item.get('tremor_index', 0),
            'tremor_score': item.get('tremor_score', float(item.get('tremor_index', 0)) * 100),
            
            'is_parkinsonian': item.get('is_parkinsonian', False),
            'signal_quality': item.get('signal_quality', 0),
            
            # Optional fields
            'patient_name': item.get('patient_name'),
            'sample_count': item.get('sample_count'),
            'sampling_rate': item.get('sampling_rate'),
        }
        normalized_items.append(normalized_item)
    
    # Create API response (same as Lambda returns)
    api_response = {
        'success': True,
        'data': normalized_items,
        'count': len(normalized_items),
        'has_more': 'LastEvaluatedKey' in response
    }
    
    # Convert to JSON (as API Gateway would)
    json_response = json.dumps(api_response, cls=DecimalEncoder, indent=2)
    
    print("📋 Simulated API Response (First 3 records):")
    print("="*60)
    
    # Show first 3 records
    preview_response = {
        'success': True,
        'data': normalized_items[:3],
        'count': len(normalized_items),
        'has_more': 'LastEvaluatedKey' in response
    }
    print(json.dumps(preview_response, cls=DecimalEncoder, indent=2))
    
    print("\n" + "="*60)
    print("📊 Data Summary:")
    print("="*60)
    
    for i, item in enumerate(normalized_items[:5], 1):
        print(f"\nRecord {i}:")
        print(f"  Timestamp: {item['timestamp']}")
        print(f"  Device: {item['device_id']}")
        print(f"  RMS: {item['rms']:.4f}")
        print(f"  Dominant Freq: {item['dominant_frequency']:.2f} Hz")
        print(f"  Tremor Index: {item['tremor_index']:.4f} (0-1 scale)")
        print(f"  Tremor Score: {item['tremor_score']:.2f} (0-100 scale)")
        print(f"  Parkinsonian: {item['is_parkinsonian']}")
        print(f"  Signal Quality: {item['signal_quality']:.2f}")
    
    print("\n" + "="*60)
    print("✅ Flutter Field Compatibility Check:")
    print("="*60)
    
    # Check required fields for Flutter TremorAnalysis model
    required_fields = [
        'device_id',
        'timestamp', 
        'rms',  # ← Maps from rms_value
        'dominant_frequency',  # ← Flutter uses 'tremor_frequency' OR 'dominant_frequency'
        'tremor_power',  # ← Flutter uses 'tremor_amplitude' OR 'tremor_power'
        'tremor_index',
        'is_parkinsonian'
    ]
    
    sample = normalized_items[0]
    all_present = True
    
    for field in required_fields:
        value = sample.get(field)
        status = "✅" if value is not None else "❌"
        print(f"{status} {field}: {value}")
        if value is None:
            all_present = False
    
    print("\n" + "="*60)
    if all_present:
        print("🎉 SUCCESS! All required fields are present.")
        print("   Flutter app should be able to parse this data.")
    else:
        print("⚠️  WARNING: Some required fields are missing!")
    
    print("="*60 + "\n")
    
    # Save full response to file
    with open('d:/25fall/Capstone/ble/MeDUSA/lambda_functions/test_api_response.json', 'w') as f:
        f.write(json_response)
    
    print("💾 Full API response saved to: test_api_response.json\n")
    
    return api_response


if __name__ == '__main__':
    result = test_api_response_format(
        patient_id='usr_694c4028',
        limit=10
    )
    
    if result:
        print("✅ Test complete! Data format is ready for Flutter frontend.")
    else:
        print("❌ Test failed! Check data availability.")
