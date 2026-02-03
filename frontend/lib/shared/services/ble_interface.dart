import 'dart:async';

/// Abstract BLE interface for cross-platform Bluetooth support
/// 
/// This interface provides a unified API for Bluetooth Low Energy operations
/// across Windows (WinBle), Mobile (FlutterBluePlus), and Web (Web Bluetooth API)
abstract class BleInterface {
  /// Initialize the BLE adapter
  Future<bool> initialize();
  
  /// Whether the adapter is initialized
  bool get isInitialized;
  
  /// Whether currently scanning
  bool get isScanning;
  
  /// Whether connected to a device
  bool get isConnected;
  
  /// Current status message
  String get status;
  
  /// Last error message
  String? get lastError;
  
  /// Stream of discovered devices
  Stream<List<UnifiedDevice>> get devicesStream;
  
  /// Stream of status updates
  Stream<String> get statusStream;
  
  /// Stream of received data from connected device
  Stream<Map<String, dynamic>> get dataStream;
  
  /// Start scanning for devices (mobile/desktop)
  /// Note: Web platform uses requestDevice() instead
  Future<void> startScan({Duration timeout});
  
  /// Stop scanning
  Future<void> stopScan();
  
  /// Request device selection (Web only - triggers browser dialog)
  /// Returns null if user cancels or no device found
  Future<UnifiedDevice?> requestDevice();
  
  /// Connect to a device
  Future<bool> connect(UnifiedDevice device);
  
  /// Disconnect from current device
  Future<void> disconnect();
  
  /// Send data to connected device
  Future<bool> sendData(Map<String, dynamic> data);
  
  /// Send command to device
  Future<bool> sendCommand(String command, [Map<String, dynamic>? parameters]);
  
  /// Dispose resources
  void dispose();
}

/// Unified device representation for cross-platform compatibility
class UnifiedDevice {
  final String name;
  final String id;
  final int? rssi;
  final dynamic platformDevice;  // Original platform-specific device object
  final DevicePlatform platform;

  UnifiedDevice({
    required this.name,
    required this.id,
    this.rssi,
    this.platformDevice,
    required this.platform,
  });

  @override
  String toString() => 'UnifiedDevice($name, $id, $platform)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Platform enumeration for device identification
enum DevicePlatform {
  windows,
  android,
  ios,
  macos,
  linux,
  web,
}

/// Extension to get current platform
extension DevicePlatformExtension on DevicePlatform {
  static DevicePlatform get current {
    // This will be determined at runtime based on kIsWeb and Platform checks
    return DevicePlatform.windows; // Default, should be overridden
  }
}
