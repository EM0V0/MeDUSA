import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutter_blue_plus;
import 'package:permission_handler/permission_handler.dart';

import '../bluetooth/flutter_blue_adapter.dart';
import 'package:win_ble/win_ble.dart' as win_ble;

/// Medical device Bluetooth connection service for managing Raspberry Pi device connections
/// Handles device discovery, connection, data transmission, and status monitoring
class MedicalBluetoothService extends ChangeNotifier {
  static final MedicalBluetoothService _instance = MedicalBluetoothService._internal();
  factory MedicalBluetoothService() => _instance;
  MedicalBluetoothService._internal();

  // Connection state
  flutter_blue_plus.BluetoothDevice? _connectedDevice;
  flutter_blue_plus.BluetoothCharacteristic? _writeCharacteristic;
  flutter_blue_plus.BluetoothCharacteristic? _notifyCharacteristic;
  
  // Service and characteristic UUIDs for medical device communication
  static const String _serviceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String _writeCharacteristicUuid = "12345678-1234-1234-1234-123456789abd";
  static const String _notifyCharacteristicUuid = "12345678-1234-1234-1234-123456789abe";

  // State management
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  String? _lastError;
  
  // Device discovery
  final List<flutter_blue_plus.BluetoothDevice> _discoveredDevices = [];
  final StreamController<List<flutter_blue_plus.BluetoothDevice>> _devicesController = StreamController<List<flutter_blue_plus.BluetoothDevice>>.broadcast();
  
  // Data streams
  final StreamController<Map<String, dynamic>> _dataController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  // Subscriptions
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _dataSubscription;
  StreamSubscription<bool>? _winBleConnectionSubscription;

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  String? get lastError => _lastError;
  flutter_blue_plus.BluetoothDevice? get connectedDevice => _connectedDevice;
  List<flutter_blue_plus.BluetoothDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  
  // Streams
  Stream<List<flutter_blue_plus.BluetoothDevice>> get devicesStream => _devicesController.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  Stream<String> get statusStream => _statusController.stream;

  /// Initialize Bluetooth service and request permissions
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (!await FlutterBlueAdapter.isSupported) {
        _setError('Bluetooth is not supported on this device');
        return false;
      }

      // Request permissions
      if (!await _requestPermissions()) {
        _setError('Bluetooth permissions not granted');
        return false;
      }

      // Check if Bluetooth is enabled
      if (!await _isBluetoothEnabled()) {
        _setError('Please enable Bluetooth');
        return false;
      }

      _setStatus('Bluetooth service initialized');
      return true;
    } catch (e) {
      _setError('Failed to initialize Bluetooth: $e');
      return false;
    }
  }

  /// Request necessary permissions for Bluetooth
  Future<bool> _requestPermissions() async {
    // Web platform doesn't need permission requests - browser handles it
    if (kIsWeb) {
      return true;
    }
    
    try {
      if (Platform.isAndroid) {
        // Android permissions
        final permissions = [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.location,
        ];

        Map<Permission, PermissionStatus> statuses = await permissions.request();
        
        return statuses.values.every((status) => 
            status == PermissionStatus.granted || 
            status == PermissionStatus.limited);
      } else if (Platform.isIOS) {
        // iOS permissions are handled automatically by flutter_blue_plus
        return true;
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
      // On Web or unsupported platforms, continue anyway
      return true;
    }
    
    return true;
  }

  /// Check if Bluetooth is enabled
  Future<bool> _isBluetoothEnabled() async {
    try {
      final adapterState = await FlutterBlueAdapter.adapterState.first
          .timeout(const Duration(seconds: 2));
      
      // On Windows, 'unknown' state often means Bluetooth is available but state can't be determined
      // We should allow it and let the actual scan determine availability
      if (Platform.isWindows || kIsWeb) {
        final isAvailable = adapterState == flutter_blue_plus.BluetoothAdapterState.on ||
                           adapterState == flutter_blue_plus.BluetoothAdapterState.unknown;
        debugPrint('[BT Init] Windows/Web - Adapter state: $adapterState, treating as available: $isAvailable');
        return isAvailable;
      }
      
      // On mobile platforms, require explicit 'on' state
      final isOn = adapterState == flutter_blue_plus.BluetoothAdapterState.on;
      debugPrint('[BT Init] Mobile - Adapter state: $adapterState, isOn: $isOn');
      return isOn;
    } catch (e) {
      debugPrint('[BT Init] Error checking Bluetooth state: $e');
      // On Windows, if we can't determine state, assume it's available
      if (Platform.isWindows || kIsWeb) {
        debugPrint('[BT Init] Windows/Web - Error occurred, assuming Bluetooth available');
        return true;
      }
      return false;
    }
  }

  /// Start scanning for Raspberry Pi devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isScanning) {
      debugPrint('Already scanning');
      return;
    }

    try {
      _isScanning = true;
      _discoveredDevices.clear();
      
      // Immediately notify UI with empty list
      _devicesController.add([]);
      
      _setStatus('Scanning for devices...');
      notifyListeners();

      debugPrint('📡 [Scan] Starting...');
      
      // Start scanning - do NOT use withServices filter
      // Many devices (including Raspberry Pi) don't advertise service UUIDs in broadcast packets
      // We filter by device name instead (see _isTargetDevice method)
      await FlutterBlueAdapter.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      _scanSubscription = FlutterBlueAdapter.scanResults.listen(
        (results) {
          for (flutter_blue_plus.ScanResult result in results) {
            final device = result.device;
            
            // Filter for MeDUSA devices by name
            if (_isTargetDevice(device, result.advertisementData)) {
              if (!_discoveredDevices.any((d) => d.remoteId == device.remoteId)) {
                final displayName = device.platformName.isNotEmpty 
                    ? device.platformName 
                    : result.advertisementData.advName;
                
                _discoveredDevices.add(device);
                debugPrint('✓ [Scan] Found: $displayName');
                
                // Send copy to ensure stream triggers
                _devicesController.add(List.from(_discoveredDevices));
                _setStatus('Found ${_discoveredDevices.length} device(s)');
              }
              // Don't log if already in list - reduces spam
            }
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('❌ [Scan] Error: $e');
          _setError('Scan error: $e');
        },
      );

      // For Web Bluetooth: check already connected devices
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
        final connectedDevices = FlutterBlueAdapter.connectedDevices;
        for (var device in connectedDevices) {
          if (device.platformName.toLowerCase().contains('medusa')) {
            if (!_discoveredDevices.any((d) => d.remoteId == device.remoteId)) {
              _discoveredDevices.add(device);
              _devicesController.add(_discoveredDevices);
              debugPrint('✓ [Scan] Found: ${device.platformName}');
              _setStatus('Found ${_discoveredDevices.length} device(s)');
              notifyListeners();
            }
          }
        }
      }

      // Auto-stop scanning after timeout
      Timer(timeout, () {
        if (_isScanning) {
          stopScan();
          debugPrint('⏹️ [Scan] Timeout - found ${_discoveredDevices.length} device(s)');
        }
      });

    } catch (e) {
      debugPrint('❌ [Scan] Failed: $e');
      _setError('Failed to start scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBlueAdapter.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      
      _isScanning = false;
      _setStatus('Scan stopped');
      notifyListeners();
    } catch (e) {
      _setError('Failed to stop scan: $e');
    }
  }

  /// Check if device is a target medical device
  /// ONLY MeDUSA Pi devices - filtering out all other BLE devices
  bool _isTargetDevice(flutter_blue_plus.BluetoothDevice device, flutter_blue_plus.AdvertisementData adData) {
    // Check device name patterns
    final name = device.platformName.toLowerCase();
    final localName = adData.advName.toLowerCase();
    
    // ONLY look for "medusa" - no other devices
    final isMedusaDevice = name.contains('medusa') || localName.contains('medusa');
    
    // Don't log here - logging happens in scan callback when device is actually added
    
    return isMedusaDevice;
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(flutter_blue_plus.BluetoothDevice device) async {
    if (_isConnecting || _isConnected) {
      debugPrint('Already connecting or connected');
      return false;
    }

    try {
      _isConnecting = true;
      _setStatus('Connecting to ${device.platformName}...');
      notifyListeners();

      // Stop scanning if active
      if (_isScanning) {
        await stopScan();
      }

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find our target service
      flutter_blue_plus.BluetoothService? targetService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == _serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception('Target service not found');
      }

      // Find characteristics
      for (var characteristic in targetService.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        
        if (uuid == _writeCharacteristicUuid.toLowerCase()) {
          _writeCharacteristic = characteristic;
        } else if (uuid == _notifyCharacteristicUuid.toLowerCase()) {
          _notifyCharacteristic = characteristic;
          
          // Subscribe to notifications
          await characteristic.setNotifyValue(true);
          _dataSubscription = characteristic.lastValueStream.listen(
            (data) {
              _handleIncomingData(data);
            },
            onError: (e) {
              _setError('Data stream error: $e');
            },
          );
        }
      }

      // Monitor connection state
      _connectionSubscription = device.connectionState.listen(
        (state) {
          if (state == flutter_blue_plus.BluetoothConnectionState.connected) {
            _isConnected = true;
            _connectedDevice = device;
            _setStatus('Connected to ${device.platformName}');
          } else if (state == flutter_blue_plus.BluetoothConnectionState.disconnected) {
            _handleDisconnection();
          }
          notifyListeners();
        },
        onError: (e) {
          _setError('Connection state error: $e');
        },
      );

      if (Platform.isWindows) {
        _winBleConnectionSubscription?.cancel();
        final address = device.remoteId.str;
        _winBleConnectionSubscription =
            win_ble.WinBle.connectionStreamOf(address).listen(
          (connected) {
            debugPrint('WinBle connection update for $address: $connected');
          },
          onError: (error) {
            debugPrint('WinBle connection stream error: $error');
          },
        );
      }

      _isConnecting = false;
      return true;

    } catch (e) {
      _setError('Connection failed: $e');
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (!_isConnected || _connectedDevice == null) return;

    try {
      _setStatus('Disconnecting...');
      
      // Cancel subscriptions
      await _dataSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _winBleConnectionSubscription?.cancel();
      
      // Disconnect device
      await _connectedDevice!.disconnect();
      
      _handleDisconnection();
    } catch (e) {
      _setError('Disconnect failed: $e');
    }
  }

  /// Handle disconnection cleanup
  void _handleDisconnection() {
    _isConnected = false;
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _winBleConnectionSubscription?.cancel();
    
    _setStatus('Disconnected');
    notifyListeners();
  }

  /// Send data to connected device
  Future<bool> sendData(Map<String, dynamic> data) async {
    if (!_isConnected || _writeCharacteristic == null) {
      _setError('Device not connected');
      return false;
    }

    try {
      final jsonData = jsonEncode(data);
      final bytes = utf8.encode(jsonData);
      
      await _writeCharacteristic!.write(bytes, withoutResponse: false);
      debugPrint('Sent data: $jsonData');
      return true;
    } catch (e) {
      _setError('Failed to send data: $e');
      return false;
    }
  }

  /// Handle incoming data from device
  void _handleIncomingData(List<int> data) {
    try {
      final jsonString = utf8.decode(data);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Add timestamp
      jsonData['timestamp'] = DateTime.now().toIso8601String();
      jsonData['deviceId'] = _connectedDevice?.remoteId.toString();
      
      _dataController.add(jsonData);
      debugPrint('Received data: $jsonString');
    } catch (e) {
      _setError('Failed to parse incoming data: $e');
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

  /// Start data collection
  Future<bool> startDataCollection() async {
    return await sendCommand('start_collection');
  }

  /// Stop data collection
  Future<bool> stopDataCollection() async {
    return await sendCommand('stop_collection');
  }

  /// Get device information
  Future<bool> getDeviceInfo() async {
    return await sendCommand('get_info');
  }

  /// Set device configuration
  Future<bool> setConfiguration(Map<String, dynamic> config) async {
    return await sendCommand('set_config', config);
  }

  /// Get connected device info as map
  Map<String, dynamic>? getConnectedDeviceInfo() {
    if (_connectedDevice == null) return null;
    
    return {
      'id': _connectedDevice!.remoteId.toString(),
      'name': _connectedDevice!.platformName,
      'isConnected': _isConnected,
      'connectionStatus': _connectionStatus,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Set error message
  void _setError(String error) {
    _lastError = error;
    _connectionStatus = 'Error: $error';
    _statusController.add(_connectionStatus);
    debugPrint('Bluetooth Error: $error');
    notifyListeners();
  }

  /// Set status message
  void _setStatus(String status) {
    _lastError = null;
    _connectionStatus = status;
    _statusController.add(_connectionStatus);
    debugPrint('Bluetooth Status: $status');
    notifyListeners();
  }

  /// Dispose service and cleanup resources
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _winBleConnectionSubscription?.cancel();
    _devicesController.close();
    _dataController.close();
    _statusController.close();
    
    if (_isConnected) {
      disconnect();
    }
    
    super.dispose();
  }

  /// Get device statistics
  Map<String, dynamic> getDeviceStatistics() {
    return {
      'discoveredDevices': _discoveredDevices.length,
      'isScanning': _isScanning,
      'isConnected': _isConnected,
      'connectedDevice': getConnectedDeviceInfo(),
      'lastError': _lastError,
      'status': _connectionStatus,
      'hasNotifyCharacteristic': _notifyCharacteristic != null,
    };
  }
}
