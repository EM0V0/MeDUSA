import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart'
    as fb_win;

/// Facade that forwards FlutterBluePlus calls to the Windows implementation
/// powered by win_ble when the app is running on desktop. Other platforms use
/// the default FlutterBluePlus backend.
/// 
/// For Web platform, this adapter provides limited functionality as Web Bluetooth
/// has a different paradigm (user-triggered device selection). Use WebBleService
/// directly for full Web Bluetooth support.
class FlutterBlueAdapter {
  static bool get _useWindows => !kIsWeb && Platform.isWindows;
  static bool get _isWeb => kIsWeb;

  static Future<bool> get isSupported async {
    if (_isWeb) {
      // Web Bluetooth is handled separately via WebBleService
      // Return true to not block initialization
      return true;
    }
    return _useWindows
        ? fb_win.FlutterBluePlusWindows.isSupported
        : fb.FlutterBluePlus.isSupported;
  }

  static Stream<fb.BluetoothAdapterState> get adapterState {
    if (_isWeb) {
      // Web doesn't have direct adapter state access
      // Return a stream that indicates unknown state
      return Stream.value(fb.BluetoothAdapterState.unknown);
    }
    return _useWindows
        ? fb_win.FlutterBluePlusWindows.adapterState
        : fb.FlutterBluePlus.adapterState;
  }

  static Stream<List<fb.ScanResult>> get scanResults {
    if (_isWeb) {
      // Web Bluetooth doesn't support scan results stream
      // Device selection is done through requestDevice() dialog
      return Stream.value([]);
    }
    return _useWindows
        ? fb_win.FlutterBluePlusWindows.scanResults
        : fb.FlutterBluePlus.scanResults;
  }

  static List<fb.BluetoothDevice> get connectedDevices {
    if (_isWeb) {
      // Web Bluetooth doesn't expose connected devices list in the same way
      return [];
    }
    return _useWindows
        ? fb_win.FlutterBluePlusWindows.connectedDevices
        : fb.FlutterBluePlus.connectedDevices;
  }

  static Future<void> startScan({
    List<fb.Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    Duration? timeout,
    bool androidUsesFineLocation = false,
  }) async {
    if (_isWeb) {
      // Web Bluetooth doesn't support startScan
      // Use WebBleService.requestDevice() instead
      throw UnsupportedError(
        'Web Bluetooth does not support background scanning. '
        'Use WebBleService.requestDevice() to show device picker dialog.',
      );
    }
    
    if (_useWindows) {
      await fb_win.FlutterBluePlusWindows.startScan(
        withServices: withServices,
        withRemoteIds: withRemoteIds,
        withNames: withNames,
        timeout: timeout,
      );
    } else {
      await fb.FlutterBluePlus.startScan(
        withServices: withServices,
        withRemoteIds: withRemoteIds,
        withNames: withNames,
        timeout: timeout,
        androidUsesFineLocation: androidUsesFineLocation,
      );
    }
  }

  static Future<void> stopScan() async {
    if (_isWeb) {
      // No-op for web
      return;
    }
    
    if (_useWindows) {
      await fb_win.FlutterBluePlusWindows.stopScan();
    } else {
      await fb.FlutterBluePlus.stopScan();
    }
  }
}