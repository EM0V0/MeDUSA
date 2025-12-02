import boto3
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Key

TABLE_NAME = 'medusa-sensor-data'
DEVICE_ID = 'medusa-pi-01'
START_ISO = '2025-11-22T23:13:26.256000Z'
END_ISO = '2025-11-22T23:13:31.242000Z'


def iso_to_ms(s):
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    dt = datetime.fromisoformat(s)
    return int(dt.replace(tzinfo=timezone.utc).timestamp() * 1000 + dt.microsecond/1000)


def main():
    ddb = boto3.resource('dynamodb', region_name='us-east-1')
    table = ddb.Table(TABLE_NAME)

    start_ms = iso_to_ms(START_ISO)
    end_ms = iso_to_ms(END_ISO)
    print('Querying', TABLE_NAME, 'for device', DEVICE_ID, 'between', start_ms, end_ms)

    # Build query
    response = table.query(
        KeyConditionExpression=Key('device_id').eq(DEVICE_ID) & Key('timestamp').between(start_ms, end_ms),
        ScanIndexForward=True,
        Limit=1000
    )

    items = response.get('Items', [])
    print('Found items:', len(items))
    if items:
        items.sort(key=lambda x: int(x['timestamp']))
        for it in items:
            ts = int(it['timestamp'])
            print(ts, datetime.fromtimestamp(ts/1000, timezone.utc).isoformat(), it.get('magnitude') or it.get('accel_x'))

if __name__ == '__main__':
    main()
