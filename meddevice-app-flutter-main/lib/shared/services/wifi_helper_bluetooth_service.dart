import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    as flutter_blue_plus;
import 'package:medusa_app/shared/bluetooth/flutter_blue_adapter.dart';
import 'package:medusa_app/shared/pairing/pairing_manager.dart';
import 'package:win_ble/win_ble.dart' as win_ble;

/// WiFi Helper Bluetooth Service for MeDUSA Raspberry Pi
/// Implements LESC pairing and WiFi credential provisioning via BLE
///
/// Based on: MeDUSA_BLETest-master/Program.cs (C# implementation)
typedef BleDevice = flutter_blue_plus.BluetoothDevice;
typedef BleService = flutter_blue_plus.BluetoothService;
typedef BleCharacteristic = flutter_blue_plus.BluetoothCharacteristic;

class WiFiHelperBluetoothService extends ChangeNotifier {
  // ====================================================================
  // UUIDs from MeDUSA WiFi Helper GATT service
  // ====================================================================
  static const String serviceUuid = "c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de";
  static const String ssidCharUuid = "c0de0001-7e1a-4f83-bf3a-0c0ffee0c0de";
  static const String pskCharUuid = "c0de0002-7e1a-4f83-bf3a-0c0ffee0c0de";
  static const String controlCharUuid = "c0de0003-7e1a-4f83-bf3a-0c0ffee0c0de";
  static const String statusCharUuid = "c0de0004-7e1a-4f83-bf3a-0c0ffee0c0de";

  // ====================================================================
  // Control commands
  // ====================================================================
  static const int cmdConnect = 0x01;
  static const int cmdClear = 0x02;
  static const int cmdFactoryReset = 0x03;

  // ====================================================================
  // Status codes (from test_wifi_helper.py)
  // ====================================================================
  static const Map<int, String> statusCodes = {
    0x01: "Idle",
    0x02: "Pairing",
    0x03: "Ready",
    0x04: "Connecting to network",
    0x05: "Authenticating",
    0x06: "Obtaining IP address",
    0x07: "Success",
    0xF0: "Pairing failed",
    0xF1: "Authentication failed",
    0xF2: "Network failed",
    0xFF: "Internal failure"
  };

  static const Map<int, String> _commandNames = {
    cmdConnect: 'CONNECT',
    cmdClear: 'CLEAR',
    cmdFactoryReset: 'FACTORY_RESET',
  };

  // ====================================================================
  // State
  // ====================================================================
  BleDevice? _connectedDevice;
  BleCharacteristic? _ssidChar;
  BleCharacteristic? _pskChar;
  BleCharacteristic? _controlChar;
  BleCharacteristic? _statusChar;

  bool _isConnected = false;
  bool _isPaired = false;
  String _connectionStatus = 'Disconnected';
  String? _lastError;

  StreamSubscription? _connectionStateSubscription;
  StreamSubscription<bool>? _winBleConnectionSubscription;

  // ====================================================================
  // Getters
  // ====================================================================
  bool get isConnected => _isConnected;
  bool get isPaired => _isPaired;
  String get connectionStatus => _connectionStatus;
  String? get lastError => _lastError;
  BleDevice? get connectedDevice => _connectedDevice;

  // Status stream
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // ====================================================================
  // Scan for MeDUSA WiFi Helper device
  // ====================================================================
  /// Scans for BLE devices with "medusa" in the name
  ///
  /// CRITICAL: Web Bluetooth vs Mobile Behavior
  /// ---------------------------------------
  /// MOBILE (Android/iOS):
  ///   - startScan() does background scanning
  ///   - scanResults stream provides all discovered devices
  ///   - We can programmatically filter devices
  ///
  /// WEB (Chrome):
  ///   - startScan() triggers browser's device picker dialog
  ///   - USER MUST MANUALLY SELECT device from list
  ///   - scanResults returns ONLY the device user selected
  ///   - withServices filter helps show relevant devices in picker
  ///
  /// This matches Program.cs behavior where watcher.Received gets ALL devices
  /// but Web Bluetooth requires user interaction for security.
  Future<List<BleDevice>> scanForDevices(
      {Duration timeout = const Duration(seconds: 10)}) async {
    List<BleDevice> foundDevices = [];

    try {
      _setStatus('🔍 Scanning for MeDUSA devices...');
      debugPrint('📡 [Scan] Starting BLE scan for MeDUSA WiFi Helper');

      // Check if Bluetooth is supported
      if (!await FlutterBlueAdapter.isSupported) {
        _setError('Bluetooth not supported on this device');
        return [];
      }

      // Check if Bluetooth is enabled
      final adapterState = await FlutterBlueAdapter.adapterState.first;

      if (adapterState != flutter_blue_plus.BluetoothAdapterState.on) {
        _setError('Please enable Bluetooth');
        return [];
      }

      final targetServiceUuid = flutter_blue_plus.Guid("c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de");

      // Do NOT use withServices filter - many devices don't advertise services in broadcast
      // We filter by device name "medusa" instead
      await FlutterBlueAdapter.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      debugPrint('�?Scan started');
      debugPrint('�?Waiting for scan results...');

      // Collect scan results
      // NOTE: On Web, this will only contain devices user manually selected
      // On Mobile, this contains all discovered devices
      final subscription = FlutterBlueAdapter.scanResults.listen((results) {
        debugPrint('📱 Received ${results.length} scan result(s)');

        for (var result in results) {
          final device = result.device;
          final name = device.platformName;
          final advName = result.advertisementData.advName;
          final rssi = result.rssi;

          debugPrint('─'.padRight(60, '─'));
          debugPrint('Device found:');
          debugPrint('  Platform Name: "$name"');
          debugPrint('  Adv Name: "$advName"');
          debugPrint('  Remote ID: ${device.remoteId}');
          debugPrint('  RSSI: $rssi dBm');
          debugPrint('  Services: ${result.advertisementData.serviceUuids}');

          // Check if this is a MeDUSA device
          final nameLower = name.toLowerCase();
          final advNameLower = advName.toLowerCase();

          // Look for "medusa" in device name OR check if it advertises our service UUID
          final hasWiFiHelperService = result.advertisementData.serviceUuids
              .contains(flutter_blue_plus.Guid("c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de"));

          debugPrint(
              '  Contains "medusa" in name: ${nameLower.contains('medusa') || advNameLower.contains('medusa')}');
          debugPrint('  Advertises WiFi Helper service: $hasWiFiHelperService');

          if ((nameLower.contains('medusa') ||
                  advNameLower.contains('medusa') ||
                  hasWiFiHelperService) &&
              !foundDevices.any((d) => d.remoteId == device.remoteId)) {
            foundDevices.add(device);
            debugPrint('�?Added to MeDUSA device list');
          } else {
            debugPrint('  Skipped (not a MeDUSA device)');
          }
        }
      });

      // Wait for scan to complete
      debugPrint('�?Scan running for ${timeout.inSeconds} seconds...');
      await Future.delayed(timeout);

      debugPrint('⏹️ Stopping scan...');
      await FlutterBlueAdapter.stopScan();
      await subscription.cancel();

      debugPrint('='.padRight(60, '='));
      debugPrint(
          'Scan complete. Found ${foundDevices.length} MeDUSA device(s)');
      if (foundDevices.isEmpty) {
        debugPrint('�?No MeDUSA devices found');
        debugPrint('');
        debugPrint('Troubleshooting:');
        debugPrint('  1. On WEB: Did you SELECT a device from browser dialog?');
        debugPrint('  2. Is medusa_wifi_helper running on Pi?');
        debugPrint('  3. Is Pi advertising the WiFi Helper service UUID?');
        debugPrint('  4. Check Pi logs: journalctl -u medusa_wifi_helper');
      } else {
        for (var device in foundDevices) {
          debugPrint('  �?${device.platformName} (${device.remoteId})');
        }
      }
      debugPrint('='.padRight(60, '='));

      _setStatus(foundDevices.isEmpty
          ? '⚠️ No devices found'
          : '�?Found ${foundDevices.length} device(s)');

      return foundDevices;
    } catch (e) {
      debugPrint('�?Scan error: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      _setError('Scan failed: $e');
      return [];
    }
  }

  // ====================================================================
  // Connect and pair with device
  // ====================================================================
  /// Connects to device and initiates LESC pairing if needed
  /// This mirrors the ConnectToDevice() method from Program.cs
  Future<bool> connectAndPair(BleDevice device) async {
    final pairingManager = PairingManager.instance;

    try {
      _setStatus('Connecting to ${device.platformName}...');

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _isConnected = true;
      _resetGattHandles();

      debugPrint('[BLE] Connected to ${device.platformName}');

      _connectionStateSubscription = device.connectionState.listen(
        (state) {
          if (state == flutter_blue_plus.BluetoothConnectionState.disconnected) {
            _handleDisconnection();
          }
        },
      );
      if (Platform.isWindows) {
        _winBleConnectionSubscription?.cancel();
        final address = device.remoteId.str;
        _winBleConnectionSubscription = win_ble.WinBle.connectionStreamOf(address).listen(
          (connected) {
            debugPrint("[BLE][Win] connection update for $address: $connected");
          },
          onError: (error) {
            debugPrint("[BLE][Win] connection stream error: $error");
          },
        );
      }

      if (!await _discoverServices(device)) {
        throw Exception('Failed to discover WiFi Helper service');
      }

      bool paired = false;
      try {
        paired = await pairingManager.isPaired(device);
      } on PairingException catch (e) {
        debugPrint('[BLE] Unable to determine pairing state: $e');
        if (e.requiresManualSteps) {
          _setError(e.message);
          return false;
        }
      }

      if (!paired) {
        _setStatus('Secure pairing required. Waiting for confirmation...');
        try {
          paired = await pairingManager.ensurePaired(
            device,
            requireMitm: true,
          );
        } on PairingException catch (e) {
          _setError(e.message);
          return false;
        }

        if (!paired) {
          _setError('Pairing did not complete. Please retry.');
          return false;
        }

        _resetGattHandles();
        if (!await _discoverServices(device)) {
          _setError(
            'Failed to refresh Bluetooth services after pairing completed.',
          );
          return false;
        }
      }

      final verified = await verifyPairingStatus();
      if (!verified) {
        _isPaired = false;
        _setError(
          'Secure channel verification failed. Confirm the pairing prompt and try again.',
        );
        return false;
      }

      _isPaired = true;
      _setStatus('Connected to ${device.platformName}');
      return true;
    } catch (e, stack) {
      debugPrint('[BLE] Connection workflow failed: $e');
      debugPrint(stack.toString());
      _setError('Connection failed: $e');
      await disconnect();
      return false;
    }
  }

  // ====================================================================
  // Discover WiFi Helper GATT services
  // ====================================================================
  /// Discovers GATT services and maps characteristics
  /// Mirrors DiscoverServices() from Program.cs
  Future<bool> _discoverServices(BleDevice device) async {
    try {
      debugPrint('🔍 Discovering services...');
      debugPrint('   Target Service UUID: $serviceUuid');

      // WEB BLUETOOTH: Service discovery requires the service to be declared in requestDevice()
      // If we get a SecurityError, it means the service wasn't properly advertised by Pi
      // or wasn't included in the scan filter
      List<BleService> services;
      try {
        services = await device.discoverServices();
        debugPrint('�?discoverServices() returned ${services.length} services');
      } catch (e) {
        debugPrint('�?discoverServices() failed: $e');

        final message = e.toString();
        if (message.contains('SecurityError') ||
            message.contains('not allowed to access')) {
          debugPrint('');
          debugPrint('=== WEB BLUETOOTH SECURITY ERROR ===');
          debugPrint('TROUBLESHOOTING:');
          debugPrint('1. Chrome caches Bluetooth permissions per origin.');
          debugPrint('2. Clear cached permissions:');
          debugPrint('   �?In Chrome, click address bar lock icon �?Site settings �?Bluetooth');
          debugPrint('   �?Or: Chrome Settings �?Privacy and security �?Site Settings �?Bluetooth');
          debugPrint('   �?Remove all MeDUSA-Helper entries');
          debugPrint('3. Pair at OS level:');
          debugPrint('   �?Windows Settings �?Bluetooth & devices �?Add device');
          debugPrint('   �?Select MeDUSA-Helper and confirm 6-digit PIN on both devices');
          debugPrint('4. Close ALL Chrome windows completely (check Task Manager).');
          debugPrint('5. Restart Chrome and retry provisioning from a fresh session.');
          debugPrint('');
          _setError(
            'Web Bluetooth blocked access to encrypted services. '
            'Chrome cached an earlier permission without the WiFi service UUID. '
            'Fix: Click address bar lock �?Site settings �?Bluetooth, remove MeDUSA-Helper. '
            'Then pair in Windows Bluetooth settings, close ALL Chrome windows, and retry.',
          );
          return false;
        }
        if (message.contains('Pi is not advertising WiFi Helper service')) {
          throw Exception('Pi is not advertising WiFi Helper service. '
              'Please check medusa_wifi_helper service on Pi.');
        }
        rethrow;
      }

      // === DEEP DIAGNOSTIC: List ALL discovered services ===
      debugPrint('');
      debugPrint('=== SERVICE DISCOVERY DIAGNOSTIC ===');
      debugPrint('Total services discovered: ${services.length}');
      if (services.isEmpty) {
        debugPrint('⚠️ WARNING: No services returned by discoverServices()!');
        debugPrint('');
        debugPrint('POSSIBLE REASONS:');
        debugPrint('1. Pi GATT server not running');
        debugPrint('2. Connection dropped before service discovery');
        debugPrint('3. Pi BLE service registration failed');
        debugPrint('');
        throw Exception(
            'No GATT services discovered - Pi may not be running WiFi Helper service');
      }

      for (var i = 0; i < services.length; i++) {
        final svc = services[i];
        final svcUuidStr = svc.uuid.toString();
        final svcUuidLower = svcUuidStr.toLowerCase();
        final targetUuidLower = serviceUuid.toLowerCase();

        debugPrint('Service #$i:');
        debugPrint('  UUID (raw):       $svcUuidStr');
        debugPrint('  UUID (lowercase): $svcUuidLower');
        debugPrint('  Characteristics:  ${svc.characteristics.length}');

        // Check if this is our target service
        if (svcUuidLower == targetUuidLower) {
          debugPrint('  �?MATCH! This is the WiFi Helper service');
        } else {
          debugPrint('  �?Not a match');
          // Show character-by-character comparison for debugging
          if (svcUuidLower.length != targetUuidLower.length) {
            debugPrint(
                '  Length mismatch: ${svcUuidLower.length} vs ${targetUuidLower.length}');
          } else {
            // Find first difference
            for (var j = 0; j < svcUuidLower.length; j++) {
              if (svcUuidLower[j] != targetUuidLower[j]) {
                debugPrint(
                    '  First diff at position $j: "${svcUuidLower[j]}" vs "${targetUuidLower[j]}"');
                debugPrint(
                    '  Actual:   "${svcUuidLower.substring(0, j + 10)}"...');
                debugPrint(
                    '  Expected: "${targetUuidLower.substring(0, j + 10)}"...');
                break;
              }
            }
          }
        }
      }
      debugPrint('=== END DIAGNOSTIC ===');
      debugPrint('');

      // Find WiFi Helper service with enhanced matching
      BleService? wifiService;
      final normalizedTargetUuid = _normalizeUuid(serviceUuid);

      for (var service in services) {
        final normalizedServiceUuid = _normalizeUuid(service.uuid.toString());

        debugPrint('Comparing:');
        debugPrint('  Service:  "$normalizedServiceUuid"');
        debugPrint('  Target:   "$normalizedTargetUuid"');
        debugPrint(
            '  Match:    ${normalizedServiceUuid == normalizedTargetUuid}');

        if (normalizedServiceUuid == normalizedTargetUuid) {
          wifiService = service;
          debugPrint('�?Found WiFi Helper service!');
          break;
        }
      }

      if (wifiService == null) {
        debugPrint('');
        debugPrint('�?CRITICAL: WiFi Helper service NOT FOUND');
        debugPrint('');
        debugPrint('=== AVAILABLE SERVICES ===');
        for (var service in services) {
          debugPrint('  - ${service.uuid}');
        }
        debugPrint('');
        debugPrint('=== TROUBLESHOOTING ===');
        debugPrint('1. On Pi, verify service is registered:');
        debugPrint(
            '   sudo journalctl -u medusa_wifi_helper | grep "Registering GATT"');
        debugPrint('2. Expected output should show:');
        debugPrint(
            '   "Registering GATT service: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de"');
        debugPrint(
            '3. If not present, the Pi service is not correctly registering GATT');
        debugPrint('');
        throw Exception('WiFi Helper service not found in discovered services');
      }

      // Map characteristics with diagnostic
      debugPrint('');
      debugPrint('=== CHARACTERISTIC DISCOVERY ===');
      debugPrint(
          'Service has ${wifiService.characteristics.length} characteristics');

      for (var char in wifiService.characteristics) {
        final charUuid = _normalizeUuid(char.uuid.toString());
        debugPrint('Characteristic: $charUuid');
        debugPrint('  Properties: ${char.properties}');

        if (charUuid == _normalizeUuid(ssidCharUuid)) {
          _ssidChar = char;
          debugPrint('  �?SSID characteristic');
        } else if (charUuid == _normalizeUuid(pskCharUuid)) {
          _pskChar = char;
          debugPrint('  �?PSK characteristic');
        } else if (charUuid == _normalizeUuid(controlCharUuid)) {
          _controlChar = char;
          debugPrint('  �?Control characteristic');
        } else if (charUuid == _normalizeUuid(statusCharUuid)) {
          _statusChar = char;
          debugPrint('  �?Status characteristic');
        } else {
          debugPrint('  ⚠️ Unknown characteristic');
        }
      }

      // Verify all characteristics found
      debugPrint('');
      debugPrint('=== CHARACTERISTIC VERIFICATION ===');
      debugPrint('  SSID:    ${_ssidChar != null ? "�?Found" : "�?MISSING"}');
      debugPrint('  PSK:     ${_pskChar != null ? "�?Found" : "�?MISSING"}');
      debugPrint(
          '  Control: ${_controlChar != null ? "�?Found" : "�?MISSING"}');
      debugPrint('  Status:  ${_statusChar != null ? "�?Found" : "�?MISSING"}');

      if (_ssidChar == null ||
          _pskChar == null ||
          _controlChar == null ||
          _statusChar == null) {
        debugPrint('');
        debugPrint('�?CRITICAL: Missing required characteristics!');
        debugPrint('');
        debugPrint('This means:');
        debugPrint('1. Pi GATT service is incomplete');
        debugPrint('2. Not all characteristics were registered');
        debugPrint('3. Check Pi service implementation');
        debugPrint('');
        throw Exception(
            'Missing required characteristics - Pi service incomplete');
      }

      debugPrint('');
      debugPrint('�?SUCCESS: All WiFi Helper characteristics discovered');
      debugPrint('');
      return true;
    } catch (e) {
      debugPrint('');
      debugPrint('�?Service discovery FAILED: $e');
      debugPrint('');
      return false;
    }
  }

  /// Normalizes UUID string for comparison
  /// Handles different formats: with/without dashes, different cases
  String _normalizeUuid(String uuid) {
    // Convert to lowercase and remove all dashes
    return uuid.toLowerCase().replaceAll('-', '').trim();
  }

  // ====================================================================
  // Verify pairing status
  // ====================================================================
  Future<bool> verifyPairingStatus({bool forceRediscover = false}) async {
    if (!_isConnected || _connectedDevice == null) {
      _setError('Cannot verify pairing: no device connected.');
      return false;
    }

    final device = _connectedDevice!;
    final stillConnected = device.isConnected;
    if (!stillConnected) {
      _setError('Device disconnected while verifying pairing.');
      await disconnect();
      return false;
    }

    if (forceRediscover) {
      _ssidChar = null;
      _pskChar = null;
      _controlChar = null;
      _statusChar = null;
    }

    if (_statusChar == null) {
      if (!await _discoverServices(device)) {
        _setError('Unable to access WiFi Helper service on device.');
        return false;
      }
    }

    // IMPORTANT: Don't check properties before pairing!
    // Before pairing, all properties show as false even if they're actually readable
    // We must attempt the read to trigger Windows pairing dialog
    debugPrint('[Pairing] Attempting to read status characteristic...');
    debugPrint('[Pairing] This will trigger Windows pairing dialog if not paired');

    _setStatus('Verifying secure pairing status...');

    try {
      // Attempt to read - this will trigger pairing if needed
      await _statusChar!.read();
      _isPaired = true;
      debugPrint('[Pairing] ✅ Read successful - device is paired');
      _setStatus('Pairing verified - encrypted channel ready.');
      return true;
    } catch (e) {
      final errorStr = e.toString();
      final lower = errorStr.toLowerCase();
      _isPaired = false;

      debugPrint('[Pairing] ❌ Read failed: $errorStr');

      if (_isAuthenticationFailure(lower)) {
        debugPrint('[Pairing] Authentication failure detected - pairing required');
        _handlePairingRequired('verifying pairing status');
        return false;
      }

      if (_isConnectionFailure(lower)) {
        _setError(
          'Device disconnected while verifying pairing. '
          'Please reconnect and try again.',
        );
        await disconnect();
        return false;
      }

      _setError('Failed to verify pairing status: $errorStr');
      return false;
    }
  }

  // ====================================================================
  // Provision WiFi credentials
  // ====================================================================
  /// Provisions WiFi credentials to Raspberry Pi with retries and pairing checks
  Future<bool> provisionWiFi(String ssid, String password) async {
    debugPrint('');
    debugPrint('=== PROVISIONING WIFI ===');
    debugPrint('SSID: $ssid');
    debugPrint('Password length: ${password.length}');
    debugPrint('');

    if (ssid.trim().isEmpty || password.isEmpty) {
      _setError('SSID and password are required.');
      return false;
    }

    if (!_isConnected || _connectedDevice == null) {
      const error = 'Device not connected. Please connect before provisioning.';
      debugPrint('[BLE] $error');
      _setError(error);
      return false;
    }

    final missingChars = <String>[];
    if (_ssidChar == null) missingChars.add('SSID');
    if (_pskChar == null) missingChars.add('PSK');
    if (_controlChar == null) missingChars.add('Control');
    if (_statusChar == null) missingChars.add('Status');

    if (missingChars.isNotEmpty) {
      _setError(
        'Missing characteristics: ${missingChars.join(", ")}. '
        'Reconnect to the device to refresh GATT services.',
      );
      return false;
    }

    if (!_isPaired) {
      debugPrint(
          '[BLE] Pairing not yet verified, running check before writes.');
      final pairingVerified = await verifyPairingStatus();
      if (!pairingVerified) {
        return false;
      }
    }

    try {
      _setStatus('Step 1/3: Writing SSID...');
      debugPrint('[BLE] Step 1/3: Writing SSID (${ssid.length} chars)');
      if (!await _writeCharacteristic(
        _ssidChar!,
        ssid,
        characteristicLabel: 'SSID',
      )) {
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 300));

      _setStatus('Step 2/3: Writing password...');
      debugPrint(
          '[BLE] Step 2/3: Writing password (length ${password.length})');
      if (!await _writeCharacteristic(
        _pskChar!,
        password,
        characteristicLabel: 'password',
      )) {
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 300));

      _setStatus('Step 3/3: Sending CONNECT command...');
      debugPrint('[BLE] Step 3/3: Sending CONNECT command');
      if (!await _writeCommand(
        _controlChar!,
        cmdConnect,
      )) {
        return false;
      }

      _setStatus('Monitoring WiFi connection status...');
      final success =
          await _monitorConnectionStatus(const Duration(seconds: 30));

      if (success) {
        debugPrint('[BLE] WiFi provisioning completed successfully.');
        _setStatus('WiFi provisioning successful.');
        return true;
      }

      debugPrint('[BLE] WiFi provisioning did not complete successfully.');
      _setError('WiFi provisioning failed - check Raspberry Pi status.');
      return false;
    } catch (e) {
      debugPrint('[BLE] Provisioning error: $e');
      _setError('Provisioning error: $e');
      return false;
    }
  }

  void _handlePairingRequired(String context) {
    final message =
        'Pairing required before $context. Confirm the Raspberry Pi PIN and approve the Bluetooth pairing prompt.';
    debugPrint('[BLE] Pairing required: $context');
    _isPaired = false;
    _setStatus(message);
  }

  bool _isAuthenticationFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('authentication') ||
        lower.contains('insufficient') ||
        lower.contains('pair') ||
        lower.contains('bond') ||
        lower.contains('not authorized') ||
        lower.contains('0x05');
  }

  bool _isConnectionFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('disconnected') ||
        lower.contains('not connected') ||
        lower.contains('connection aborted') ||
        lower.contains('connection fail') ||
        lower.contains('unreachable') ||
        lower.contains('cancelled') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('link loss');
  }

  // ====================================================================
  // Write string to characteristic
  // ====================================================================
  /// Writes UTF-8 string to characteristic with response
  /// Mirrors WriteCharacteristic() from Program.cs
  Future<bool> _writeCharacteristic(
    BleCharacteristic char,
    String value, {
    String characteristicLabel = 'characteristic',
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final props = char.properties;
    if (!props.write && !props.writeWithoutResponse) {
      _setError(
        '$characteristicLabel characteristic is not writable on this device.',
      );
      return false;
    }

    final useWithoutResponse = props.write ? false : true;
    final bytes = utf8.encode(value);

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          '[BLE] Writing $characteristicLabel '
          '(attempt $attempt/$maxRetries, ${bytes.length} bytes)',
        );
        await char.write(bytes, withoutResponse: useWithoutResponse);
        debugPrint('[BLE] $characteristicLabel write successful');
        return true;
      } catch (e) {
        final errorStr = e.toString();
        final lower = errorStr.toLowerCase();
        debugPrint(
          '[BLE] $characteristicLabel write error on attempt '
          '$attempt: $errorStr',
        );

        if (_isAuthenticationFailure(lower)) {
          _handlePairingRequired('writing $characteristicLabel');
          return false;
        }

        if (_isConnectionFailure(lower)) {
          _setError(
            'Connection lost while writing $characteristicLabel. '
            'Please reconnect and try again.',
          );
          await disconnect();
          return false;
        }

        if (attempt == maxRetries) {
          _setError(
            'Failed to write $characteristicLabel after '
            '$maxRetries attempt(s): $errorStr',
          );
          return false;
        }

        debugPrint(
          '[BLE] Retrying $characteristicLabel write after '
          '${retryDelay.inMilliseconds} ms',
        );
        await Future.delayed(retryDelay);
      }
    }

    return false;
  }

  Future<bool> _monitorConnectionStatus(Duration timeout) async {
    if (_statusChar == null) return false;

    final seconds = timeout.inSeconds;

    for (var i = 0; i < seconds; i++) {
      await Future.delayed(const Duration(seconds: 1));

      try {
        final value = await _statusChar!.read();
        if (value.isNotEmpty) {
          final statusCode = value[0];
          final statusText = statusCodes[statusCode] ??
              'Unknown (0x${statusCode.toRadixString(16)})';

          _setStatus('[$i s] Status: $statusText');

          if (statusCode == 0x07) {
            debugPrint('[BLE] WiFi connection successful.');
            return true;
          } else if (statusCode >= 0xF0) {
            debugPrint('[BLE] WiFi connection failed: $statusText');
            return false;
          }
        }
      } catch (e) {
        debugPrint('Status read error: $e');
      }
    }

    _setStatus('Status monitoring timed out.');
    debugPrint(
      '[BLE] Monitoring timeout - check the Raspberry Pi for final status.',
    );
    return false;
  }

  // ====================================================================
  // Read current WiFi status
  // ====================================================================
  /// Reads and decodes current status from status characteristic
  Future<String?> readStatus() async {
    if (_statusChar == null) return null;

    try {
      final value = await _statusChar!.read();
      if (value.isNotEmpty) {
        final statusCode = value[0];
        return statusCodes[statusCode] ??
            'Unknown (0x${statusCode.toRadixString(16)})';
      }
    } catch (e) {
      debugPrint('Status read error: $e');
    }

    return null;
  }

  Future<bool> _writeCommand(
    BleCharacteristic char,
    int command, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    final commandLabel = _commandNames[command] ??
        '0x${command.toRadixString(16).toUpperCase()}';

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          '[BLE] Sending $commandLabel command '
          '(attempt $attempt/$maxRetries)',
        );
        await char.write([command], withoutResponse: false);
        debugPrint('[BLE] $commandLabel command sent');
        return true;
      } catch (e) {
        final errorStr = e.toString();
        final lower = errorStr.toLowerCase();
        debugPrint(
          '[BLE] $commandLabel command error on attempt '
          '$attempt: $errorStr',
        );

        if (_isAuthenticationFailure(lower)) {
          _handlePairingRequired('sending $commandLabel command');
          return false;
        }

        if (_isConnectionFailure(lower)) {
          _setError(
            'Connection lost while sending $commandLabel command. '
            'Please reconnect and try again.',
          );
          await disconnect();
          return false;
        }

        if (attempt == maxRetries) {
          _setError(
            'Failed to send $commandLabel command after '
            '$maxRetries attempt(s): $errorStr',
          );
          return false;
        }

        debugPrint(
          '[BLE] Retrying $commandLabel command after '
          '${retryDelay.inMilliseconds} ms',
        );
        await Future.delayed(retryDelay);
      }
    }

    return false;
  }

  // ====================================================================
  // Clear WiFi credentials
  // ====================================================================
  /// Sends clear command to Pi
  /// Mirrors ClearCredentials() from Program.cs
  Future<bool> clearCredentials() async {
    if (!_isConnected || _controlChar == null) {
      _setError('Device not connected');
      return false;
    }

    try {
      _setStatus('Clearing stored credentials...');

      if (await _writeCommand(_controlChar!, cmdClear)) {
        await Future.delayed(const Duration(seconds: 1));
        final status = await readStatus();
        _setStatus('Credentials cleared. Status: $status');
        return true;
      }

      return false;
    } catch (e) {
      _setError('Clear failed: $e');
      return false;
    }
  }

  // ====================================================================
  // Disconnect from device
  // ====================================================================
  /// Disconnects and cleans up resources
  /// Mirrors Cleanup() from Program.cs
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        _setStatus('Disconnecting...');
        await _connectionStateSubscription?.cancel();
    _winBleConnectionSubscription?.cancel();
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
    } finally {
      _handleDisconnection();
    }
  }

  // ====================================================================
  // Handle disconnection cleanup
  // ====================================================================
  void _resetGattHandles() {
    _ssidChar = null;
    _pskChar = null;
    _controlChar = null;
    _statusChar = null;
  }

  void _handleDisconnection() {
    debugPrint('🔌 Device disconnected - cleaning up');

    _connectedDevice = null;
    _resetGattHandles();
    _isConnected = false;
    _isPaired = false;
    _connectionStateSubscription?.cancel();
    _winBleConnectionSubscription?.cancel();

    _setStatus('Disconnected');
  }

  // ====================================================================
  // Status management
  // ====================================================================
  void _setStatus(String status) {
    _lastError = null;
    _connectionStatus = status;
    _statusController.add(status);
    debugPrint('WiFi Helper: $status');
    notifyListeners();
  }

  void _setError(String error) {
    _lastError = error;
    _connectionStatus = 'Error: $error';
    _statusController.add(_connectionStatus);
    debugPrint('WiFi Helper Error: $error');
    notifyListeners();
  }

  // ====================================================================
  // Dispose
  // ====================================================================
  @override
  void dispose() {
    disconnect();
    _statusController.close();
    super.dispose();
  }
}



