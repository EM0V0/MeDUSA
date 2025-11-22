import boto3
from boto3.dynamodb.conditions import Key

def verify_data():
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    
    # Check raw data
    raw_table = dynamodb.Table('medusa-sensor-data')
    patient_id = 'usr_694c4028'
    
    print(f"Checking data for patient: {patient_id}")
    
    try:
        response = raw_table.query(
            KeyConditionExpression=Key('patient_id').eq(patient_id),
            Limit=10
        )
        print(f"Raw data count (sample): {response['Count']}")
        if response['Count'] > 0:
            print("Sample raw item:", response['Items'][0])
    except Exception as e:
        print(f"Error checking raw data: {e}")

    # Check analysis data
    analysis_table = dynamodb.Table('medusa-tremor-analysis')
    try:
        response = analysis_table.query(
            KeyConditionExpression=Key('patient_id').eq(patient_id),
            Limit=10
        )
        print(f"Analysis data count (sample): {response['Count']}")
        if response['Count'] > 0:
            print("Sample analysis item:", response['Items'][0])
    except Exception as e:
        print(f"Error checking analysis data: {e}")

if __name__ == "__main__":
    verify_data()
