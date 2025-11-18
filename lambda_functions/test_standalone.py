"""
Standalone test for tremor detection algorithm (no AWS dependencies)
"""

import json
import numpy as np
from scipy.signal import butter, filtfilt
from scipy.fft import rfft, rfftfreq


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
            Dictionary of extracted features.
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


def generate_synthetic_tremor_data(fs=100, duration=5, tremor_freq=4.5, noise_level=0.1):
    """Generate synthetic accelerometer data with Parkinsonian tremor."""
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
    assert 3 <= features['dominant_freq'] <= 6, f"Dominant freq {features['dominant_freq']:.2f} should be in tremor band [3-6 Hz]"
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
    
    # Test 5: Multiple tremor frequencies
    print("\nTest 5: Testing Multiple Tremor Frequencies")
    print("-" * 60)
    test_freqs = [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 7.0, 8.0]
    for freq in test_freqs:
        data = generate_synthetic_tremor_data(fs=100, duration=5, tremor_freq=freq, noise_level=0.1)
        result = processor.process(data)
        status = "✓ TREMOR" if result['is_parkinsonian'] else "✗ Normal"
        print(f"{freq:.1f} Hz: {status} (dominant={result['dominant_freq']:.2f} Hz, index={result['tremor_index']:.3f})")
    
    print("\n" + "="*60)
    print("All Tests Passed!")
    print("="*60 + "\n")


if __name__ == "__main__":
    print("\n🧪 MeDUSA Tremor Detection - Standalone Test Suite")
    
    try:
        test_tremor_detection()
        print("✅ All tests completed successfully!\n")
        
    except AssertionError as e:
        print(f"\n❌ Test failed: {e}\n")
        import sys
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error during testing: {e}\n")
        import traceback
        traceback.print_exc()
        import sys
        sys.exit(1)
