import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';
import 'package:flutter_web_bluetooth/js_web_bluetooth.dart';

/// Web Bluetooth Service for web platform
/// 
/// Uses the Web Bluetooth API through flutter_web_bluetooth package
/// to provide BLE functionality in web browsers (Chrome, Edge, Opera)
class WebBleService extends ChangeNotifier {
  // Singleton instance
  static final WebBleService _instance = WebBleService._internal();
  factory WebBleService() => _instance;
  WebBleService._internal();

  // Web Bluetooth instance
  final FlutterWebBluetoothInterface _webBluetooth = FlutterWebBluetooth.instance;

  // State
  bool _isScanning = false;
  bool _isInitialized = false;
  bool _isConnected = false;
  String _status = 'Idle';
  String? _lastError;

  // Connected device
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  // Service and characteristic UUIDs (same as other platforms)
  static const String serviceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String writeCharacteristicUuid = "12345678-1234-1234-1234-123456789abd";
  static const String notifyCharacteristicUuid = "12345678-1234-1234-1234-123456789abe";

  // Discovered devices
  final List<WebBleDevice> _discoveredDevices = [];
  final StreamController<List<WebBleDevice>> _devicesController =
      StreamController<List<WebBleDevice>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Subscriptions
  StreamSubscription<bool>? _availabilitySubscription;
  StreamSubscription<ByteData>? _notifySubscription;

  // Getters
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  String get status => _status;
  String? get lastError => _lastError;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  Stream<List<WebBleDevice>> get devicesStream => _devicesController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  List<WebBleDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Check if Web Bluetooth is supported in current browser
  bool get isBluetoothApiSupported => _webBluetooth.isBluetoothApiSupported;

  /// Initialize the Web Bluetooth service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('[WebBle] Already initialized');
      return true;
    }

    try {
      debugPrint('[WebBle] 🔧 Initializing...');

      // Check if browser supports Web Bluetooth
      if (!_webBluetooth.isBluetoothApiSupported) {
        _setError('Web Bluetooth API is not supported in this browser');
        return false;
      }

      // Listen to Bluetooth availability changes
      _availabilitySubscription = _webBluetooth.isAvailable.listen(
        (available) {
          debugPrint('[WebBle] Bluetooth available: $available');
          if (!available) {
            _setStatus('Bluetooth not available');
          }
        },
        onError: (e) {
          debugPrint('[WebBle] Availability stream error: $e');
        },
      );

      _isInitialized = true;
      _setStatus('Initialized (Web Bluetooth)');
      debugPrint('[WebBle] ✅ Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[WebBle] ❌ Initialization failed: $e');
      _setError('Initialization failed: $e');
      return false;
    }
  }

  /// Request device (triggers browser's device picker dialog)
  /// 
  /// Web Bluetooth requires user interaction to trigger device selection.
  /// This method will show the browser's native Bluetooth device picker.
  Future<WebBleDevice?> requestDevice() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isScanning = true;
      _setStatus('Requesting device...');
      notifyListeners();

      debugPrint('[WebBle] 📡 Requesting device with services: $serviceUuid');

      // Build request options
      // We request devices that have our service UUID
      final requestOptions = RequestOptionsBuilder(
        [
          // Filter by name containing "MeDUSA" (case-insensitive handled by browser)
          RequestFilterBuilder(
            namePrefix: 'MeDUSA',
            services: [serviceUuid],
          ),
          // Alternative: accept all devices with our service
          RequestFilterBuilder(
            services: [serviceUuid],
          ),
        ],
        // Also request optional services we might need
        optionalServices: [serviceUuid],
      );

      // Request device - this shows browser's device picker
      final device = await _webBluetooth.requestDevice(requestOptions);

      debugPrint('[WebBle] ✓ Device selected: ${device.name} (${device.id})');

      // Create our wrapper
      final webDevice = WebBleDevice(
        name: device.name ?? 'Unknown Device',
        id: device.id,
        device: device,
      );

      // Add to discovered list if not already there
      if (!_discoveredDevices.any((d) => d.id == webDevice.id)) {
        _discoveredDevices.add(webDevice);
        _devicesController.add(List.from(_discoveredDevices));
      }

      _isScanning = false;
      _setStatus('Device selected: ${webDevice.name}');
      notifyListeners();

      return webDevice;
    } on UserCancelledDialogError {
      debugPrint('[WebBle] User cancelled device selection');
      _setStatus('Device selection cancelled');
      _isScanning = false;
      notifyListeners();
      return null;
    } on DeviceNotFoundError {
      debugPrint('[WebBle] No devices found');
      _setError('No MeDUSA devices found nearby');
      _isScanning = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[WebBle] ❌ Request device failed: $e');
      _setError('Failed to request device: $e');
      _isScanning = false;
      notifyListeners();
      return null;
    }
  }

  /// Connect to a Web Bluetooth device
  Future<bool> connect(WebBleDevice webDevice) async {
    try {
      _setStatus('Connecting to ${webDevice.name}...');
      debugPrint('[WebBle] 🔗 Connecting to ${webDevice.name}...');

      final device = webDevice.device;
      
      // Connect to GATT server
      await device.connect();
      
      debugPrint('[WebBle] Connected, discovering services...');
      _setStatus('Discovering services...');

      // Discover services
      final services = await device.discoverServices();
      
      // Find our target service
      BluetoothService? targetService;
      for (var service in services) {
        debugPrint('[WebBle] Found service: ${service.uuid}');
        if (service.uuid.toLowerCase() == serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        debugPrint('[WebBle] Target service not found');
        _setError('Medical device service not found');
        device.disconnect();  // disconnect() returns void, no await needed
        return false;
      }

      debugPrint('[WebBle] ✓ Found target service, getting characteristics...');

      // Get characteristics
      final characteristics = await targetService.getCharacteristics();
      
      for (var char in characteristics) {
        final uuid = char.uuid.toLowerCase();
        debugPrint('[WebBle] Found characteristic: $uuid');
        
        if (uuid == writeCharacteristicUuid.toLowerCase()) {
          _writeCharacteristic = char;
          debugPrint('[WebBle] ✓ Write characteristic found');
        } else if (uuid == notifyCharacteristicUuid.toLowerCase()) {
          _notifyCharacteristic = char;
          debugPrint('[WebBle] ✓ Notify characteristic found');
          
          // Subscribe to notifications
          await _setupNotifications(char);
        }
      }

      _connectedDevice = device;
      _isConnected = true;
      _setStatus('Connected to ${webDevice.name}');
      debugPrint('[WebBle] ✅ Connection complete');
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[WebBle] ❌ Connection failed: $e');
      _setError('Connection failed: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Setup notifications for a characteristic
  Future<void> _setupNotifications(BluetoothCharacteristic characteristic) async {
    try {
      // Check if notifications are supported via properties
      final props = characteristic.properties;
      final supportsNotify = props.hasNotify && props.notify;
      final supportsIndicate = props.hasIndicate && props.indicate;
      
      if (!supportsNotify && !supportsIndicate) {
        debugPrint('[WebBle] Characteristic does not support notifications');
        return;
      }

      // Start notifications
      await characteristic.startNotifications();
      
      // Listen to value changes
      _notifySubscription = characteristic.value.listen(
        (data) {
          _handleIncomingData(data);
        },
        onError: (e) {
          debugPrint('[WebBle] Notification error: $e');
        },
      );

      debugPrint('[WebBle] ✓ Notifications enabled');
    } catch (e) {
      debugPrint('[WebBle] Failed to setup notifications: $e');
    }
  }

  /// Handle incoming data from notifications
  void _handleIncomingData(ByteData data) {
    try {
      // Convert ByteData to List<int>
      final bytes = data.buffer.asUint8List();
      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Add metadata
      jsonData['timestamp'] = DateTime.now().toIso8601String();
      jsonData['deviceId'] = _connectedDevice?.id ?? 'unknown';
      jsonData['platform'] = 'web';

      _dataController.add(jsonData);
      debugPrint('[WebBle] 📥 Received: $jsonString');
    } catch (e) {
      debugPrint('[WebBle] Failed to parse data: $e');
    }
  }

  /// Send data to the connected device
  Future<bool> sendData(Map<String, dynamic> data) async {
    if (!_isConnected || _writeCharacteristic == null) {
      _setError('Device not connected');
      return false;
    }

    try {
      final jsonData = jsonEncode(data);
      final bytes = utf8.encode(jsonData);
      
      // Convert to Uint8List for Web Bluetooth
      final uint8List = Uint8List.fromList(bytes);
      
      await _writeCharacteristic!.writeValueWithResponse(uint8List);
      debugPrint('[WebBle] 📤 Sent: $jsonData');
      return true;
    } catch (e) {
      debugPrint('[WebBle] Failed to send data: $e');
      _setError('Failed to send data: $e');
      return false;
    }
  }

  /// Send command to device
  Future<bool> sendCommand(String command, [Map<String, dynamic>? parameters]) async {
    final data = {
      'command': command,
      'timestamp': DateTime.now().toIso8601String(),
      if (parameters != null) 'parameters': parameters,
    };
    return await sendData(data);
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    if (!_isConnected || _connectedDevice == null) return;

    try {
      _setStatus('Disconnecting...');
      
      // Cancel subscriptions
      await _notifySubscription?.cancel();
      _notifySubscription = null;

      // Disconnect device
      _connectedDevice!.disconnect();
      
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _isConnected = false;
      
      _setStatus('Disconnected');
      debugPrint('[WebBle] ⏹️ Disconnected');
      notifyListeners();
    } catch (e) {
      debugPrint('[WebBle] Disconnect error: $e');
      _setError('Disconnect failed: $e');
    }
  }

  /// Get previously paired devices
  /// Note: This requires "Experimental Web Platform features" flag in Chrome
  Stream<Set<BluetoothDevice>> get pairedDevices => _webBluetooth.devices;

  void _setStatus(String status) {
    _status = status;
    _lastError = null;
    _statusController.add(status);
    debugPrint('[WebBle] Status: $status');
  }

  void _setError(String error) {
    _lastError = error;
    _status = 'Error: $error';
    _statusController.add(_status);
    debugPrint('[WebBle] ❌ Error: $error');
  }

  @override
  void dispose() {
    _availabilitySubscription?.cancel();
    _notifySubscription?.cancel();
    _devicesController.close();
    _statusController.close();
    _dataController.close();
    
    if (_isConnected) {
      disconnect();
    }
    
    super.dispose();
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'platform': 'web',
      'isSupported': isBluetoothApiSupported,
      'isInitialized': _isInitialized,
      'isConnected': _isConnected,
      'connectedDeviceId': _connectedDevice?.id,
      'discoveredDevices': _discoveredDevices.length,
      'status': _status,
      'lastError': _lastError,
    };
  }
}

/// Wrapper for Web Bluetooth device
class WebBleDevice {
  final String name;
  final String id;
  final BluetoothDevice device;
  
  WebBleDevice({
    required this.name,
    required this.id,
    required this.device,
  });

  @override
  String toString() => 'WebBleDevice($name, $id)';
}
