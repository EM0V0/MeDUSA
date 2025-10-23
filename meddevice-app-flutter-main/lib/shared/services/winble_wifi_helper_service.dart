import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  WinBleWiFiHelperService._internal();

  final WinBleService _winBle = WinBleService();

  // WiFi Helper GATT Service UUIDs
  static const String SERVICE_UUID = 'c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String SSID_CHAR_UUID = 'c0de0001-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String PSK_CHAR_UUID = 'c0de0002-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String CONTROL_CHAR_UUID = 'c0de0003-7e1a-4f83-bf3a-0c0ffee0c0de';
  static const String STATUS_CHAR_UUID = 'c0de0004-7e1a-4f83-bf3a-0c0ffee0c0de';

  // Control commands
  static const int CMD_CONNECT = 0x01;
  static const int CMD_CLEAR = 0x02;
  static const int CMD_FACTORY_RESET = 0x03;

  // Status codes
  static const Map<int, String> STATUS_CODES = {
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
      
      // 2. Connect
      _setStatus('Connecting to device...');
      final connected = await _winBle.connect(deviceAddress);
      if (!connected) {
        _lastError = 'Failed to connect to device';
        throw Exception(_lastError);
      }
      _connectedDeviceAddress = deviceAddress;
      debugPrint('[WinBleWiFi] ✅ Connected');

      // 3. Pair (triggers Windows PIN dialog)
      _setStatus('Pairing...');
      debugPrint('[WinBleWiFi] 🔐 Starting pairing (Windows PIN dialog will appear)');
      debugPrint('[WinBleWiFi] 📱 Check Raspberry Pi OLED for 6-digit PIN');
      
      final paired = await _winBle.pairDevice(deviceAddress);
      if (!paired) {
        _lastError = 'Pairing failed - user may have cancelled';
        throw Exception(_lastError);
      }
      _isPaired = true;
      debugPrint('[WinBleWiFi] ✅ Pairing successful');

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
                 SERVICE_UUID.toLowerCase().replaceAll('-', '');
        } catch (e) {
          return false;
        }
      });
      
      if (!hasWiFiService) {
        _lastError = 'WiFi Helper service not found';
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
        serviceId: SERVICE_UUID,
        characteristicId: SSID_CHAR_UUID,
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
        serviceId: SERVICE_UUID,
        characteristicId: PSK_CHAR_UUID,
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
        serviceId: SERVICE_UUID,
        characteristicId: CONTROL_CHAR_UUID,
        data: [CMD_CONNECT],
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
          serviceId: SERVICE_UUID,
          characteristicId: STATUS_CHAR_UUID,
        );

        if (statusData != null && statusData.isNotEmpty) {
          final statusCode = statusData[0];
          final statusText = STATUS_CODES[statusCode] ?? 'Unknown (0x${statusCode.toRadixString(16)})';
          
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
      
      // 2. Connect
      _setStatus('Connecting to device...');
      final connected = await _winBle.connect(deviceAddress);
      if (!connected) {
        throw Exception('Failed to connect to device');
      }
      _connectedDeviceAddress = deviceAddress;
      debugPrint('[WinBleWiFi] ✅ Connected');

      // 3. Pair (triggers Windows PIN dialog)
      _setStatus('Pairing...');
      debugPrint('[WinBleWiFi] 🔐 Starting pairing (Windows PIN dialog will appear)');
      debugPrint('[WinBleWiFi] 📱 Check Raspberry Pi OLED for 6-digit PIN');
      
      final paired = await _winBle.pairDevice(deviceAddress);
      if (!paired) {
        throw Exception('Pairing failed - user may have cancelled');
      }
      _isPaired = true;
      debugPrint('[WinBleWiFi] ✅ Pairing successful');

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
                 SERVICE_UUID.toLowerCase().replaceAll('-', '');
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
        serviceId: SERVICE_UUID,
        characteristicId: SSID_CHAR_UUID,
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
        serviceId: SERVICE_UUID,
        characteristicId: PSK_CHAR_UUID,
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
        serviceId: SERVICE_UUID,
        characteristicId: CONTROL_CHAR_UUID,
        data: [CMD_CONNECT],
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
          serviceId: SERVICE_UUID,
          characteristicId: STATUS_CHAR_UUID,
        );

        if (statusData != null && statusData.isNotEmpty) {
          final statusCode = statusData[0];
          final statusText = STATUS_CODES[statusCode] ?? 'Unknown (0x${statusCode.toRadixString(16)})';
          
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
        serviceId: SERVICE_UUID,
        characteristicId: STATUS_CHAR_UUID,
      );

      if (statusData != null && statusData.isNotEmpty) {
        final statusCode = statusData[0];
        return STATUS_CODES[statusCode] ?? 'Unknown (0x${statusCode.toRadixString(16)})';
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
        serviceId: SERVICE_UUID,
        characteristicId: CONTROL_CHAR_UUID,
        data: [CMD_CLEAR],
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

