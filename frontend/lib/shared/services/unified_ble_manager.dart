import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'ble_interface.dart';
import 'web_ble_service.dart';
import 'winble_service.dart';

/// Unified BLE Manager that automatically selects the correct platform implementation
/// 
/// Usage:
/// ```dart
/// final bleManager = UnifiedBleManager();
/// await bleManager.initialize();
/// 
/// // On Web - use requestDevice (triggers browser dialog)
/// if (bleManager.isWebPlatform) {
///   final device = await bleManager.requestDevice();
///   if (device != null) {
///     await bleManager.connect(device);
///   }
/// } else {
///   // On Desktop/Mobile - use scan
///   await bleManager.startScan();
///   // Wait for devices, then connect
/// }
/// ```
class UnifiedBleManager extends ChangeNotifier implements BleInterface {
  // Singleton
  static final UnifiedBleManager _instance = UnifiedBleManager._internal();
  factory UnifiedBleManager() => _instance;
  UnifiedBleManager._internal();

  // Platform services
  WebBleService? _webService;
  WinBleService? _winService;

  // State
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnected = false;
  String _status = 'Not initialized';
  String? _lastError;
  UnifiedDevice? _connectedDevice;

  final List<UnifiedDevice> _discoveredDevices = [];
  final StreamController<List<UnifiedDevice>> _devicesController =
      StreamController<List<UnifiedDevice>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Subscriptions
  StreamSubscription? _devicesSub;
  StreamSubscription? _dataSub;

  // Platform detection
  bool get isWebPlatform => kIsWeb;
  bool get isWindowsPlatform => !kIsWeb && Platform.isWindows;
  bool get isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  DevicePlatform get currentPlatform {
    if (kIsWeb) return DevicePlatform.web;
    if (Platform.isWindows) return DevicePlatform.windows;
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isIOS) return DevicePlatform.ios;
    if (Platform.isMacOS) return DevicePlatform.macos;
    if (Platform.isLinux) return DevicePlatform.linux;
    return DevicePlatform.windows; // fallback
  }

  // Getters
  @override
  bool get isInitialized => _isInitialized;
  @override
  bool get isScanning => _isScanning;
  @override
  bool get isConnected => _isConnected;
  @override
  String get status => _status;
  @override
  String? get lastError => _lastError;
  UnifiedDevice? get connectedDevice => _connectedDevice;

  @override
  Stream<List<UnifiedDevice>> get devicesStream => _devicesController.stream;
  @override
  Stream<String> get statusStream => _statusController.stream;
  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  
  List<UnifiedDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Check if Web Bluetooth is supported (Web platform only)
  bool get isWebBluetoothSupported {
    if (!isWebPlatform) return false;
    _webService ??= WebBleService();
    return _webService!.isBluetoothApiSupported;
  }

  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('[UnifiedBLE] Already initialized');
      return true;
    }

    try {
      debugPrint('[UnifiedBLE] 🔧 Initializing for ${currentPlatform.name}...');

      if (isWebPlatform) {
        _webService = WebBleService();
        final success = await _webService!.initialize();
        
        if (success) {
          // Listen to web service streams
          _devicesSub = _webService!.devicesStream.listen((devices) {
            _discoveredDevices.clear();
            for (var device in devices) {
              _discoveredDevices.add(UnifiedDevice(
                name: device.name,
                id: device.id,
                platformDevice: device,
                platform: DevicePlatform.web,
              ));
            }
            _devicesController.add(List.from(_discoveredDevices));
          });

          _dataSub = _webService!.dataStream.listen((data) {
            _dataController.add(data);
          });

          _webService!.statusStream.listen((status) {
            _setStatus(status);
          });
        }

        _isInitialized = success;
        _setStatus(success ? 'Initialized (Web)' : 'Web Bluetooth not supported');
        return success;
      } else if (isWindowsPlatform) {
        _winService = WinBleService();
        final success = await _winService!.initialize();

        if (success) {
          // Listen to Windows service streams
          _devicesSub = _winService!.devicesStream.listen((devices) {
            _discoveredDevices.clear();
            for (var device in devices) {
              _discoveredDevices.add(UnifiedDevice(
                name: device.name,
                id: device.address,
                rssi: int.tryParse(device.rssi),
                platformDevice: device,
                platform: DevicePlatform.windows,
              ));
            }
            _devicesController.add(List.from(_discoveredDevices));
          });
        }

        _isInitialized = success;
        _setStatus(success ? 'Initialized (Windows)' : 'WinBLE initialization failed');
        return success;
      } else {
        // Mobile platforms - use FlutterBluePlus (handled by bluetooth_service.dart)
        _isInitialized = true;
        _setStatus('Initialized (Mobile)');
        return true;
      }
    } catch (e) {
      debugPrint('[UnifiedBLE] ❌ Initialization failed: $e');
      _setError('Initialization failed: $e');
      return false;
    }
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 30)}) async {
    if (isWebPlatform) {
      // Web doesn't support background scanning
      // Call requestDevice() instead
      _setError('Web platform requires user interaction. Use requestDevice() instead.');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _devicesController.add([]);
    _setStatus('Scanning...');
    notifyListeners();

    if (isWindowsPlatform && _winService != null) {
      await _winService!.startScan(timeout: timeout, nameFilter: 'medusa');
    }
    // Mobile handled by MedicalBluetoothService

    // Wait for timeout then stop
    Future.delayed(timeout, () {
      if (_isScanning) {
        stopScan();
      }
    });
  }

  @override
  Future<void> stopScan() async {
    if (!_isScanning) return;

    if (isWindowsPlatform && _winService != null) {
      await _winService!.stopScan();
    }

    _isScanning = false;
    _setStatus('Scan stopped');
    notifyListeners();
  }

  @override
  Future<UnifiedDevice?> requestDevice() async {
    if (!isWebPlatform) {
      debugPrint('[UnifiedBLE] requestDevice() is only for Web platform');
      return null;
    }

    if (!_isInitialized) {
      await initialize();
    }

    _webService ??= WebBleService();
    final webDevice = await _webService!.requestDevice();

    if (webDevice != null) {
      final device = UnifiedDevice(
        name: webDevice.name,
        id: webDevice.id,
        platformDevice: webDevice,
        platform: DevicePlatform.web,
      );

      if (!_discoveredDevices.any((d) => d.id == device.id)) {
        _discoveredDevices.add(device);
        _devicesController.add(List.from(_discoveredDevices));
      }

      return device;
    }

    return null;
  }

  @override
  Future<bool> connect(UnifiedDevice device) async {
    try {
      _setStatus('Connecting to ${device.name}...');

      bool success = false;

      if (isWebPlatform && _webService != null) {
        if (device.platformDevice is WebBleDevice) {
          success = await _webService!.connect(device.platformDevice as WebBleDevice);
        }
      } else if (isWindowsPlatform && _winService != null) {
        success = await _winService!.connect(device.id);
      }

      if (success) {
        _connectedDevice = device;
        _isConnected = true;
        _setStatus('Connected to ${device.name}');
      } else {
        _setError('Failed to connect to ${device.name}');
      }

      notifyListeners();
      return success;
    } catch (e) {
      _setError('Connection error: $e');
      notifyListeners();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      if (isWebPlatform && _webService != null) {
        await _webService!.disconnect();
      } else if (isWindowsPlatform && _winService != null) {
        if (_connectedDevice != null) {
          await _winService!.disconnect(_connectedDevice!.id);
        }
      }

      _connectedDevice = null;
      _isConnected = false;
      _setStatus('Disconnected');
      notifyListeners();
    } catch (e) {
      _setError('Disconnect error: $e');
    }
  }

  @override
  Future<bool> sendData(Map<String, dynamic> data) async {
    if (!_isConnected) {
      _setError('Not connected');
      return false;
    }

    if (isWebPlatform && _webService != null) {
      return await _webService!.sendData(data);
    } else if (isWindowsPlatform && _winService != null) {
      // WinBLE sendData implementation would go here
      return false;
    }

    return false;
  }

  @override
  Future<bool> sendCommand(String command, [Map<String, dynamic>? parameters]) async {
    final data = {
      'command': command,
      'timestamp': DateTime.now().toIso8601String(),
      if (parameters != null) 'parameters': parameters,
    };
    return await sendData(data);
  }

  void _setStatus(String status) {
    _status = status;
    _lastError = null;
    _statusController.add(status);
    debugPrint('[UnifiedBLE] Status: $status');
  }

  void _setError(String error) {
    _lastError = error;
    _status = 'Error: $error';
    _statusController.add(_status);
    debugPrint('[UnifiedBLE] ❌ Error: $error');
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _dataSub?.cancel();
    _devicesController.close();
    _statusController.close();
    _dataController.close();

    if (_isConnected) {
      disconnect();
    }

    super.dispose();
  }

  /// Get platform-specific statistics
  Map<String, dynamic> getStatistics() {
    return {
      'platform': currentPlatform.name,
      'isInitialized': _isInitialized,
      'isScanning': _isScanning,
      'isConnected': _isConnected,
      'connectedDevice': _connectedDevice?.toString(),
      'discoveredDevices': _discoveredDevices.length,
      'status': _status,
      'lastError': _lastError,
      'isWebBluetoothSupported': isWebPlatform ? isWebBluetoothSupported : null,
    };
  }
}
