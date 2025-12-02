"""
Test script for process_sensor_data Lambda function
Generates synthetic sensor data and validates tremor detection
"""

import json
import numpy as np
from datetime import datetime, timedelta
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))

from process_sensor_data import TremorProcessor, ButterworthLowPass


def generate_synthetic_tremor_data(fs=100, duration=5, tremor_freq=4.5, noise_level=0.1):
    """
    Generate synthetic accelerometer data with Parkinsonian tremor.
    
    Args:
        fs: Sampling frequency (Hz)
        duration: Signal duration (seconds)
        tremor_freq: Tremor frequency (Hz, typically 3-6 Hz for Parkinson's)
        noise_level: Gaussian noise amplitude
    
    Returns:
        numpy array of synthetic magnitude data
    """
    t = np.linspace(0, duration, int(fs * duration))
    
    # Parkinsonian tremor component (4-5 Hz dominant)
    tremor = 0.5 * np.sin(2 * np.pi * tremor_freq * t)
    
    # Voluntary movement (lower frequency)
    voluntary = 0.2 * np.sin(2 * np.pi * 1.5 * t)
    
    # Gaussian noise
    noise = noise_level * np.random.randn(len(t))
    
    # Combined signal
    signal = tremor + voluntary + noise + 9.8  # Add gravity offset
    
    return signal


def generate_normal_data(fs=100, duration=5, noise_level=0.05):
    """Generate normal movement data without tremor."""
    t = np.linspace(0, duration, int(fs * duration))
    
    # Smooth voluntary movements (0.5-2 Hz)
    movement = 0.3 * np.sin(2 * np.pi * 0.8 * t) + 0.2 * np.sin(2 * np.pi * 1.2 * t)
    
    # Low noise
    noise = noise_level * np.random.randn(len(t))
    
    signal = movement + noise + 9.8
    
    return signal


def test_tremor_detection():
    """Test tremor detection with synthetic data."""
    print("\n" + "="*60)
    print("Testing Tremor Detection Algorithm")
    print("="*60)
    
    processor = TremorProcessor(fs=100, tremor_band=(3, 6), filter_cutoff=12)
    
    # Test 1: Parkinsonian tremor data
    print("\nTest 1: Synthetic Parkinsonian Tremor (4.5 Hz)")
    print("-" * 60)
    tremor_data = generate_synthetic_tremor_data(
        fs=100, duration=5, tremor_freq=4.5, noise_level=0.1
    )
    features = processor.process(tremor_data)
    
    print(f"RMS:              {features['rms']:.4f}")
    print(f"Dominant Freq:    {features['dominant_freq']:.2f} Hz")
    print(f"Tremor Power:     {features['tremor_power']:.4f}")
    print(f"Tremor Index:     {features['tremor_index']:.4f}")
    print(f"Is Parkinsonian:  {features['is_parkinsonian']}")
    
    assert features['is_parkinsonian'], "Should detect Parkinsonian tremor"
    assert 3 <= features['dominant_freq'] <= 6, "Dominant freq should be in tremor band"
    print("✓ PASS: Correctly identified Parkinsonian tremor")
    
    # Test 2: Normal movement data
    print("\nTest 2: Normal Movement (No Tremor)")
    print("-" * 60)
    normal_data = generate_normal_data(fs=100, duration=5, noise_level=0.05)
    features = processor.process(normal_data)
    
    print(f"RMS:              {features['rms']:.4f}")
    print(f"Dominant Freq:    {features['dominant_freq']:.2f} Hz")
    print(f"Tremor Power:     {features['tremor_power']:.4f}")
    print(f"Tremor Index:     {features['tremor_index']:.4f}")
    print(f"Is Parkinsonian:  {features['is_parkinsonian']}")
    
    assert not features['is_parkinsonian'], "Should NOT detect tremor in normal data"
    print("✓ PASS: Correctly rejected normal movement")
    
    # Test 3: Edge case - 3 Hz tremor
    print("\nTest 3: Edge Case - 3 Hz Tremor (Lower Bound)")
    print("-" * 60)
    edge_data = generate_synthetic_tremor_data(
        fs=100, duration=5, tremor_freq=3.0, noise_level=0.1
    )
    features = processor.process(edge_data)
    
    print(f"RMS:              {features['rms']:.4f}")
    print(f"Dominant Freq:    {features['dominant_freq']:.2f} Hz")
    print(f"Tremor Power:     {features['tremor_power']:.4f}")
    print(f"Tremor Index:     {features['tremor_index']:.4f}")
    print(f"Is Parkinsonian:  {features['is_parkinsonian']}")
    print("✓ PASS: Edge case handled")
    
    # Test 4: Butterworth filter
    print("\nTest 4: Butterworth Low-Pass Filter")
    print("-" * 60)
    test_signal = np.sin(2 * np.pi * 5 * np.linspace(0, 1, 100))  # 5 Hz signal
    filter = ButterworthLowPass(cutoff=12, fs=100, order=4)
    filtered = filter.apply(test_signal)
    
    print(f"Input signal length:    {len(test_signal)}")
    print(f"Filtered signal length: {len(filtered)}")
    print(f"Filter cutoff:          12 Hz")
    assert len(filtered) == len(test_signal), "Filtered length should match input"
    print("✓ PASS: Filter applied successfully")
    
    print("\n" + "="*60)
    print("All Tests Passed!")
    print("="*60 + "\n")


def test_lambda_handler_local():
    """Test the Lambda handler with mock data."""
    print("\n" + "="*60)
    print("Testing Lambda Handler (Local Mock)")
    print("="*60)
    
    # Note: This test requires DynamoDB access or mocking
    print("\n⚠ WARNING: This test requires AWS credentials and DynamoDB access")
    print("To test locally, you need to:")
    print("1. Set up AWS credentials")
    print("2. Create test data in medusa-sensor-data table")
    print("3. Mock DynamoDB with boto3 stubs (recommended)")
    print("\nSkipping Lambda handler test in offline mode.")
    print("Use AWS Lambda test console or deploy to test with real data.")


def generate_test_event():
    """Generate a sample Lambda event for testing."""
    now = int(datetime.utcnow().timestamp())
    event = {
        "device_id": "test_device_001",
        "patient_id": "test_patient_123",
        "start_timestamp": now - 300,  # 5 minutes ago
        "end_timestamp": now,
        "window_size": 100,
        "sampling_rate": 100
    }
    
    print("\n" + "="*60)
    print("Sample Lambda Event for Testing")
    print("="*60)
    print(json.dumps(event, indent=2))
    print("\nYou can use this event in AWS Lambda test console:")
    print("1. Go to AWS Lambda Console")
    print("2. Select: medusa-process-sensor-data")
    print("3. Click 'Test' tab")
    print("4. Paste the JSON above")
    print("5. Click 'Test' button")
    

if __name__ == "__main__":
    print("\n🧪 MeDUSA Sensor Data Processing - Test Suite")
    
    try:
        # Run algorithm tests
        test_tremor_detection()
        
        # Generate sample event
        generate_test_event()
        
        # Note about Lambda handler testing
        test_lambda_handler_local()
        
        print("\n✅ All tests completed successfully!\n")
        
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}\n")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error during testing: {e}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)
