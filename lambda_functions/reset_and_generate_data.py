import boto3
import time
import json
import numpy as np
from datetime import datetime, timedelta
from decimal import Decimal
import sys
import os

# Add current directory to path to import local modules if needed
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Import the processing function
try:
    from process_sensor_data import lambda_handler as process_handler
except ImportError:
    print("Could not import process_sensor_data. Make sure you are running this from the lambda_functions directory.")
    sys.exit(1)

# Configuration
PATIENT_ID = 'usr_694c4028'
DEVICE_ID = 'DEV-002'
REGION = 'us-east-1'

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name=REGION)
sensor_table = dynamodb.Table('medusa-sensor-data')
analysis_table = dynamodb.Table('medusa-tremor-analysis')
mapping_table = dynamodb.Table('medusa-device-patient-mapping')

def clear_table(table):
    """Delete all items from a table."""
    print(f"Clearing table {table.name}...")
    
    # Handle pagination
    scan = table.scan()
    items = scan['Items']
    while 'LastEvaluatedKey' in scan:
        scan = table.scan(ExclusiveStartKey=scan['LastEvaluatedKey'])
        items.extend(scan['Items'])
        
    print(f"Found {len(items)} items to delete.")
    
    with table.batch_writer() as batch:
        for each in items:
            # Build the key for deletion
            key = {}
            for k in table.key_schema:
                key[k['AttributeName']] = each[k['AttributeName']]
            batch.delete_item(Key=key)
    print(f"Table {table.name} cleared.")

def generate_sine_wave(freq, sampling_rate, duration_sec, amplitude=1.0):
    t = np.linspace(0, duration_sec, int(sampling_rate * duration_sec), endpoint=False)
    return amplitude * np.sin(2 * np.pi * freq * t)

def generate_raw_data(end_time):
    """Generate raw sensor data for the last 24 hours."""
    print("Generating raw sensor data...")
    
    start_time = end_time - timedelta(hours=24)
    
    current_time = start_time
    items_written = 0
    
    # We will generate data points every 5 minutes to cover 24 hours without too much data
    # But for the last 1 hour, we generate every 1 minute for high resolution
    
    while current_time <= end_time:
        # Determine interval based on how recent the data is
        time_diff = end_time - current_time
        if time_diff < timedelta(hours=1):
            interval = timedelta(minutes=1)
        else:
            interval = timedelta(minutes=15) # Sparse data for older history
            
        # Simulate tremor
        # 20% chance of Parkinsonian tremor (3-6Hz)
        is_parkinsonian = np.random.random() < 0.2
        
        if is_parkinsonian:
            freq = np.random.uniform(3.5, 5.5)
            amp = np.random.uniform(0.5, 0.9)
        else:
            freq = np.random.uniform(1.0, 2.0) # Normal movement
            amp = np.random.uniform(0.1, 0.2)
            
        # Generate 1 second of data at 100Hz
        sampling_rate = 100
        duration = 1.0
        
        x_data = generate_sine_wave(freq, sampling_rate, duration, amp) + np.random.normal(0, 0.05, 100)
        y_data = generate_sine_wave(freq, sampling_rate, duration, amp) + np.random.normal(0, 0.05, 100)
        z_data = generate_sine_wave(freq, sampling_rate, duration, amp) + np.random.normal(0, 0.05, 100)
        
        # Write individual items (Pi format)
        # Use batch writer for efficiency
        with sensor_table.batch_writer() as batch:
            base_ts_ms = int(current_time.timestamp() * 1000)
            
            for i in range(len(x_data)):
                # Calculate timestamp for this sample (ms)
                ts_offset_ms = int(i * (1000 / sampling_rate))
                item_ts = base_ts_ms + ts_offset_ms
                
                # Calculate magnitude
                mag = np.sqrt(x_data[i]**2 + y_data[i]**2 + z_data[i]**2)
                
                item = {
                    'device_id': DEVICE_ID,
                    'timestamp': item_ts,
                    'patient_id': PATIENT_ID,
                    'accel_x': Decimal(str(round(x_data[i], 4))),
                    'accel_y': Decimal(str(round(y_data[i], 4))),
                    'accel_z': Decimal(str(round(z_data[i], 4))),
                    'magnitude': Decimal(str(round(mag, 4)))
                }
                batch.put_item(Item=item)
                items_written += 1
        
        print(f"Generated raw data at {current_time.strftime('%H:%M')} ({'Parkinsonian' if is_parkinsonian else 'Normal'})", end='\r')
        
        current_time += interval
        
    print(f"\nGenerated {items_written} raw data records.")

def trigger_processing(end_time):
    """Trigger the processing lambda for the generated data."""
    print("Triggering processing...")
    
    start_time = end_time - timedelta(hours=24)
    
    # Process in 1-hour chunks to avoid timeouts or memory issues
    current_chunk_start = start_time
    
    while current_chunk_start < end_time:
        current_chunk_end = min(current_chunk_start + timedelta(hours=1), end_time)
        
        print(f"Processing chunk: {current_chunk_start.strftime('%H:%M')} to {current_chunk_end.strftime('%H:%M')}")
        
        event = {
            'device_id': DEVICE_ID,
            'patient_id': PATIENT_ID,
            'start_timestamp': int(current_chunk_start.timestamp()),
            'end_timestamp': int(current_chunk_end.timestamp()),
            'window_size': 10, # Lower window size for test data
            'sampling_rate': 100
        }
        
        try:
            # We call the handler directly. 
            # Note: process_sensor_data.py expects 'start_timestamp' and 'end_timestamp' 
            # to be used for querying DynamoDB.
            
            # However, looking at process_sensor_data.py, it calculates start/end if not provided.
            # But we provide them.
            
            # IMPORTANT: The process_sensor_data.py logic might process ALL data in the window into ONE analysis point
            # or multiple. Let's check the logic.
            # It seems to process the whole window into ONE result.
            # "Process data and extract features... results_table.put_item"
            
            # If we want multiple points on the chart, we need to call this multiple times with smaller windows.
            # The chart needs points.
            
            # Let's iterate through our data points and process them individually or in small batches.
            # Since we generated data every 15 mins or 1 min, we should process each "packet" as a point.
            
            # Actually, let's look at how we generated data. We generated discrete items.
            # If we pass a large window, the lambda queries ALL items in that window.
            # And then: "magnitude_data = np.array(magnitude_data)" -> concatenates all.
            # Then "processor.process(magnitude_data)" -> ONE result.
            
            # So yes, to get a chart with many points, we need to invoke the processor many times,
            # once for each small time window corresponding to our data points.
            pass
        except Exception as e:
            print(f"Error processing chunk: {e}")
            
        current_chunk_start += timedelta(hours=1)

    # Re-implementing the loop to process per-point
    print("\nReprocessing point-by-point for chart resolution...")
    current_time = start_time
    processed_count = 0
    
    while current_time <= end_time:
        # Determine interval (same as generation)
        time_diff = end_time - current_time
        if time_diff < timedelta(hours=1):
            interval = timedelta(minutes=1)
        else:
            interval = timedelta(minutes=15)
            
        # Define a small window around this point
        # The raw data item has a specific timestamp.
        # We need to capture that item.
        
        # Window: [current_time - 5s, current_time + 5s]
        # Widen window to ensure we capture all data points despite timestamp rounding
        
        win_start = int((current_time - timedelta(seconds=5)).timestamp())
        win_end = int((current_time + timedelta(seconds=5)).timestamp())
        
        event = {
            'device_id': DEVICE_ID,
            'patient_id': PATIENT_ID,
            'start_timestamp': win_start,
            'end_timestamp': win_end,
            'window_size': 10, # We generated 100 samples, so 10 is fine
            'sampling_rate': 100
        }
        
        try:
            result = process_handler(event, None)
            
            # Check result body for status
            if isinstance(result, dict) and 'body' in result:
                body = json.loads(result['body'])
                if body.get('status') == 'success':
                    processed_count += 1
                    print(f"Processed point at {current_time.strftime('%H:%M')}", end='\r')
                else:
                    print(f"\nFailed to process at {current_time.strftime('%H:%M')}: {body}")
            else:
                print(f"\nUnexpected result format: {result}")
                
        except Exception as e:
            print(f"\nException processing point: {e}")
            # Ignore insufficient data errors for gaps
            pass
            
        current_time += interval
        
    print(f"\nSuccessfully processed {processed_count} analysis points.")

def setup_device_mapping():
    """Setup device-patient mapping."""
    print("Setting up device-patient mapping...")
    
    try:
        item = {
            'device_id': DEVICE_ID,
            'assignment_timestamp': int(datetime.utcnow().timestamp()),
            'patient_id': PATIENT_ID,
            'patient_name': 'Test Patient',
            'status': 'active',
            'assigned_by': 'admin',
            'notes': 'Generated by reset_and_generate_data.py'
        }
        
        mapping_table.put_item(Item=item)
        print(f"Mapped {DEVICE_ID} to {PATIENT_ID}")
    except Exception as e:
        print(f"Warning: Could not update mapping table: {e}")

if __name__ == '__main__':
    print("Starting Reset and Generate Data...")
    clear_table(sensor_table)
    clear_table(analysis_table)
    
    # Setup device-patient mapping
    setup_device_mapping()
    
    # Use a fixed end time for both generation and processing to ensure alignment
    fixed_end_time = datetime.utcnow()
    
    generate_raw_data(fixed_end_time)
    trigger_processing(fixed_end_time)
    print("\nDone!")
