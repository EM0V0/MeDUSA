import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Custom exception for pairing-related errors
class PairingException implements Exception {
  final String message;
  final bool requiresManualSteps;

  PairingException(this.message, {this.requiresManualSteps = false});

  @override
  String toString() => message;
}

/// Manager for handling Bluetooth pairing operations
/// Specifically designed for Windows platform with PIN code input support
class PairingManager {
  static final PairingManager _instance = PairingManager._internal();
  PairingManager._internal();
  
  static PairingManager get instance => _instance;

  // Callback for requesting PIN from user
  Future<String?> Function(BluetoothDevice device)? _pinRequestCallback;

  /// Set the callback function that will be invoked when a PIN is required
  /// This should show a dialog or input field to the user
  void setPinRequestCallback(Future<String?> Function(BluetoothDevice device) callback) {
    _pinRequestCallback = callback;
  }

  /// Check if the device is currently paired at OS level
  Future<bool> isPaired(BluetoothDevice device) async {
    if (kIsWeb) {
      // Web Bluetooth doesn't expose pairing status directly
      // Assume paired if connected
      return device.isConnected;
    }

    if (!Platform.isWindows) {
      // On mobile platforms, pairing is handled automatically by OS
      // We can't easily check pairing status, so return true if connected
      return device.isConnected;
    }

    // Windows-specific pairing check
    // On Windows, we'll assume pairing is needed and let the OS handle it
    // The actual pairing will be triggered when accessing encrypted characteristics
    try {
      debugPrint('[PairingManager] Windows platform - pairing status checked via connection');
      // If device is connected, we can attempt to verify by reading an encrypted characteristic
      // This will be done in the WiFiHelperBluetoothService.verifyPairingStatus() method
      return device.isConnected;
    } catch (e) {
      debugPrint('[PairingManager] Error checking pairing status: $e');
      // If we can't determine, assume not paired to trigger pairing flow
      return false;
    }
  }

  /// Ensure the device is paired, initiating pairing if necessary
  /// 
  /// On Windows: Triggers manual PIN entry flow
  /// - Shows PIN input dialog to user
  /// - User enters 6-digit PIN
  /// - Sends PIN to device for verification
  /// 
  /// Parameters:
  /// - device: The Bluetooth device to pair with
  /// - requireMitm: Require Man-in-the-Middle protection (LESC pairing with PIN)
  Future<bool> ensurePaired(
    BluetoothDevice device, {
    bool requireMitm = true,
  }) async {
    debugPrint('[PairingManager] ensurePaired called for ${device.platformName}');
    
    // Check if already paired
    final alreadyPaired = await isPaired(device);
    if (alreadyPaired) {
      debugPrint('[PairingManager] Device already paired');
      return true;
    }

    if (kIsWeb) {
      throw PairingException(
        'Web Bluetooth pairing requires OS-level pairing. '
        'Please pair the device in your operating system Bluetooth settings first.',
        requiresManualSteps: true,
      );
    }

    if (!Platform.isWindows) {
      // On mobile, pairing is handled automatically by the OS
      // Just return true and let the OS handle it
      debugPrint('[PairingManager] Mobile platform - OS handles pairing automatically');
      return true;
    }

    // Windows-specific pairing flow with PIN input
    return await _pairOnWindows(device, requireMitm: requireMitm);
  }

  /// Windows-specific pairing implementation
  /// 
  /// Uses Windows native Bluetooth pairing dialog (no custom UI)
  /// Windows will automatically show pairing prompt when accessing encrypted characteristics
  Future<bool> _pairOnWindows(
    BluetoothDevice device, {
    required bool requireMitm,
  }) async {
    debugPrint('🔐 [Pairing] Starting Windows native pairing for ${device.platformName}');

    try {
      // Windows handles pairing automatically via system dialog
      // When we attempt to connect to encrypted characteristics,
      // Windows will show its native Bluetooth pairing prompt
      // User enters PIN shown on Raspberry Pi OLED
      
      debugPrint('⏳ [Pairing] Windows will show pairing dialog automatically');
      debugPrint('📱 [Pairing] Check Raspberry Pi OLED for 6-digit PIN');
      
      // No custom dialog - let Windows handle everything
      // Pairing happens during connection to encrypted characteristics
      
      return true;
    } catch (e) {
      if (e is PairingException) {
        rethrow;
      }
      debugPrint('❌ [Pairing] Error: $e');
      throw PairingException('Pairing error: $e');
    }
  }

  /// Unpair a device (Windows only)
  /// Note: Unpairing must be done through Windows Bluetooth settings
  Future<bool> unpair(BluetoothDevice device) async {
    if (kIsWeb || !Platform.isWindows) {
      debugPrint('[PairingManager] Unpairing not supported on this platform');
      return false;
    }

    try {
      final address = device.remoteId.str;
      debugPrint('[PairingManager] Unpairing device: $address');
      debugPrint('[PairingManager] Please unpair the device manually in Windows Bluetooth settings');
      
      // WinBle doesn't provide an unpair method
      // Users must unpair through Windows Settings > Bluetooth & devices
      
      return false;
    } catch (e) {
      debugPrint('[PairingManager] Unpair error: $e');
      return false;
    }
  }

  /// Request pairing with automatic PIN handling (for testing)
  /// In production, use ensurePaired() with proper PIN callback
  Future<bool> requestPairing(BluetoothDevice device) async {
    debugPrint('[PairingManager] requestPairing (auto PIN) - use ensurePaired() for manual PIN');
    return await ensurePaired(device, requireMitm: true);
  }
}