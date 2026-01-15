import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

import 'encryption_service.dart';

/// Custom exception for security-related errors
class SecurityException implements Exception {
  final String message;
  final String? details;
  
  SecurityException(this.message, {this.details});
  
  @override
  String toString() => 'SecurityException: $message${details != null ? ' - $details' : ''}';
}

/// Security service abstract class
abstract class SecurityService {
  /// Initialize security service
  Future<void> initialize();

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics();

  /// Check if biometrics is available
  Future<bool> isBiometricsAvailable();

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics();

  /// Verify certificate pinning
  Future<bool> verifyCertificatePinning(String host, int port);

  /// Generate device fingerprint
  Future<String> generateDeviceFingerprint();

  /// Verify device integrity
  Future<bool> verifyDeviceIntegrity();

  /// Generate secure key
  Future<String> generateSecureKey();

  /// Derive key from password
  Future<String> deriveKey(String password, String salt, {int iterations = 100000});

  /// Generate secure random bytes
  Future<Uint8List> generateSecureRandom(int length);

  /// Secure clear sensitive data
  void secureClear(List<int> data);

  /// Verify nonce
  Future<bool> verifyNonce(String nonce);

  /// Store sensitive data securely
  Future<void> storeSecureData(String key, String value);

  /// Retrieve sensitive data securely
  Future<String?> getSecureData(String key);

  /// Delete secure data
  Future<void> deleteSecureData(String key);

  /// Clear all secure data
  Future<void> clearAllSecureData();

  /// Get TLS connection information
  Future<Map<String, dynamic>> getTLSConnectionInfo();
}

/// Security service implementation
class SecurityServiceImpl implements SecurityService {
  static const String _keyPrefix = 'secure_';
  static const String _deviceIdKey = '${_keyPrefix}device_id';
  static const String _saltKey = '${_keyPrefix}salt';
  
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final EncryptionService _encryptionService;
  final Random _random = Random.secure();

  SecurityServiceImpl({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
    EncryptionService? encryptionService,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
        _localAuth = localAuth ?? LocalAuthentication(),
        _encryptionService = encryptionService ?? EncryptionServiceImpl();

  @override
  Future<void> initialize() async {
    try {
      // Initialize device ID if not exists
      final deviceId = await getSecureData(_deviceIdKey);
      if (deviceId == null) {
        final newDeviceId = await generateDeviceFingerprint();
        await storeSecureData(_deviceIdKey, newDeviceId);
      }

      // Initialize salt if not exists
      final salt = await getSecureData(_saltKey);
      if (salt == null) {
        final newSalt = base64Encode(await generateSecureRandom(32));
        await storeSecureData(_saltKey, newSalt);
      }
    } catch (e) {
      throw SecurityException('Failed to initialize security service', details: e.toString());
    }
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      if (!await isBiometricsAvailable()) {
        return false;
      }

      final result = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access secure data',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      return result;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometrics availability: $e');
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  @override
  Future<bool> verifyCertificatePinning(String host, int port) async {
    // TODO: Implement actual certificate pinning verification for production
    throw UnimplementedError('Certificate pinning verification not implemented');
  }

  @override
  Future<String> generateDeviceFingerprint() async {
    try {
      final components = <String>[];
      
      // Add device-specific information
      components.add('flutter_${defaultTargetPlatform.name}');
      components.add(DateTime.now().millisecondsSinceEpoch.toString());
      
      final combined = components.join('|');
      final bytes = utf8.encode(combined);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      throw SecurityException('Failed to generate device fingerprint', details: e.toString());
    }
  }

  @override
  Future<bool> verifyDeviceIntegrity() async {
    // TODO: Implement actual device integrity checks for production
    throw UnimplementedError('Device integrity verification not implemented');
  }

  @override
  Future<String> generateSecureKey() async {
    try {
      final randomBytes = await generateSecureRandom(32);
      return base64Encode(randomBytes);
    } catch (e) {
      throw SecurityException('Failed to generate secure key', details: e.toString());
    }
  }

  @override
  Future<String> deriveKey(String password, String salt, {int iterations = 100000}) async {
    try {
      final passwordBytes = utf8.encode(password);
      final saltBytes = base64Decode(salt);
      
      // Simple PBKDF2 implementation
      Uint8List key = Uint8List.fromList(passwordBytes);
      for (int i = 0; i < iterations; i++) {
        final hmac = Hmac(sha256, key);
        key = Uint8List.fromList(hmac.convert(saltBytes).bytes);
      }
      
      return base64Encode(key);
    } catch (e) {
      throw SecurityException('Failed to derive key', details: e.toString());
    }
  }

  @override
  Future<Uint8List> generateSecureRandom(int length) async {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  @override
  void secureClear(List<int> data) {
    for (int i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }

  @override
  Future<bool> verifyNonce(String nonce) async {
    return nonce.isNotEmpty && nonce.length >= 16;
  }

  @override
  Future<void> storeSecureData(String key, String value) async {
    try {
      await _secureStorage.write(key: '$_keyPrefix$key', value: value);
    } catch (e) {
      throw SecurityException('Failed to store secure data', details: e.toString());
    }
  }

  @override
  Future<String?> getSecureData(String key) async {
    try {
      return await _secureStorage.read(key: '$_keyPrefix$key');
    } catch (e) {
      throw SecurityException('Failed to retrieve secure data', details: e.toString());
    }
  }

  @override
  Future<void> deleteSecureData(String key) async {
    try {
      await _secureStorage.delete(key: '$_keyPrefix$key');
    } catch (e) {
      throw SecurityException('Failed to delete secure data', details: e.toString());
    }
  }

  @override
  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw SecurityException('Failed to clear all secure data', details: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getTLSConnectionInfo() async {
    // TODO: Implement actual TLS connection info retrieval for production
    throw UnimplementedError('TLS connection info retrieval not implemented');
  }
}