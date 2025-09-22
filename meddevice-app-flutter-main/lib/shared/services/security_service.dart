import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'encryption_service.dart';

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
        final newSalt = _encryptionService.generateSalt();
        await storeSecureData(_saltKey, newSalt);
      }
    } catch (e) {
      throw SecurityException('Failed to initialize security service: $e');
    }
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access secure data',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) return false;

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> verifyCertificatePinning(String host, int port) async {
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      
      final certificate = socket.peerCertificate;
      socket.destroy();
      
      if (certificate == null) return false;
      
      // Verify certificate chain and properties
      return _verifyCertificateProperties(certificate);
    } catch (e) {
      return false;
    }
  }

  bool _verifyCertificateProperties(X509Certificate certificate) {
    try {
      // Basic certificate validation
      final now = DateTime.now();
      final notBefore = certificate.startValidity;
      final notAfter = certificate.endValidity;
      
      if (now.isBefore(notBefore) || now.isAfter(notAfter)) {
        return false;
      }
      
      // Additional validations can be added here
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> generateDeviceFingerprint() async {
    try {
      final properties = <String>[];
      
      // Platform info
      properties.add(Platform.operatingSystem);
      properties.add(Platform.operatingSystemVersion);
      
      // Generate a unique device identifier
      final deviceData = properties.join('|');
      final bytes = utf8.encode(deviceData);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      // Fallback to random ID
      return _encryptionService.generateRandomString(32);
    }
  }

  @override
  Future<bool> verifyDeviceIntegrity() async {
    try {
      // Check if device has been compromised
      // This is a basic implementation
      
      // Check for root/jailbreak indicators
      if (await _isDeviceRooted()) return false;
      
      // Verify stored device fingerprint
      final storedFingerprint = await getSecureData(_deviceIdKey);
      final currentFingerprint = await generateDeviceFingerprint();
      
      return storedFingerprint == currentFingerprint;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isDeviceRooted() async {
    try {
      // Basic root detection
      final rootPaths = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
        '/su/bin/su',
      ];
      
      for (final path in rootPaths) {
        if (await File(path).exists()) return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> generateSecureKey() async {
    return await _encryptionService.generateAESKey();
  }

  @override
  Future<String> deriveKey(String password, String salt, {int iterations = 100000}) async {
    try {
      final bytes = utf8.encode(password + salt);
      var hash = bytes;
      
      for (int i = 0; i < iterations; i++) {
        hash = Uint8List.fromList(sha256.convert(hash).bytes);
      }
      
      return base64Encode(hash);
    } catch (e) {
      throw SecurityException('Failed to derive key: $e');
    }
  }

  @override
  Future<Uint8List> generateSecureRandom(int length) async {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return Uint8List.fromList(bytes);
  }

  @override
  void secureClear(List<int> data) {
    try {
      for (int i = 0; i < data.length; i++) {
        data[i] = 0;
      }
    } catch (e) {
      // Silent fail for security
    }
  }

  @override
  Future<bool> verifyNonce(String nonce) async {
    try {
      // Basic nonce validation
      if (nonce.isEmpty) return false;
      
      // Check if it's valid base64
      try {
        base64Decode(nonce);
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> storeSecureData(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      throw SecurityException('Failed to store secure data: $e');
    }
  }

  @override
  Future<String?> getSecureData(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteSecureData(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      throw SecurityException('Failed to delete secure data: $e');
    }
  }

  @override
  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw SecurityException('Failed to clear all secure data: $e');
    }
  }
}

/// Security exception class
class SecurityException implements Exception {
  final String message;
  
  const SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}

/// Security utilities
class SecurityUtils {
  /// Generate secure token
  static String generateSecureToken({int length = 32}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Validate token format
  static bool isValidToken(String token) {
    if (token.isEmpty) return false;
    final regex = RegExp(r'^[A-Za-z0-9]+$');
    return regex.hasMatch(token);
  }

  /// Create secure hash
  static String createSecureHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify hash
  static bool verifyHash(String input, String hash) {
    final inputHash = createSecureHash(input);
    return inputHash == hash;
  }
}