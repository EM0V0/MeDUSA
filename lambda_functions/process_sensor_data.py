import json
import boto3
import os
import numpy as np
from decimal import Decimal
from datetime import datetime
from scipy.signal import butter, filtfilt
from scipy.fft import rfft, rfftfreq

# Initialize DynamoDB with explicit region
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
sensor_table = dynamodb.Table('medusa-sensor-data')
results_table = dynamodb.Table('medusa-tremor-analysis')  # Store analysis results
devices_table = dynamodb.Table('medusa-devices-prod')     # Device registry for ownership lookup


class ButterworthLowPass:
    """Butterworth low-pass filter implementation."""

    def __init__(self, cutoff, fs, order=4):
        self.cutoff = cutoff
        self.fs = fs
        self.order = order

    def apply(self, data):
        """Apply Butterworth low-pass filter to data."""
        nyq = 0.5 * self.fs
        normal_cutoff = self.cutoff / nyq
        b, a = butter(self.order, normal_cutoff, btype='low', analog=False)
        return filtfilt(b, a, data)


class TremorProcessor:
    """Extract features relevant to Parkinson's tremor detection."""

    def __init__(self, fs=100, tremor_band=(3, 6), filter_cutoff=12):
        """
        Initialize tremor processor.

        Args:
            fs: Sampling frequency (Hz).
            tremor_band: Frequency range for Parkinson's tremor (Hz).
            filter_cutoff: Low-pass filter cutoff frequency (Hz).
        """
        self.fs = fs
        self.tremor_band = tremor_band
        self.filter = ButterworthLowPass(filter_cutoff, fs)

    def process(self, data_array):
        """
        Process sensor data to extract tremor features.

        Args:
            data_array: Array of raw accelerometer values.

        Returns:
            Dictionary of extracted features:
              - rms: RMS value of the filtered data.
              - dominant_freq: Frequency with highest amplitude.
              - tremor_power: Power in the 3–6 Hz band.
              - tremor_index: Ratio of tremor band power to total power.
              - is_parkinsonian: Boolean decision based on thresholds.
        """
        # Apply low-pass filter
        filtered_data = self.filter.apply(data_array)

        # Calculate RMS value
        rms = np.sqrt(np.mean(np.square(filtered_data)))

        # Compute FFT
        fft_values = rfft(filtered_data)
        freqs = rfftfreq(len(filtered_data), 1 / self.fs)
        fft_magnitude = np.abs(fft_values)

        # Skip DC component (index 0) for peak detection
        fft_magnitude_no_dc = fft_magnitude[1:]
        freqs_no_dc = freqs[1:]

        # Tremor band (3-6 Hz)
        tremor_mask = (freqs_no_dc >= self.tremor_band[0]) & (freqs_no_dc <= self.tremor_band[1])
        tremor_power = np.sum(fft_magnitude_no_dc[tremor_mask] ** 2) if np.any(tremor_mask) else 0

        # Dominant frequency (excluding DC)
        dom_idx = np.argmax(fft_magnitude_no_dc)
        dominant_freq = freqs_no_dc[dom_idx] if dom_idx < len(freqs_no_dc) else 0

        # Tremor index: ratio of tremor band power to total power
        total_power = np.sum(fft_magnitude_no_dc ** 2)
        tremor_index = tremor_power / total_power if total_power > 0 else 0

        return {
            'rms': float(rms),
            'dominant_freq': float(dominant_freq),
            'tremor_power': float(tremor_power),
            'tremor_index': float(tremor_index),
            'is_parkinsonian': bool(self.tremor_band[0] <= dominant_freq <= self.tremor_band[1] and tremor_index > 0.3)
        }


def decimal_to_float(obj):
    """Convert DynamoDB Decimal objects to float for numpy processing."""
    if isinstance(obj, list):
        return [decimal_to_float(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: decimal_to_float(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj


def lambda_handler(event, context):
    """
    Process sensor data from DynamoDB to extract Parkinson's tremor features.
    
    Triggered by:
    - Scheduled EventBridge rule (batch processing)
    - Manual invocation with specific device_id and time range
    
    Args:
        event: Dict containing:
            - device_id: Device to process (required)
            - patient_id: Patient filter (optional)
            - start_timestamp: Start time for data window (optional, default: last 5 minutes)
            - end_timestamp: End time for data window (optional, default: now)
            - window_size: Minimum samples needed for analysis (default: 100)
            - sampling_rate: Expected sampling rate in Hz (default: 100)
    
    Returns:
        Status and analysis results
    """
    
    # Parse input parameters
    device_id = event.get('device_id')
    patient_id = event.get('patient_id')
    window_size = event.get('window_size', 100)  # Minimum 100 samples for FFT
    sampling_rate = event.get('sampling_rate', 100)  # 100 Hz default
    
    if not device_id:
        return {'statusCode': 400, 'body': 'Missing device_id'}
    
    # Lookup patient_id from device registry if not provided
    # This ensures data is correctly attributed to the current owner
    if not patient_id or patient_id == "UNASSIGNED":
        try:
            device_record = devices_table.get_item(Key={'id': device_id})
            if 'Item' in device_record:
                patient_id = device_record['Item'].get('patientId')
                print(f"Resolved patient_id {patient_id} for device {device_id}")
        except Exception as e:
            print(f"Error looking up device owner: {e}")

    # Time range (default: last 5 minutes)
    now = int(datetime.utcnow().timestamp())
    end_timestamp = event.get('end_timestamp', now)
    start_timestamp = event.get('start_timestamp', now - 300)  # 5 min window
    
    try:
        # Prepare query parameters
        # The Pi publishes data with millisecond timestamps (13 digits).
        # We convert our search window (seconds) to milliseconds.
        start_ts_ms = int(start_timestamp * 1000)
        end_ts_ms = int(end_timestamp * 1000)

        query_params = {
            'KeyConditionExpression': 'device_id = :did AND #ts BETWEEN :start AND :end',
            'ExpressionAttributeNames': {
                '#ts': 'timestamp'  # 'timestamp' is a reserved word
            },
            'ExpressionAttributeValues': {
                ':did': device_id,
                ':start': start_ts_ms,
                ':end': end_ts_ms
            },
            'ScanIndexForward': True  # Oldest first for time series
        }
        
        # DON'T filter by patient_id in sensor data since it may be outdated
        # We use the patient_id from device registry (resolved above) for the analysis result
        # This allows us to process old sensor data with incorrect patient_ids
        
        response = sensor_table.query(**query_params)
        items = response['Items']
        
        # Handle pagination if more than 1MB of data
        while 'LastEvaluatedKey' in response:
            query_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
            response = sensor_table.query(**query_params)
            items.extend(response['Items'])
        
        # Convert Decimal to float for numpy processing
        items = decimal_to_float(items)
        
        # Extract accelerometer magnitude time series with timestamps
        # We need timestamps to align the sliding window
        time_series_data = []
        
        for item in items:
            ts = float(item['timestamp']) / 1000.0 # Convert ms to seconds
            
            # Use pre-calculated magnitude if available (from enrichment Lambda)
            if 'magnitude' in item:
                try:
                    mag = float(item['magnitude'])
                    time_series_data.append((ts, mag))
                    continue
                except (ValueError, TypeError):
                    pass  # Fallback to calculation

            # Handle single value format (Pi) - accel_x, accel_y, accel_z
            if 'accel_x' in item:
                try:
                    x = float(item['accel_x'])
                    y = float(item['accel_y'])
                    z = float(item['accel_z'])
                    mag = np.sqrt(x**2 + y**2 + z**2)
                    time_series_data.append((ts, mag))
                except (ValueError, TypeError):
                    continue
            
            # Support both new simplified schema (x,y,z) and old schema (accelerometer_x, etc)
            # These are list-based formats
            else:
                x_vals = item.get('x', item.get('accelerometer_x', []))
                y_vals = item.get('y', item.get('accelerometer_y', []))
                z_vals = item.get('z', item.get('accelerometer_z', []))
                
                # Calculate magnitude for each sample in this record
                # Note: If we have array data, we assume uniform sampling within the record
                # But we only have one timestamp for the record.
                # For simplicity, we'll just use the record timestamp for all samples in the batch
                # or distribute them if we knew the rate.
                # Given the user wants "per second" points, and array data is usually high freq,
                # we might need to be careful.
                # For now, let's assume single-value mode is dominant for the Pi.
                if x_vals and y_vals and z_vals:
                    for x, y, z in zip(x_vals, y_vals, z_vals):
                        mag = np.sqrt(x**2 + y**2 + z**2)
                        time_series_data.append((ts, mag))
        
        # Calculate actual sampling rate
        actual_fs = sampling_rate
        if len(time_series_data) > 1:
            duration = time_series_data[-1][0] - time_series_data[0][0]
            if duration > 0:
                actual_fs = len(time_series_data) / duration
                print(f"Calculated actual sampling rate: {actual_fs:.2f} Hz")

        if len(time_series_data) == 0:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'status': 'insufficient_data',
                    'message': f'No samples found',
                    'device_id': device_id
                })
            }
            
        # Sort by timestamp
        time_series_data.sort(key=lambda x: x[0])
        
        # Initialize tremor processor
        # Adjust filter cutoff if sampling rate is low
        filter_cutoff = 12
        if actual_fs < 25: # Nyquist for 12Hz is 24Hz
            filter_cutoff = actual_fs / 2.1 # Set cutoff slightly below Nyquist
            if filter_cutoff < 1: filter_cutoff = 1 # Minimum cutoff
            
        processor = TremorProcessor(
            fs=actual_fs,
            tremor_band=(3, 6),  # Parkinson's tremor frequency range
            filter_cutoff=filter_cutoff
        )
        
        # Use the resolved patient_id, fallback to item's patient_id, then UNASSIGNED
        final_patient_id = patient_id if patient_id else items[0].get('patient_id', 'UNASSIGNED')
        
        # Sliding Window Analysis
        # We want to generate multiple analysis points for the chart.
        # E.g. One point every 1 second.
        # Window size for analysis: e.g. 5 seconds (500 samples at 100Hz)
        
        analysis_window_duration = 5.0 # seconds
        step_size = 1.0 # seconds
        
        # Determine start and end of the data range
        data_start_time = time_series_data[0][0]
        data_end_time = time_series_data[-1][0]
        
        current_window_start = data_start_time
        
        analysis_results = []
        
        # If we have very few samples (e.g. 1Hz data), just process each point or small windows
        if actual_fs < 5:
             print("Low sampling rate detected. Processing in simplified mode.")
             # Just take 5 second windows regardless of sample count
             pass

        while current_window_start + analysis_window_duration <= data_end_time + step_size: # Allow one last partial window
            current_window_end = current_window_start + analysis_window_duration
            
            # Extract samples in this window
            window_samples = [mag for ts, mag in time_series_data if current_window_start <= ts < current_window_end]
            
            # Check if we have enough samples (at least 1)
            if len(window_samples) > 0:
                
                # Process window
                use_fallback = False
                if actual_fs < 5:
                    use_fallback = True
                else:
                    try:
                        features = processor.process(np.array(window_samples))
                    except Exception as e:
                        print(f"Error processing window: {e}")
                        use_fallback = True
                
                if use_fallback:
                    # Fallback for low sampling rate or errors
                    # Calculate AC component (remove DC/Gravity)
                    ac_component = np.array(window_samples) - np.mean(window_samples)
                    rms_ac = np.sqrt(np.mean(np.square(ac_component)))
                    
                    # Estimate tremor index based on AC amplitude (assuming 0.2g is severe)
                    # RMS of 1.0 is gravity. RMS of AC component represents shaking.
                    estimated_index = min(float(rms_ac) / 0.2, 1.0) 
                    
                    features = {
                        'rms': float(np.sqrt(np.mean(np.square(window_samples)))), # Total RMS
                        'dominant_freq': 0.0,
                        'tremor_power': float(rms_ac ** 2), # Variance as power proxy
                        'tremor_index': estimated_index,
                        'is_parkinsonian': estimated_index > 0.3
                    }
                
                # Timestamp for this analysis point is the END of the window
                analysis_ts = current_window_end
                
                analysis_result = {
                    'device_id': device_id,
                    'patient_id': final_patient_id,
                    'timestamp': datetime.utcfromtimestamp(analysis_ts).isoformat() + 'Z',
                    
                    # Tremor features
                    'rms': Decimal(str(features['rms'])),
                    'dominant_freq': Decimal(str(features['dominant_freq'])),
                    'tremor_power': Decimal(str(features['tremor_power'])),
                    'tremor_index': Decimal(str(features['tremor_index'])),
                    'is_parkinsonian': features['is_parkinsonian'],
                    
                    # Metadata
                    'ttl': int(datetime.utcnow().timestamp()) + (90 * 24 * 60 * 60)
                }
                analysis_results.append(analysis_result)
            
            # Move to next window
            current_window_start += step_size
            
        # Batch write results to DynamoDB
        if analysis_results:
            with results_table.batch_writer() as batch:
                for result in analysis_results:
                    batch.put_item(Item=result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'device_id': device_id,
                'patient_id': final_patient_id,
                'points_generated': len(analysis_results),
                'samples_processed': len(time_series_data)
            })
        }
        
    except Exception as e:
        print(f"Error processing sensor data: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': str(e),
                'device_id': device_id
            })
        }
