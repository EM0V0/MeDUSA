import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart'
    as fb_win;

/// Facade that forwards FlutterBluePlus calls to the Windows implementation
/// powered by win_ble when the app is running on desktop. Other platforms use
/// the default FlutterBluePlus backend.
class FlutterBlueAdapter {
  static bool get _useWindows => !kIsWeb && Platform.isWindows;

  static Future<bool> get isSupported async => _useWindows
      ? fb_win.FlutterBluePlusWindows.isSupported
      : fb.FlutterBluePlus.isSupported;

  static Stream<fb.BluetoothAdapterState> get adapterState => _useWindows
      ? fb_win.FlutterBluePlusWindows.adapterState
      : fb.FlutterBluePlus.adapterState;

  static Stream<List<fb.ScanResult>> get scanResults => _useWindows
      ? fb_win.FlutterBluePlusWindows.scanResults
      : fb.FlutterBluePlus.scanResults;

  static List<fb.BluetoothDevice> get connectedDevices => _useWindows
      ? fb_win.FlutterBluePlusWindows.connectedDevices
      : fb.FlutterBluePlus.connectedDevices;

  static Future<void> startScan({
    List<fb.Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    Duration? timeout,
    bool androidUsesFineLocation = false,
  }) async {
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
    if (_useWindows) {
      await fb_win.FlutterBluePlusWindows.stopScan();
    } else {
      await fb.FlutterBluePlus.stopScan();
    }
  }
}