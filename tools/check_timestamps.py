import boto3
from boto3.dynamodb.conditions import Key
import datetime
import statistics

TABLE_NAME = 'medusa-tremor-analysis'
PATIENT_ID = 'usr_694c4028'

def parse_ts(s):
    # Expected format: 2025-11-22T22:55:28.269000Z
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    try:
        return datetime.datetime.fromisoformat(s)
    except Exception:
        # fallback
        try:
            return datetime.datetime.strptime(s, '%Y-%m-%dT%H:%M:%S.%fZ')
        except Exception:
            return None

def main():
    ddb = boto3.resource('dynamodb')
    table = ddb.Table(TABLE_NAME)
    items = []
    kwargs = {
        'KeyConditionExpression': Key('patient_id').eq(PATIENT_ID),
        'ScanIndexForward': True,
        'Limit': 1000,
    }
    # paginate
    response = table.query(**kwargs)
    items.extend(response.get('Items', []))
    while 'LastEvaluatedKey' in response:
        kwargs['ExclusiveStartKey'] = response['LastEvaluatedKey']
        response = table.query(**kwargs)
        items.extend(response.get('Items', []))
    if not items:
        print('No items found for', PATIENT_ID)
        return
    # extract timestamps
    ts_list = []
    for it in items:
        ts = it.get('timestamp')
        if isinstance(ts, str):
            dt = parse_ts(ts)
            if dt:
                ts_list.append(dt)
    ts_list.sort()
    diffs = []
    for a,b in zip(ts_list, ts_list[1:]):
        diffs.append((b - a).total_seconds())
    print('Total items:', len(ts_list))
    print('First:', ts_list[0].isoformat())
    print('Last :', ts_list[-1].isoformat())
    if diffs:
        print('Min interval:', min(diffs))
        print('Max interval:', max(diffs))
        print('Mean interval:', statistics.mean(diffs))
        print('Median interval:', statistics.median(diffs))
        # show gaps >1.5s
        gaps = [(i+1, d) for i,d in enumerate(diffs) if d > 1.5]
        print('Gaps >1.5s count:', len(gaps))
        if gaps:
            print('First 10 gaps:')
            for idx, g in gaps[:10]:
                print(idx, ts_list[idx-1].isoformat(), '->', ts_list[idx].isoformat(), 'gap(s)=', g)
    else:
        print('Only one timestamp present')
    # show sample timestamps
    print('\nSample timestamps (first 50):')
    for t in ts_list[:50]:
        print(t.isoformat())

if __name__ == '__main__':
    main()
