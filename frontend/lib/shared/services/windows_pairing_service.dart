import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows Platform Channel for BLE Pairing using WinRT APIs
/// 
/// This service provides access to Windows-specific BLE pairing functionality
/// that is not available through cross-platform BLE packages.
/// 
/// Supports:
/// - ProvidePin mode (user enters PIN shown on device)
/// - DisplayPin mode (user confirms PIN matches)
/// - ConfirmPinMatch mode (user confirms displayed PIN)
/// - LESC (Low Energy Secure Connections) pairing
class WindowsPairingService {
  static const MethodChannel _channel =
      MethodChannel('com.medusa/windows_ble_pairing');

  /// Pair with a BLE device using Windows native pairing dialog
  /// 
  /// [deviceAddress]: BLE device address in format "AA:BB:CC:DD:EE:FF"
  /// [requireAuthentication]: Whether to require LESC authentication (default: true)
  /// 
  /// Returns: true if pairing succeeds, false otherwise
  /// 
  /// The Windows pairing dialog will automatically appear and handle:
  /// - ProvidePin: User enters PIN shown on device OLED
  /// - DisplayPin: Windows shows PIN, user confirms it matches device
  /// - ConfirmPinMatch: User confirms PIN on both devices
  static Future<bool> pairDevice({
    required String deviceAddress,
    bool requireAuthentication = true,
  }) async {
    if (!Platform.isWindows) {
      debugPrint('[WindowsPairing] ⚠️ Not on Windows platform');
      return false;
    }

    try {
      debugPrint('[WindowsPairing] 🔐 Initiating pairing for $deviceAddress');
      debugPrint('[WindowsPairing] Authentication required: $requireAuthentication');

      final result = await _channel.invokeMethod<bool>('pairDevice', {
        'deviceAddress': deviceAddress,
        'requireAuthentication': requireAuthentication,
      });

      if (result == true) {
        debugPrint('[WindowsPairing] ✅ Pairing successful');
        return true;
      } else {
        debugPrint('[WindowsPairing] ❌ Pairing failed or cancelled');
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('[WindowsPairing] ❌ Platform error: ${e.code} - ${e.message}');
      debugPrint('[WindowsPairing] Details: ${e.details}');
      return false;
    } catch (e) {
      debugPrint('[WindowsPairing] ❌ Unexpected error: $e');
      return false;
    }
  }

  /// Check if a device is already paired
  /// 
  /// [deviceAddress]: BLE device address in format "AA:BB:CC:DD:EE:FF"
  /// 
  /// Returns: true if device is paired, false otherwise
  static Future<bool> isDevicePaired(String deviceAddress) async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isDevicePaired', {
        'deviceAddress': deviceAddress,
      });

      debugPrint('[WindowsPairing] Device $deviceAddress paired status: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      debugPrint('[WindowsPairing] Error checking pairing status: $e');
      return false;
    }
  }

  /// Unpair a BLE device
  /// 
  /// [deviceAddress]: BLE device address in format "AA:BB:CC:DD:EE:FF"
  /// 
  /// Returns: true if unpairing succeeds, false otherwise
  static Future<bool> unpairDevice(String deviceAddress) async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      debugPrint('[WindowsPairing] 🔓 Unpairing device: $deviceAddress');

      final result = await _channel.invokeMethod<bool>('unpairDevice', {
        'deviceAddress': deviceAddress,
      });

      if (result == true) {
        debugPrint('[WindowsPairing] ✅ Device unpaired');
        return true;
      } else {
        debugPrint('[WindowsPairing] ❌ Unpair failed');
        return false;
      }
    } catch (e) {
      debugPrint('[WindowsPairing] Error unpairing: $e');
      return false;
    }
  }

  /// Get pairing protection level for a paired device
  /// 
  /// [deviceAddress]: BLE device address
  /// 
  /// Returns: Protection level string (None, Encryption, EncryptionAndAuthentication)
  static Future<String?> getPairingProtectionLevel(String deviceAddress) async {
    if (!Platform.isWindows) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>('getPairingProtectionLevel', {
        'deviceAddress': deviceAddress,
      });

      debugPrint('[WindowsPairing] Protection level for $deviceAddress: $result');
      return result;
    } catch (e) {
      debugPrint('[WindowsPairing] Error getting protection level: $e');
      return null;
    }
  }
}

