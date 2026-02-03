import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:win_ble/win_ble.dart' as winble;
import 'winble_service.dart';

/// Unified Bluetooth adapter that uses WinBle on Windows
/// and FlutterBluePlus on other platforms
/// 
/// This allows the rest of the app to use a consistent API
/// while using platform-specific implementations under the hood.
class BluetoothAdapter {
  static final BluetoothAdapter _instance = BluetoothAdapter._internal();
  factory BluetoothAdapter() => _instance;
  BluetoothAdapter._internal();

  // Platform-specific services
  final WinBleService _winBleService = WinBleService();
  
  // State
  bool _isInitialized = false;
  bool _isScanning = false;
  String _status = 'Idle';
  
  final List<UnifiedBleDevice> _discoveredDevices = [];
  final StreamController<List<UnifiedBleDevice>> _devicesController =
      StreamController<List<UnifiedBleDevice>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  // Getters
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  String get status => _status;
  Stream<List<UnifiedBleDevice>> get devicesStream => _devicesController.stream;
  Stream<String> get statusStream => _statusController.stream;
  List<UnifiedBleDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Initialize the adapter
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    // Web platform uses WebBleService, not this adapter
    if (kIsWeb) {
      debugPrint('[BluetoothAdapter] Web platform - use WebBleService instead');
      _isInitialized = true;
      _setStatus('Initialized (Web - use WebBleService)');
      return true;
    }

    try {
      if (Platform.isWindows) {
        debugPrint('[BluetoothAdapter] Using WinBle for Windows');
        final success = await _winBleService.initialize();
        if (success) {
          // Listen to WinBle device stream
          _winBleService.devicesStream.listen((winbleDevices) {
            _discoveredDevices.clear();
            for (var device in winbleDevices) {
              _discoveredDevices.add(UnifiedBleDevice.fromWinBle(device));
            }
            _devicesController.add(List.from(_discoveredDevices));
          });
          
          _isInitialized = true;
          _setStatus('Initialized (WinBle)');
          return true;
        }
        return false;
      } else {
        debugPrint('[BluetoothAdapter] Using FlutterBluePlus for ${Platform.operatingSystem}');
        // FlutterBluePlus doesn't need explicit initialization
        _isInitialized = true;
        _setStatus('Initialized (FlutterBluePlus)');
        return true;
      }
    } catch (e) {
      debugPrint('[BluetoothAdapter] Initialization failed: $e');
      _setStatus('Initialization failed');
      return false;
    }
  }

  /// Start scanning for devices
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
    String? nameFilter,
  }) async {
    if (_isScanning) {
      debugPrint('[BluetoothAdapter] Already scanning');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _devicesController.add([]);
    _setStatus('Scanning...');

    // Web platform doesn't support background scanning
    if (kIsWeb) {
      debugPrint('[BluetoothAdapter] Web platform - background scanning not supported');
      _isScanning = false;
      _setStatus('Web: Use device selection dialog');
      return;
    }

    if (Platform.isWindows) {
      // Use WinBle
      await _winBleService.startScan(timeout: timeout, nameFilter: nameFilter);
    } else {
      // Use FlutterBluePlus
      try {
        await fbp.FlutterBluePlus.startScan(timeout: timeout);
        
        // Listen to scan results
        fbp.FlutterBluePlus.scanResults.listen((results) {
          _discoveredDevices.clear();
          for (var result in results) {
            final deviceName = result.device.platformName.toLowerCase();
            if (nameFilter != null && !deviceName.contains(nameFilter.toLowerCase())) {
              continue;
            }
            _discoveredDevices.add(UnifiedBleDevice.fromFlutterBluePlus(result.device));
          }
          _devicesController.add(List.from(_discoveredDevices));
          _setStatus('Found ${_discoveredDevices.length} device(s)');
        });
      } catch (e) {
        debugPrint('[BluetoothAdapter] Scan failed: $e');
        _isScanning = false;
        _setStatus('Scan failed');
      }
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    if (Platform.isWindows) {
      await _winBleService.stopScan();
    } else {
      await fbp.FlutterBluePlus.stopScan();
    }

    _isScanning = false;
    _setStatus('Scan stopped');
  }

  /// Connect to a device
  Future<bool> connect(UnifiedBleDevice device) async {
    try {
      _setStatus('Connecting...');
      
      if (Platform.isWindows) {
        final success = await _winBleService.connect(device.address);
        if (success) {
          _setStatus('Connected');
          return true;
        }
        return false;
      } else {
        if (device.flutterBluePlusDevice != null) {
          await device.flutterBluePlusDevice!.connect();
          _setStatus('Connected');
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('[BluetoothAdapter] Connection failed: $e');
      _setStatus('Connection failed');
      return false;
    }
  }

  /// Disconnect from a device
  Future<void> disconnect(UnifiedBleDevice device) async {
    try {
      if (Platform.isWindows) {
        await _winBleService.disconnect(device.address);
      } else {
        if (device.flutterBluePlusDevice != null) {
          await device.flutterBluePlusDevice!.disconnect();
        }
      }
      _setStatus('Disconnected');
    } catch (e) {
      debugPrint('[BluetoothAdapter] Disconnect failed: $e');
    }
  }

  /// Pair with a device (Windows only, uses WinRT)
  Future<bool> pairDevice(UnifiedBleDevice device) async {
    if (!Platform.isWindows) {
      debugPrint('[BluetoothAdapter] Pairing only supported on Windows');
      return false;
    }

    return await _winBleService.pairDevice(device.address);
  }

  void _setStatus(String status) {
    _status = status;
    _statusController.add(status);
  }

  void dispose() {
    _devicesController.close();
    _statusController.close();
  }
}

/// Unified BLE device representation
/// Works across both WinBle and FlutterBluePlus
class UnifiedBleDevice {
  final String name;
  final String address;
  final int? rssi;
  
  // Platform-specific device objects
  final winble.BleDevice? winBleDevice;
  final fbp.BluetoothDevice? flutterBluePlusDevice;

  UnifiedBleDevice({
    required this.name,
    required this.address,
    this.rssi,
    this.winBleDevice,
    this.flutterBluePlusDevice,
  });

  factory UnifiedBleDevice.fromWinBle(winble.BleDevice device) {
    // Convert rssi from String to int?
    // win_ble package returns rssi as String, convert to int?
    final rssiValue = int.tryParse(device.rssi);
    
    return UnifiedBleDevice(
      name: device.name,
      address: device.address,
      rssi: rssiValue,
      winBleDevice: device,
    );
  }

  factory UnifiedBleDevice.fromFlutterBluePlus(fbp.BluetoothDevice device) {
    return UnifiedBleDevice(
      name: device.platformName,
      address: device.remoteId.toString(),
      flutterBluePlusDevice: device,
    );
  }

  @override
  String toString() => 'UnifiedBleDevice($name, $address)';
}