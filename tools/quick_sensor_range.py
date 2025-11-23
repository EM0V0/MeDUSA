import boto3
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Key

ddb=boto3.resource('dynamodb', region_name='us-east-1')
table=ddb.Table('medusa-sensor-data')
start='2025-11-22T23:13:15.000000Z'
end='2025-11-22T23:13:36.000000Z'

def iso_to_ms(s):
    if s.endswith('Z'):
        s=s[:-1]+'+00:00'
    dt=datetime.fromisoformat(s)
    return int(dt.replace(tzinfo=timezone.utc).timestamp()*1000 + dt.microsecond/1000)

s=iso_to_ms(start)
e=iso_to_ms(end)
print('range ms',s,e)
resp=table.query(KeyConditionExpression=Key('device_id').eq('medusa-pi-01') & Key('timestamp').between(s,e), ScanIndexForward=True)
items=resp.get('Items', [])
print('count',len(items))
for it in sorted(items, key=lambda x:int(x['timestamp'])):
    ts=int(it['timestamp'])
    print(ts, datetime.fromtimestamp(ts/1000, timezone.utc).isoformat(), it.get('magnitude'))
