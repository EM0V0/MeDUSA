"""Diagnose frontend merge behavior for medusa tremor data.

This script simulates the frontend polling merge rules and reports how many
API-returned points would be rejected by a strict 'isAfter(newestLocal - 10ms)'
check. It helps quantify whether timestamp micro-differences cause dropped points.

Usage: python tools/diagnose_merge_behavior.py
"""
from datetime import datetime, timezone, timedelta
import boto3
from boto3.dynamodb.conditions import Key

# Config
PATIENT_ID = 'usr_694c4028'
TABLE_NAME = 'medusa-tremor-analysis'
REGION = 'us-east-1'
OVERLAP_MS = 2000  # frontend overlap in ms
STRICT_MARGIN_MS = 10  # the small margin the frontend uses when deciding "new"
LIMIT = 50


def iso_from_dt(dt: datetime) -> str:
    return dt.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')


def parse_iso(s: str) -> datetime:
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    return datetime.fromisoformat(s)


def query_items_between(table, patient_id, start_iso, end_iso, limit=100):
    # Query DynamoDB table for items for patient_id between ISO timestamps (inclusive)
    resp = table.query(
        KeyConditionExpression=Key('patient_id').eq(patient_id) & Key('timestamp').between(start_iso, end_iso),
        ScanIndexForward=True,
        Limit=limit
    )
    return resp.get('Items', [])


def main():
    ddb = boto3.resource('dynamodb', region_name=REGION)
    table = ddb.Table(TABLE_NAME)

    # Determine 'now' by reading the latest item for the patient
    # We'll query a large window backwards to find the latest timestamp
    now_dt = datetime.now(timezone.utc)
    # To be safe, fetch last 200 items by querying recent time range (last hour)
    start_search = now_dt - timedelta(hours=1)
    start_iso = iso_from_dt(start_search)
    end_iso = iso_from_dt(now_dt)

    items = query_items_between(table, PATIENT_ID, start_iso, end_iso, limit=200)
    if not items:
        print('No items found for patient in last hour; aborting.')
        return

    # Items are in ascending order (we requested ScanIndexForward=True)
    # Derive latest DB timestamp
    latest_item = items[-1]
    latest_ts_str = latest_item.get('timestamp')
    latest_ts = parse_iso(latest_ts_str)

    print(f'Latest DB timestamp for {PATIENT_ID}: {latest_ts.isoformat()} (used as now)')

    # Simulate different 'newestLocal' scenarios: 0s, 0.5s, 1s, 2s, 5s behind latest
    deltas = [0.0, 0.5, 1.0, 2.0, 5.0]

    for d in deltas:
        newest_local = latest_ts - timedelta(seconds=d)
        start_time = newest_local - timedelta(milliseconds=OVERLAP_MS)
        end_time = latest_ts

        start_iso = iso_from_dt(start_time)
        end_iso = iso_from_dt(end_time)

        returned = query_items_between(table, PATIENT_ID, start_iso, end_iso, limit=LIMIT)
        # Convert timestamps
        returned_ts = []
        for it in returned:
            ts = it.get('timestamp')
            try:
                dt = parse_iso(ts)
                returned_ts.append(dt)
            except Exception:
                continue

        # Compute how many returned points would be considered 'not new' by strict check
        margin = timedelta(milliseconds=STRICT_MARGIN_MS)
        not_new = [t for t in returned_ts if not t > (newest_local - margin)]
        strictly_new = [t for t in returned_ts if t > (newest_local - margin)]

        print('\n--- Simulation: newestLocal = latest_db - {:.1f}s ---'.format(d))
        print('Simulated newestLocal:', newest_local.isoformat())
        print('Query window: {} -> {}'.format(start_iso, end_iso))
        print('Returned count:', len(returned_ts))
        print('Would be accepted as "new" (strict > newestLocal-{}ms): {}'.format(STRICT_MARGIN_MS, len(strictly_new)))
        print('Would be rejected (<= newestLocal-{}ms): {}'.format(STRICT_MARGIN_MS, len(not_new)))
        if returned_ts:
            print('Sample returned timestamps (first 10):')
            for t in returned_ts[:10]:
                mark = ''
                if t in not_new:
                    mark = '<=newestLocal (rejected)'
                print(' ', t.isoformat(), mark)

if __name__ == '__main__':
    main()
