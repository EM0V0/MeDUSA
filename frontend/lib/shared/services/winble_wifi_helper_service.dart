import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'winble_service.dart';

/// WinBle-based WiFi Helper service for Windows
/// 
/// Handles complete WiFi provisioning flow:
/// 1. Scan for MeDUSA devices
/// 2. Connect
/// 3. Pair (triggers Windows PIN dialog)
/// 4. Discover WiFi Helper service
/// 5. Write WiFi credentials
/// 6. Monitor status
class WinBleWiFiHelperService extends ChangeNotifier {
  static final WinBleWiFiHelperService _instance = WinBleWiFiHelperService._internal();
  factory WinBleWiFiHelperService() => _instance;
  WinBleWiFiHelperService._internal() {
    _setupPinChannelListener();
  }

  final WinBleService _winBle = WinBleService();
  
  // PIN input method channel
  static const MethodChannel _pinChannel = MethodChannel('com.medusa/windows_ble_pairing/pin');
  
  // PIN request callback - set by UI (no BuildContext needed, UI will handle it)
  Function()? _onPinRequested;
  
  /// Register callback for PIN requests from C++
  /// The callback should show the PIN input dialog
  void setOnPinRequested(Function() callback) {
    _onPinRequested = callback;
    debugPrint('[WinBleWiFi] 🔐 PIN request callback registered');
  }
  
  /// Setup method channel listener for PIN requests from C++
  void _setupPinChannelListener() {
    debugPrint('[WinBleWiFi] 📡 Setting up PIN channel listener...');
    _pinChannel.setMethodCallHandler((call) async {
      debugPrint('[WinBleWiFi] 📥 Received method call from C++: ${call.method}');
      debugPrint('[WinBleWiFi] 📥 Call arguments: ${call.arguments}');
      
      switch (call.method) {
        case 'onPinRequest':
          debugPrint('[WinBleWiFi] 🔐 C++ requesting PIN input (Pi has generated PIN on OLED)');
          debugPrint('[WinBleWiFi] 🔐 Checking if callback is registered: ${_onPinRequested != null}');
          // Notify UI to show PIN dialog
          if (_onPinRequested != null) {
            debugPrint('[WinBleWiFi] 🔐 Invoking PIN request callback NOW');
            try {
              _onPinRequested!();
              debugPrint('[WinBleWiFi] 🔐 PIN request callback invoked successfully');
            } catch (e, stackTrace) {
              debugPrint('[WinBleWiFi] ❌ Error invoking PIN request callback: $e');
              debugPrint('[WinBleWiFi] ❌ Stack trace: $stackTrace');
            }
          } else {
            debugPrint('[WinBleWiFi] ⚠️ No PIN request callback registered!');
            debugPrint('[WinBleWiFi] ⚠️ This means UI has not called setOnPinRequested()');
          }
          return null;
          
        default:
          debugPrint('[WinBleWiFi] ❌ Unknown method: ${call.method}');
          throw MissingPluginException('Method ${call.method} not implemented');
      }
    });
    
    debugPrint('[WinBleWiFi] 📡 PIN channel listener setup complete');
  }

  // WiFi Helper GATT Service UUIDs
  static const String serviceUuid = 'c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String ssidCharUuid = 'c0de0001-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String pskCharUuid = 'c0de0002-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String controlCharUuid = 'c0de0003-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String statusCharUuid = 'c0de0004-7e1a-4f83-bf3a-0c0ffee0c0de';

  // Control commands
  static const int cmdConnect = 0x01;
  static const int cmdClear = 0x02;
  static const int cmdFactoryReset = 0x03;

  // Status codes
  static const Map<int, String> statusCodes = {
    0x01: 'Idle',
    0x02: 'Pairing',
    0x03: 'Ready',
    0x04: 'Connecting',
    0x05: 'Authenticating',
    0x06: 'Obtaining IP',
    0x07: 'Success ✅',
    0xF0: 'Fail: Pairing ❌',
    0xF1: 'Fail: Authentication ❌',
    0xF2: 'Fail: Network ❌',
    0xFF: 'Fail: Internal ❌',
  };

  // State
  String _status = 'Idle';
  String? _connectedDeviceAddress;
  bool _isPaired = false;
  String? _lastError;

  // Status stream controller
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  String get status => _status;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  bool get isPaired => _isPaired;
  String? get lastError => _lastError;
  Stream<String> get statusStream => _statusController.stream;
  
  /// Submit PIN to C++ plugin
  Future<void> submitPinToPlugin(String pin) async {
    debugPrint('[WinBleWiFi] 🔐 Submitting PIN to C++ plugin: $pin');
    
    if (pin.isEmpty) {
      debugPrint('[WinBleWiFi] ❌ PIN is empty');
      throw Exception('PIN cannot be empty');
    }
    
    try {
      await _pinChannel.invokeMethod('submitPin', {'pin': pin});
      debugPrint('[WinBleWiFi] ✅ PIN submitted to C++ plugin');
    } catch (e) {
      debugPrint('[WinBleWiFi] ❌ Error submitting PIN: $e');
      throw Exception('Failed to submit PIN: $e');
    }
  }
  
  /// Show PIN input dialog
  Future<String?> _showPinDialog() async {
    // This method is now handled by the UI layer (wifi_provision_page.dart)
    // The PIN input dialog is shown there and the PIN is passed to this service
    debugPrint('[WinBleWiFi] 🔐 PIN input dialog should be handled by UI layer');
    return null; // This will be overridden by the actual PIN from UI
  }

  /// Connect and pair with device (without provisioning WiFi yet)
  /// 
  /// [deviceAddress]: BLE device address (MAC)
  /// 
  /// Returns: true if connection and pairing succeed
  Future<bool> connectAndPair(String deviceAddress) async {
    try {
      debugPrint('[WinBleWiFi] 🚀 Starting connection and pairing for $deviceAddress');
      _lastError = null;
      
      // 1. Initialize
      await _winBle.initialize();
      
      // 2. Pair FIRST (before connecting)
      // CRITICAL: Must pair before connect to avoid "Operation already in progress" error
      // Connecting first triggers Windows auto-pairing which conflicts with manual pairing
      _setStatus('Pairing...');
      debugPrint('[WinBleWiFi] 🔐 Starting pairing (BEFORE connection)');
      debugPrint('[WinBleWiFi] 🔐 Windows PIN dialog will appear');
      debugPrint('[WinBleWiFi] 📱 Check Raspberry Pi OLED for 6-digit PIN');
      
      final paired = await _winBle.pairDevice(deviceAddress);
      if (!paired) {
        _lastError = 'Pairing failed - user may have cancelled';
        throw Exception(_lastError);
      }
      _isPaired = true;
      debugPrint('[WinBleWiFi] ✅ Pairing successful');

      // 3. Connect (AFTER successful pairing)
      _setStatus('Connecting to device...');
      debugPrint('[WinBleWiFi] 🔌 Connecting to paired device...');
      
      final connected = await _winBle.connect(deviceAddress);
      if (!connected) {
        _lastError = 'Failed to connect to device';
        throw Exception(_lastError);
      }
      _connectedDeviceAddress = deviceAddress;
      debugPrint('[WinBleWiFi] ✅ Connected');

      // Small delay to ensure pairing is complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // 4. Discover services
      _setStatus('Discovering services...');
      final services = await _winBle.discoverServices(deviceAddress);
      debugPrint('[WinBleWiFi] 🔍 Discovered ${services.length} service(s)');

      // Debug: Print all discovered services
      debugPrint('[WinBleWiFi] 📋 Listing all discovered services:');
      for (var i = 0; i < services.length; i++) {
        // WinBle returns services as String UUIDs directly, not objects
        final uuid = services[i] as String;
        debugPrint('[WinBleWiFi]   Service $i: $uuid');
      }
      
      // Verify WiFi Helper service exists
      final targetUuid = serviceUuid.toLowerCase().replaceAll('-', '');
      debugPrint('[WinBleWiFi] 🔍 Looking for service UUID: $serviceUuid');
      debugPrint('[WinBleWiFi] 🔍 Normalized UUID: $targetUuid');
      
      final hasWiFiService = services.any((service) {
        // Service is already a String UUID
        final uuid = service as String;
        final normalizedUuid = uuid.toLowerCase().replaceAll('-', '');
        final matches = normalizedUuid == targetUuid;
        
        if (matches) {
          debugPrint('[WinBleWiFi]   ✅ MATCH FOUND: $uuid');
        }
        
        return matches;
      });
      
      if (!hasWiFiService) {
        _lastError = 'WiFi Helper service not found';
        debugPrint('[WinBleWiFi] ❌ WiFi Helper service UUID not in discovered services!');
        debugPrint('[WinBleWiFi] ❌ Expected: $serviceUuid');
        debugPrint('[WinBleWiFi] ❌ This likely means:');
        debugPrint('[WinBleWiFi]    1. Raspberry Pi GATT server is not running');
        debugPrint('[WinBleWiFi]    2. Service UUID mismatch');
        debugPrint('[WinBleWiFi]    3. Service requires higher permissions');
        throw Exception(_lastError);
      }
      debugPrint('[WinBleWiFi] ✅ WiFi Helper service found');

      _setStatus('Connected and paired successfully');
      return true;

    } catch (e) {
      debugPrint('[WinBleWiFi] ❌ Error: $e');
      _lastError = e.toString();
      _setStatus('Error: $e');
      return false;
    }
  }

  /// Unpair a device to allow fresh pairing with new PIN
  /// 
  /// This is useful when:
  /// - User wants to re-enter PIN code
  /// - Raspberry Pi is not generating new PIN (because already paired)
  /// - Need to clear old pairing state
  /// 
  /// [deviceAddress]: BLE device address (MAC) to unpair
  /// 
  /// Returns: true if unpair succeeds
  Future<bool> unpairDevice(String deviceAddress) async {
    try {
      debugPrint('[WinBleWiFi] 🔓 Unpairing device $deviceAddress');
      _lastError = null;
      
      // Call WinBle unpair (which uses WindowsPairingService)
      final success = await _winBle.unpairDevice(deviceAddress);
      
      if (success) {
        // Reset state
        _connectedDeviceAddress = null;
        _isPaired = false;
        
        debugPrint('[WinBleWiFi] ✅ Device unpaired successfully');
        _setStatus('Device unpaired - ready for fresh pairing');
        
        return true;
      } else {
        debugPrint('[WinBleWiFi] ❌ Unpair failed');
        _lastError = 'Failed to unpair device';
        _setStatus('Unpair failed');
        return false;
      }
    } catch (e) {
      debugPrint('[WinBleWiFi] ❌ Unpair error: $e');
      _lastError = e.toString();
      _setStatus('Error unpairing: $e');
      return false;
    }
  }

  /// Provision WiFi credentials to already connected and paired device
  /// 
  /// [ssid]: WiFi network name
  /// [password]: WiFi password
  /// 
  /// Returns: true if provisioning succeeds
  Future<bool> provisionWiFiCredentials(String ssid, String password) async {
    if (_connectedDeviceAddress == null || !_isPaired) {
      _lastError = 'Device not connected or paired';
      debugPrint('[WinBleWiFi] ❌ $_lastError');
      return false;
    }

    final deviceAddress = _connectedDeviceAddress!;

    try {
      debugPrint('[WinBleWiFi] 📡 Starting WiFi provisioning');
      _lastError = null;

      // 1. Write SSID
      _setStatus('Writing SSID...');
      debugPrint('[WinBleWiFi] ✍️ Writing SSID: $ssid');
      
      final ssidWritten = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: ssidCharUuid,
        data: utf8.encode(ssid),
        writeWithResponse: true,
      );

      if (!ssidWritten) {
        _lastError = 'Failed to write SSID';
        throw Exception(_lastError);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Write Password
      _setStatus('Writing password...');
      debugPrint('[WinBleWiFi] ✍️ Writing password (${password.length} chars)');
      
      final pskWritten = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: pskCharUuid,
        data: utf8.encode(password),
        writeWithResponse: true,
      );

      if (!pskWritten) {
        _lastError = 'Failed to write password';
        throw Exception(_lastError);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Send CONNECT command
      _setStatus('Sending connect command...');
      debugPrint('[WinBleWiFi] ✍️ Sending CONNECT command');
      
      final commandSent = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: controlCharUuid,
        data: [cmdConnect],
        writeWithResponse: true,
      );

      if (!commandSent) {
        _lastError = 'Failed to send connect command';
        throw Exception(_lastError);
      }

      // 4. Monitor status
      _setStatus('Monitoring connection status...');
      debugPrint('[WinBleWiFi] ⏳ Monitoring WiFi connection (30 seconds)');
      
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        
        final statusData = await _winBle.readCharacteristic(
          deviceAddress: deviceAddress,
          serviceId: serviceUuid,
          characteristicId: statusCharUuid,
        );

        if (statusData != null && statusData.isNotEmpty) {
          final statusCode = statusData[0];
          final statusText = statusCodes[statusCode] ?? 'Unknown (0x${statusCode.toRadixString(16)})';
          
          debugPrint('[WinBleWiFi] Status: $statusText');
          _setStatus('Status: $statusText');

          // Check for success
          if (statusCode == 0x07) {
            debugPrint('[WinBleWiFi] 🎉 WiFi provisioning successful!');
            _setStatus('WiFi provisioning successful!');
            return true;
          }

          // Check for failure
          if (statusCode >= 0xF0) {
            _lastError = 'WiFi provisioning failed: $statusText';
            throw Exception(_lastError);
          }
        }
      }

      // Timeout
      debugPrint('[WinBleWiFi] ⏱️ Status monitoring timeout');
      _lastError = 'Monitoring timeout - check device';
      _setStatus(_lastError!);
      return false;

    } catch (e) {
      debugPrint('[WinBleWiFi] ❌ Error: $e');
      _lastError = e.toString();
      _setStatus('Error: $e');
      return false;
    }
  }

  /// Provision WiFi credentials to MeDUSA device
  /// (Legacy method - does connect, pair, and provision in one step)
  /// 
  /// [deviceAddress]: BLE device address (MAC)
  /// [ssid]: WiFi network name
  /// [password]: WiFi password
  /// 
  /// Returns: true if provisioning succeeds
  Future<bool> provisionWiFi({
    required String deviceAddress,
    required String ssid,
    required String password,
  }) async {
    try {
      debugPrint('[WinBleWiFi] 🚀 Starting WiFi provisioning for $deviceAddress');
      
      // 1. Initialize
      await _winBle.initialize();
      
      // 2. Pair FIRST (before connecting) - CRITICAL for Windows
      _setStatus('Pairing...');
      debugPrint('[WinBleWiFi] 🔐 Starting pairing (BEFORE connection)');
      debugPrint('[WinBleWiFi] 🔐 Windows PIN dialog will appear');
      debugPrint('[WinBleWiFi] 📱 Check Raspberry Pi OLED for 6-digit PIN');
      
      // PIN input dialog is now handled by the UI layer
      // No need to call it here as it's handled in wifi_provision_page.dart
      
      final paired = await _winBle.pairDevice(deviceAddress);
      if (!paired) {
        throw Exception('Pairing failed - user may have cancelled');
      }
      _isPaired = true;
      debugPrint('[WinBleWiFi] ✅ Pairing successful');

      // 3. Connect (AFTER successful pairing)
      _setStatus('Connecting to device...');
      debugPrint('[WinBleWiFi] 🔌 Connecting to paired device...');
      
      final connected = await _winBle.connect(deviceAddress);
      if (!connected) {
        throw Exception('Failed to connect to device');
      }
      _connectedDeviceAddress = deviceAddress;
      debugPrint('[WinBleWiFi] ✅ Connected');

      // Small delay to ensure pairing is complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // 4. Discover services
      _setStatus('Discovering services...');
      final services = await _winBle.discoverServices(deviceAddress);
      debugPrint('[WinBleWiFi] 🔍 Discovered ${services.length} service(s)');

      // Verify WiFi Helper service exists
      final hasWiFiService = services.any((service) {
        try {
          final uuid = (service as dynamic).uuid as String?;
          if (uuid == null) return false;
          return uuid.toLowerCase().replaceAll('-', '') == 
                 serviceUuid.toLowerCase().replaceAll('-', '');
        } catch (e) {
          return false;
        }
      });
      
      if (!hasWiFiService) {
        throw Exception('WiFi Helper service not found');
      }
      debugPrint('[WinBleWiFi] ✅ WiFi Helper service found');

      // 5. Write SSID
      _setStatus('Writing SSID...');
      debugPrint('[WinBleWiFi] ✍️ Writing SSID: $ssid');
      
      final ssidWritten = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: ssidCharUuid,
        data: utf8.encode(ssid),
        writeWithResponse: true,
      );

      if (!ssidWritten) {
        throw Exception('Failed to write SSID');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // 6. Write Password
      _setStatus('Writing password...');
      debugPrint('[WinBleWiFi] ✍️ Writing password (${password.length} chars)');
      
      final pskWritten = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: pskCharUuid,
        data: utf8.encode(password),
        writeWithResponse: true,
      );

      if (!pskWritten) {
        throw Exception('Failed to write password');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // 7. Send CONNECT command
      _setStatus('Sending connect command...');
      debugPrint('[WinBleWiFi] ✍️ Sending CONNECT command');
      
      final commandSent = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: controlCharUuid,
        data: [cmdConnect],
        writeWithResponse: true,
      );

      if (!commandSent) {
        throw Exception('Failed to send connect command');
      }

      // 8. Monitor status
      _setStatus('Monitoring connection status...');
      debugPrint('[WinBleWiFi] ⏳ Monitoring WiFi connection (30 seconds)');
      
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        
        final statusData = await _winBle.readCharacteristic(
          deviceAddress: deviceAddress,
          serviceId: serviceUuid,
          characteristicId: statusCharUuid,
        );

        if (statusData != null && statusData.isNotEmpty) {
          final statusCode = statusData[0];
          final statusText = statusCodes[statusCode] ?? 'Unknown (0x${statusCode.toRadixString(16)})';
          
          debugPrint('[WinBleWiFi] Status: $statusText');
          _setStatus('Status: $statusText');

          // Check for success
          if (statusCode == 0x07) {
            debugPrint('[WinBleWiFi] 🎉 WiFi provisioning successful!');
            _setStatus('WiFi provisioning successful!');
            return true;
          }

          // Check for failure
          if (statusCode >= 0xF0) {
            throw Exception('WiFi provisioning failed: $statusText');
          }
        }
      }

      // Timeout
      debugPrint('[WinBleWiFi] ⏱️ Status monitoring timeout');
      _setStatus('Monitoring timeout - check device');
      return false;

    } catch (e) {
      debugPrint('[WinBleWiFi] ❌ Error: $e');
      _setStatus('Error: $e');
      return false;
    } finally {
      // Cleanup
      if (_connectedDeviceAddress != null) {
        await _winBle.disconnect(_connectedDeviceAddress!);
        _connectedDeviceAddress = null;
      }
    }
  }

  /// Read current WiFi status
  Future<String?> readStatus(String deviceAddress) async {
    try {
      final statusData = await _winBle.readCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: statusCharUuid,
      );

      if (statusData != null && statusData.isNotEmpty) {
        final statusCode = statusData[0];
        return statusCodes[statusCode] ?? 'Unknown (0x${statusCode.toRadixString(16)})';
      }

      return null;
    } catch (e) {
      debugPrint('[WinBleWiFi] Failed to read status: $e');
      return null;
    }
  }

  /// Clear WiFi credentials
  Future<bool> clearCredentials(String deviceAddress) async {
    try {
      debugPrint('[WinBleWiFi] 🗑️ Clearing credentials');
      
      final success = await _winBle.writeCharacteristic(
        deviceAddress: deviceAddress,
        serviceId: serviceUuid,
        characteristicId: controlCharUuid,
        data: [cmdClear],
        writeWithResponse: true,
      );

      if (success) {
        debugPrint('[WinBleWiFi] ✅ Credentials cleared');
        _setStatus('Credentials cleared');
      }

      return success;
    } catch (e) {
      debugPrint('[WinBleWiFi] Failed to clear credentials: $e');
      return false;
    }
  }

  void _setStatus(String status) {
    _status = status;
    _statusController.add(status);
    notifyListeners();
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_connectedDeviceAddress != null) {
      await _winBle.disconnect(_connectedDeviceAddress!);
      _connectedDeviceAddress = null;
      _isPaired = false;
      _setStatus('Disconnected');
    }
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}