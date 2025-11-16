import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

/// Facade that forwards FlutterBluePlus calls to the Windows implementation
/// powered by win_ble when the app is running on desktop. Other platforms use
/// the default FlutterBluePlus backend.
class FlutterBlueAdapter {
  static bool get _useWindows => !kIsWeb && Platform.isWindows;

  static Future<bool> get isSupported async {
    if (_useWindows) {
      // On Windows, use win_ble to check support
      // win_ble doesn't have a direct isSupported check, so we assume it's supported
      // if we can initialize (which is checked during actual initialization)
      return true;
    }
    return fb.FlutterBluePlus.isSupported;
  }

  static Stream<fb.BluetoothAdapterState> get adapterState {
    if (_useWindows) {
      // On Windows, return a stream that emits 'unknown' state
      // This is acceptable for Windows as win_ble handles state internally
      return Stream.value(fb.BluetoothAdapterState.unknown).asBroadcastStream();
    }
    return fb.FlutterBluePlus.adapterState;
  }

  static Stream<List<fb.ScanResult>> get scanResults {
    if (_useWindows) {
      // On Windows, win_ble is used directly in bluetooth_service.dart
      // Return an empty stream as a placeholder
      // The actual scanning is handled by win_ble in bluetooth_service.dart
      return Stream.value(<fb.ScanResult>[]).asBroadcastStream();
    }
    return fb.FlutterBluePlus.scanResults;
  }

  static List<fb.BluetoothDevice> get connectedDevices {
    if (_useWindows) {
      // On Windows, return empty list as win_ble handles connections differently
      return [];
    }
    return fb.FlutterBluePlus.connectedDevices;
  }

  static Future<void> startScan({
    List<fb.Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    Duration? timeout,
    bool androidUsesFineLocation = false,
  }) async {
    if (_useWindows) {
      // On Windows, scanning is handled by win_ble directly in bluetooth_service.dart
      // This is a no-op here to maintain API compatibility
      debugPrint('[FlutterBlueAdapter] Windows: startScan is handled by win_ble');
      return;
    }
    await fb.FlutterBluePlus.startScan(
      withServices: withServices,
      withRemoteIds: withRemoteIds,
      withNames: withNames,
      timeout: timeout,
      androidUsesFineLocation: androidUsesFineLocation,
    );
  }

  static Future<void> stopScan() async {
    if (_useWindows) {
      // On Windows, scanning is handled by win_ble directly in bluetooth_service.dart
      // This is a no-op here to maintain API compatibility
      debugPrint('[FlutterBlueAdapter] Windows: stopScan is handled by win_ble');
      return;
    }
    await fb.FlutterBluePlus.stopScan();
  }
}
