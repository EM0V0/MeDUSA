import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:win_ble/win_ble.dart';
import 'windows_pairing_service.dart';

// Export win_ble types for external use
export 'package:win_ble/win_ble.dart' show BleDevice;

/// Pure WinBle implementation for Windows BLE operations
/// 
/// This service uses win_ble package for all BLE operations on Windows
/// and integrates with WindowsPairingService for LESC pairing support.
class WinBleService extends ChangeNotifier {
  // Singleton instance
  static final WinBleService _instance = WinBleService._internal();
  factory WinBleService() => _instance;
  WinBleService._internal();

  // State
  bool _isScanning = false;
  bool _isInitialized = false;
  String _status = 'Idle';
  String? _connectedDeviceAddress;
  
  final List<BleDevice> _discoveredDevices = [];
  final StreamController<List<BleDevice>> _devicesController =
      StreamController<List<BleDevice>>.broadcast();

  // Getters
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  String get status => _status;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  Stream<List<BleDevice>> get devicesStream => _devicesController.stream;
  List<BleDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Initialize WinBle
  Future<bool> initialize() async {
    if (!Platform.isWindows) {
      debugPrint('[WinBle] ⚠️ Not on Windows platform');
      return false;
    }

    if (_isInitialized) {
      debugPrint('[WinBle] Already initialized');
      return true;
    }

    try {
      debugPrint('[WinBle] 🔧 Initializing...');
      
      // Initialize WinBle
      await WinBle.initialize(
        serverPath: '',  // Use default
        enableLog: true,
      );

      // Setup scan result listener
      WinBle.scanStream.listen((device) {
        _handleScanResult(device);
      });

      _isInitialized = true;
      _setStatus('Initialized');
      debugPrint('[WinBle] ✅ Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[WinBle] ❌ Initialization failed: $e');
      _setStatus('Initialization failed');
      return false;
    }
  }

  /// Start scanning for BLE devices
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
    String? nameFilter,
  }) async {
    if (_isScanning) {
      debugPrint('[WinBle] Already scanning');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isScanning = true;
      _discoveredDevices.clear();
      _devicesController.add([]);
      
      _setStatus('Scanning for devices...');
      debugPrint('[WinBle] 📡 Starting scan...');

      // Start WinBle scan (returns void, not Future)
      WinBle.startScanning();

      // Auto-stop after timeout
      Timer(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });

    } catch (e) {
      debugPrint('[WinBle] ❌ Scan start failed: $e');
      _isScanning = false;
      _setStatus('Scan failed');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      WinBle.stopScanning(); // Returns void, not Future
      _isScanning = false;
      _setStatus('Scan stopped');
      debugPrint('[WinBle] ⏹️ Scan stopped - found ${_discoveredDevices.length} device(s)');
    } catch (e) {
      debugPrint('[WinBle] Error stopping scan: $e');
    }
  }

  /// Handle scan result from WinBle
  void _handleScanResult(BleDevice device) {
    // Apply filter if needed
    final deviceName = device.name.toLowerCase();
    if (deviceName.isEmpty || !deviceName.contains('medusa')) {
      return; // Skip devices that don't match
    }

    // Check if already discovered
    if (_discoveredDevices.any((d) => d.address == device.address)) {
      return; // Already in list
    }

    debugPrint('[WinBle] ✓ Found: ${device.name} (${device.address})');
    
    _discoveredDevices.add(device);
    _devicesController.add(List.from(_discoveredDevices));
    _setStatus('Found ${_discoveredDevices.length} device(s)');
  }

  /// Connect to a BLE device
  Future<bool> connect(String deviceAddress) async {
    try {
      debugPrint('[WinBle] 🔌 Connecting to $deviceAddress...');
      _setStatus('Connecting...');

      await WinBle.connect(deviceAddress);
      
      _connectedDeviceAddress = deviceAddress;
      _setStatus('Connected');
      debugPrint('[WinBle] ✅ Connected');
      
      return true;
    } catch (e) {
      debugPrint('[WinBle] ❌ Connection failed: $e');
      _setStatus('Connection failed');
      return false;
    }
  }

  /// Disconnect from device
  Future<void> disconnect(String deviceAddress) async {
    try {
      debugPrint('[WinBle] 🔌 Disconnecting from $deviceAddress...');
      
      await WinBle.disconnect(deviceAddress);
      
      if (_connectedDeviceAddress == deviceAddress) {
        _connectedDeviceAddress = null;
      }
      
      _setStatus('Disconnected');
      debugPrint('[WinBle] ✅ Disconnected');
    } catch (e) {
      debugPrint('[WinBle] Error disconnecting: $e');
    }
  }

  /// Pair with a device using Windows native pairing
  Future<bool> pairDevice(String deviceAddress) async {
    try {
      debugPrint('[WinBle] 🔐 Initiating pairing for $deviceAddress');
      
      // Check if already paired
      final isPaired = await WindowsPairingService.isDevicePaired(deviceAddress);
      if (isPaired) {
        debugPrint('[WinBle] ✅ Device already paired');
        return true;
      }

      _setStatus('Pairing...');
      
      // Use Windows native pairing dialog (ProvidePin mode)
      final success = await WindowsPairingService.pairDevice(
        deviceAddress: deviceAddress,
        requireAuthentication: true, // LESC with EncryptionAndAuthentication
      );

      if (success) {
        debugPrint('[WinBle] ✅ Pairing successful');
        _setStatus('Paired');
        return true;
      } else {
        debugPrint('[WinBle] ❌ Pairing failed');
        _setStatus('Pairing failed');
        return false;
      }
    } catch (e) {
      debugPrint('[WinBle] ❌ Pairing error: $e');
      _setStatus('Pairing error');
      return false;
    }
  }

  /// Discover services and characteristics
  Future<List<dynamic>> discoverServices(String deviceAddress) async {
    try {
      debugPrint('[WinBle] 🔍 Discovering services for $deviceAddress...');
      
      final services = await WinBle.discoverServices(deviceAddress);
      
      debugPrint('[WinBle] ✅ Discovered ${services.length} service(s)');
      return services;
    } catch (e) {
      debugPrint('[WinBle] ❌ Service discovery failed: $e');
      return [];
    }
  }

  /// Read a characteristic
  Future<List<int>?> readCharacteristic({
    required String deviceAddress,
    required String serviceId,
    required String characteristicId,
  }) async {
    try {
      debugPrint('[WinBle] 📖 Reading characteristic $characteristicId...');
      
      final data = await WinBle.read(
        address: deviceAddress,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );
      
      debugPrint('[WinBle] ✅ Read ${data.length} bytes');
      return data;
    } catch (e) {
      debugPrint('[WinBle] ❌ Read failed: $e');
      return null;
    }
  }

  /// Write to a characteristic
  Future<bool> writeCharacteristic({
    required String deviceAddress,
    required String serviceId,
    required String characteristicId,
    required List<int> data,
    bool writeWithResponse = true,
  }) async {
    try {
      debugPrint('[WinBle] ✍️ Writing ${data.length} bytes to $characteristicId...');
      
      await WinBle.write(
        address: deviceAddress,
        service: serviceId,
        characteristic: characteristicId,
        data: Uint8List.fromList(data),
        writeWithResponse: writeWithResponse,
      );
      
      debugPrint('[WinBle] ✅ Write successful');
      return true;
    } catch (e) {
      debugPrint('[WinBle] ❌ Write failed: $e');
      return false;
    }
  }

  /// Subscribe to characteristic notifications
  Future<void> subscribeToCharacteristic({
    required String deviceAddress,
    required String serviceId,
    required String characteristicId,
    required void Function(List<int> value) onValueReceived,
  }) async {
    try {
      debugPrint('[WinBle] 🔔 Subscribing to notifications for $characteristicId...');
      
      await WinBle.subscribeToCharacteristic(
        address: deviceAddress,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );

      // Listen to value stream
      WinBle.characteristicValueStream.listen((event) {
        if (event.address == deviceAddress &&
            event.characteristicId == characteristicId) {
          onValueReceived(event.value);
        }
      });
      
      debugPrint('[WinBle] ✅ Subscribed to notifications');
    } catch (e) {
      debugPrint('[WinBle] ❌ Subscribe failed: $e');
    }
  }

  /// Unsubscribe from characteristic notifications
  Future<void> unsubscribeFromCharacteristic({
    required String deviceAddress,
    required String serviceId,
    required String characteristicId,
  }) async {
    try {
      await WinBle.unSubscribeFromCharacteristic(
        address: deviceAddress,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );
      
      debugPrint('[WinBle] ✅ Unsubscribed from notifications');
    } catch (e) {
      debugPrint('[WinBle] Error unsubscribing: $e');
    }
  }

  void _setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _devicesController.close();
    super.dispose();
  }
}

