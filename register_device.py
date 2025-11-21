import boto3
import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('medusa-devices-prod')

device_id = "medusa-pi-01"
patient_id = 'usr_694c4028'

item = {
    'id': device_id,
    'patientId': patient_id,
    'name': 'Test Device 002',
    'status': 'active',
    'macAddress': '00:11:22:33:44:55',
    'createdAt': datetime.datetime.utcnow().isoformat(),
    'updatedAt': datetime.datetime.utcnow().isoformat(),
    'lastSeen': datetime.datetime.utcnow().isoformat()
}

table.put_item(Item=item)
print(f"Successfully registered device {device_id} to patient {patient_id}")
