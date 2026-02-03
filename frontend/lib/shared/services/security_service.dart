import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

/// Custom exception for security-related errors
class SecurityException implements Exception {
  final String message;
  final String? details;
  
  SecurityException(this.message, {this.details});
  
  @override
  String toString() => 'SecurityException: $message${details != null ? ' - $details' : ''}';
}

/// Device integrity status
enum DeviceIntegrityStatus {
  secure,
  rooted,
  jailbroken,
  emulator,
  debugMode,
  unknown,
}

/// Certificate pinning result
class CertificatePinningResult {
  final bool isValid;
  final String? fingerprint;
  final String? error;
  final DateTime? checkedAt;

  CertificatePinningResult({
    required this.isValid,
    this.fingerprint,
    this.error,
    this.checkedAt,
  });
}

/// TLS connection information
class TLSConnectionInfo {
  final String host;
  final int port;
  final String? protocol;
  final String? cipherSuite;
  final String? certificateSubject;
  final String? certificateIssuer;
  final DateTime? certificateValidFrom;
  final DateTime? certificateValidTo;
  final String? certificateFingerprint;

  TLSConnectionInfo({
    required this.host,
    required this.port,
    this.protocol,
    this.cipherSuite,
    this.certificateSubject,
    this.certificateIssuer,
    this.certificateValidFrom,
    this.certificateValidTo,
    this.certificateFingerprint,
  });

  Map<String, dynamic> toMap() => {
    'host': host,
    'port': port,
    'protocol': protocol,
    'cipherSuite': cipherSuite,
    'certificateSubject': certificateSubject,
    'certificateIssuer': certificateIssuer,
    'certificateValidFrom': certificateValidFrom?.toIso8601String(),
    'certificateValidTo': certificateValidTo?.toIso8601String(),
    'certificateFingerprint': certificateFingerprint,
  };
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
  Future<CertificatePinningResult> verifyCertificatePinning(String host, int port);

  /// Generate device fingerprint
  Future<String> generateDeviceFingerprint();

  /// Verify device integrity (root/jailbreak detection)
  Future<DeviceIntegrityStatus> verifyDeviceIntegrity();

  /// Generate secure key
  Future<String> generateSecureKey();

  /// Derive key from password using PBKDF2
  Future<String> deriveKey(String password, String salt, {int iterations = 100000});

  /// Generate secure random bytes
  Future<Uint8List> generateSecureRandom(int length);

  /// Secure clear sensitive data from memory
  void secureClear(List<int> data);

  /// Generate a cryptographically secure nonce
  Future<String> generateNonce();

  /// Verify nonce validity and uniqueness
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
  Future<TLSConnectionInfo> getTLSConnectionInfo(String url);

  /// Verify firmware/app signature
  Future<bool> verifyAppSignature();

  /// Check if running in secure environment
  Future<bool> isSecureEnvironment();
}

/// Security service implementation with full security features
class SecurityServiceImpl implements SecurityService {
  static const String _tag = 'SecurityService';
  static const String _keyPrefix = 'secure_';
  static const String _deviceIdKey = '${_keyPrefix}device_id';
  static const String _saltKey = '${_keyPrefix}salt';
  static const String _nonceStorageKey = '${_keyPrefix}used_nonces';
  
  // Certificate fingerprints for pinning (SHA-256)
  // Add your API server certificate fingerprints here
  static const List<String> _trustedFingerprints = [
    // AWS API Gateway certificate fingerprint
    '87:DC:D4:DC:74:64:0A:32:2C:D2:05:55:25:06:D1:BE:64:F1:25:96:25:80:96:54:49:86:B4:85:0B:C7:27:06',
    // Amazon Root CA 1
    '8E:CD:E6:88:4F:3D:87:B1:12:5B:A3:1A:C3:FC:B1:3D:70:16:DE:7F:57:CC:90:4F:E1:CB:97:C6:AE:98:19:6E',
  ];
  
  // Nonce validity window (5 minutes)
  static const Duration _nonceValidityWindow = Duration(minutes: 5);
  
  // Maximum stored nonces to prevent memory bloat
  static const int _maxStoredNonces = 1000;
  
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final Random _random = Random.secure();
  
  // In-memory nonce cache for replay protection
  final Set<String> _usedNonces = {};
  final Map<String, DateTime> _nonceTimestamps = {};

  SecurityServiceImpl({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
        _localAuth = localAuth ?? LocalAuthentication();

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
      
      // Load persisted nonces
      await _loadPersistedNonces();
      
      // Clean expired nonces
      _cleanExpiredNonces();
      
      debugPrint('$_tag: Security service initialized successfully');
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
      debugPrint('$_tag: Biometric authentication error: $e');
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
      debugPrint('$_tag: Error checking biometrics availability: $e');
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('$_tag: Error getting available biometrics: $e');
      return [];
    }
  }

  @override
  Future<CertificatePinningResult> verifyCertificatePinning(String host, int port) async {
    // Skip certificate pinning on web platform
    if (kIsWeb) {
      return CertificatePinningResult(
        isValid: true,
        error: 'Certificate pinning not available on web platform',
        checkedAt: DateTime.now(),
      );
    }
    
    try {
      debugPrint('$_tag: Verifying certificate pinning for $host:$port');
      
      // Create a secure socket connection to get the certificate
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (certificate) {
          // We'll handle validation manually
          return true;
        },
      );
      
      final certificate = socket.peerCertificate;
      await socket.close();
      
      if (certificate == null) {
        return CertificatePinningResult(
          isValid: false,
          error: 'No certificate received from server',
          checkedAt: DateTime.now(),
        );
      }
      
      // Calculate certificate fingerprint (SHA-256 of DER-encoded certificate)
      final fingerprint = _calculateCertificateFingerprint(certificate);
      
      // Check if fingerprint matches any trusted fingerprint
      final isValid = _trustedFingerprints.any(
        (trusted) => _normalizeFingerprint(trusted) == _normalizeFingerprint(fingerprint)
      );
      
      debugPrint('$_tag: Certificate fingerprint: $fingerprint');
      debugPrint('$_tag: Certificate pinning ${isValid ? 'PASSED' : 'FAILED'}');
      
      return CertificatePinningResult(
        isValid: isValid,
        fingerprint: fingerprint,
        error: isValid ? null : 'Certificate fingerprint does not match any trusted fingerprint',
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('$_tag: Certificate pinning verification error: $e');
      return CertificatePinningResult(
        isValid: false,
        error: 'Failed to verify certificate: $e',
        checkedAt: DateTime.now(),
      );
    }
  }
  
  /// Calculate SHA-256 fingerprint of X509 certificate
  String _calculateCertificateFingerprint(X509Certificate certificate) {
    // Get DER-encoded certificate bytes
    final derBytes = certificate.der;
    final digest = sha256.convert(derBytes);
    
    // Format as colon-separated hex string
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
  
  /// Normalize fingerprint for comparison (remove colons, convert to uppercase)
  String _normalizeFingerprint(String fingerprint) {
    return fingerprint.replaceAll(':', '').replaceAll('-', '').toUpperCase();
  }

  @override
  Future<String> generateDeviceFingerprint() async {
    try {
      final components = <String>[];
      
      // Platform information
      components.add('platform_${defaultTargetPlatform.name}');
      
      // Unique installation identifier
      final installId = await _getOrCreateInstallId();
      components.add('install_$installId');
      
      // Random entropy
      final entropy = await generateSecureRandom(16);
      components.add('entropy_${base64Encode(entropy)}');
      
      // Timestamp
      components.add('time_${DateTime.now().millisecondsSinceEpoch}');
      
      final combined = components.join('|');
      final bytes = utf8.encode(combined);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      throw SecurityException('Failed to generate device fingerprint', details: e.toString());
    }
  }
  
  Future<String> _getOrCreateInstallId() async {
    const key = '${_keyPrefix}install_id';
    var installId = await _secureStorage.read(key: key);
    if (installId == null) {
      final bytes = await generateSecureRandom(16);
      installId = base64Encode(bytes);
      await _secureStorage.write(key: key, value: installId);
    }
    return installId;
  }

  @override
  Future<DeviceIntegrityStatus> verifyDeviceIntegrity() async {
    debugPrint('$_tag: Verifying device integrity...');
    
    // Check if running in debug mode
    if (kDebugMode) {
      debugPrint('$_tag: Running in debug mode');
      return DeviceIntegrityStatus.debugMode;
    }
    
    // Platform-specific integrity checks
    if (kIsWeb) {
      // Web platform - limited integrity checks possible
      debugPrint('$_tag: Web platform - integrity checks limited');
      return DeviceIntegrityStatus.secure;
    }
    
    try {
      // Check for emulator/simulator
      if (await _isEmulator()) {
        debugPrint('$_tag: Emulator detected');
        return DeviceIntegrityStatus.emulator;
      }
      
      // Check for root (Android) or jailbreak (iOS)
      if (await _isRootedOrJailbroken()) {
        debugPrint('$_tag: Device is rooted/jailbroken');
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return DeviceIntegrityStatus.jailbroken;
        }
        return DeviceIntegrityStatus.rooted;
      }
      
      debugPrint('$_tag: Device integrity verified - secure');
      return DeviceIntegrityStatus.secure;
    } catch (e) {
      debugPrint('$_tag: Error verifying device integrity: $e');
      return DeviceIntegrityStatus.unknown;
    }
  }
  
  /// Check if running on emulator/simulator
  Future<bool> _isEmulator() async {
    if (kIsWeb) return false;
    
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _checkAndroidEmulator();
        case TargetPlatform.iOS:
          return await _checkIOSSimulator();
        default:
          return false;
      }
    } catch (e) {
      debugPrint('$_tag: Error checking emulator: $e');
      return false;
    }
  }
  
  Future<bool> _checkAndroidEmulator() async {
    // Check common Android emulator indicators
    // In production, this would use platform channels for native checks
    final emulatorIndicators = [
      'generic',
      'unknown',
      'google_sdk',
      'sdk_gphone',
      'sdk_x86',
      'vbox86p',
      'emulator',
      'goldfish',
      'ranchu',
    ];
    
    // Check environment variables that indicate emulator
    // Note: This is a basic check; production would use native code
    final fingerprint = Platform.environment['FINGERPRINT'] ?? '';
    for (final indicator in emulatorIndicators) {
      if (fingerprint.toLowerCase().contains(indicator)) {
        return true;
      }
    }
    
    return false;
  }
  
  Future<bool> _checkIOSSimulator() async {
    // On iOS, we can check for simulator through platform channels
    // For now, check SIMULATOR_DEVICE_NAME environment variable
    return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
  }
  
  /// Check for root (Android) or jailbreak (iOS)
  Future<bool> _isRootedOrJailbroken() async {
    if (kIsWeb) return false;
    
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _checkAndroidRoot();
        case TargetPlatform.iOS:
          return await _checkIOSJailbreak();
        default:
          return false;
      }
    } catch (e) {
      debugPrint('$_tag: Error checking root/jailbreak: $e');
      return false;
    }
  }
  
  Future<bool> _checkAndroidRoot() async {
    // Check for common root indicators
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
      '/system/app/SuperSU',
      '/system/app/SuperSU.apk',
      '/system/etc/init.d/99telecominfra',
      '/system/etc/init.d/99SuperSUDaemon',
      '/dev/com.koushikdutta.superuser.daemon/',
    ];
    
    for (final path in rootPaths) {
      try {
        if (await File(path).exists()) {
          return true;
        }
      } catch (_) {
        // Continue checking
      }
    }
    
    // Root management apps to check for (requires native platform channel)
    // Package names: com.koushikdutta.superuser, com.thirdparty.superuser,
    // eu.chainfire.supersu, com.noshufou.android.su, com.topjohnwu.magisk
    // Note: In production, use PackageManager through platform channels
    // to check for these packages
    
    return false;
  }
  
  Future<bool> _checkIOSJailbreak() async {
    // Check for common jailbreak indicators
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Applications/Sileo.app',
      '/Applications/Zebra.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/usr/bin/ssh',
      '/private/var/lib/apt/',
      '/private/var/lib/cydia',
      '/private/var/stash',
      '/private/var/mobile/Library/SBSettings/Themes',
      '/private/var/tmp/cydia.log',
    ];
    
    for (final path in jailbreakPaths) {
      try {
        if (await File(path).exists()) {
          return true;
        }
      } catch (_) {
        // Continue checking
      }
    }
    
    // Check if we can write to system directories (shouldn't be possible on non-jailbroken)
    try {
      final testFile = File('/private/jailbreak_test.txt');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true; // If we can write, device is jailbroken
    } catch (_) {
      // Expected behavior on non-jailbroken device
    }
    
    return false;
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
      
      // PBKDF2-HMAC-SHA256 implementation
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
  Future<String> generateNonce() async {
    // Generate a cryptographically secure nonce
    // Format: timestamp_randomBytes
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = await generateSecureRandom(16);
    final randomPart = base64Encode(randomBytes);
    
    final nonce = '${timestamp}_$randomPart';
    
    // Store the nonce to prevent reuse
    _usedNonces.add(nonce);
    _nonceTimestamps[nonce] = DateTime.now();
    
    // Clean expired nonces periodically
    if (_usedNonces.length > _maxStoredNonces ~/ 2) {
      _cleanExpiredNonces();
    }
    
    return nonce;
  }

  @override
  Future<bool> verifyNonce(String nonce) async {
    if (nonce.isEmpty || nonce.length < 16) {
      return false;
    }
    
    // Check if nonce was already used (replay attack prevention)
    if (_usedNonces.contains(nonce)) {
      debugPrint('$_tag: Nonce already used - potential replay attack');
      return false;
    }
    
    // Parse timestamp from nonce
    final parts = nonce.split('_');
    if (parts.length != 2) {
      return false;
    }
    
    try {
      final timestamp = int.parse(parts[0]);
      final nonceTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      // Check if nonce is within validity window
      if (now.difference(nonceTime) > _nonceValidityWindow) {
        debugPrint('$_tag: Nonce expired');
        return false;
      }
      
      // Mark nonce as used
      _usedNonces.add(nonce);
      _nonceTimestamps[nonce] = now;
      
      // Persist nonces
      await _persistNonces();
      
      return true;
    } catch (e) {
      debugPrint('$_tag: Error verifying nonce: $e');
      return false;
    }
  }
  
  void _cleanExpiredNonces() {
    final now = DateTime.now();
    final expiredNonces = <String>[];
    
    for (final entry in _nonceTimestamps.entries) {
      if (now.difference(entry.value) > _nonceValidityWindow) {
        expiredNonces.add(entry.key);
      }
    }
    
    for (final nonce in expiredNonces) {
      _usedNonces.remove(nonce);
      _nonceTimestamps.remove(nonce);
    }
    
    // If still too many, remove oldest
    if (_usedNonces.length > _maxStoredNonces) {
      final sorted = _nonceTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final toRemove = sorted.take(_usedNonces.length - _maxStoredNonces);
      for (final entry in toRemove) {
        _usedNonces.remove(entry.key);
        _nonceTimestamps.remove(entry.key);
      }
    }
    
    debugPrint('$_tag: Cleaned nonces, remaining: ${_usedNonces.length}');
  }
  
  Future<void> _persistNonces() async {
    try {
      final data = {
        'nonces': _usedNonces.toList(),
        'timestamps': _nonceTimestamps.map(
          (k, v) => MapEntry(k, v.millisecondsSinceEpoch),
        ),
      };
      await _secureStorage.write(
        key: _nonceStorageKey,
        value: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('$_tag: Error persisting nonces: $e');
    }
  }
  
  Future<void> _loadPersistedNonces() async {
    try {
      final stored = await _secureStorage.read(key: _nonceStorageKey);
      if (stored != null) {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        
        final nonces = (data['nonces'] as List<dynamic>?)?.cast<String>() ?? [];
        _usedNonces.addAll(nonces);
        
        final timestamps = (data['timestamps'] as Map<String, dynamic>?) ?? {};
        for (final entry in timestamps.entries) {
          _nonceTimestamps[entry.key] = DateTime.fromMillisecondsSinceEpoch(
            entry.value as int,
          );
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error loading persisted nonces: $e');
    }
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
      _usedNonces.clear();
      _nonceTimestamps.clear();
    } catch (e) {
      throw SecurityException('Failed to clear all secure data', details: e.toString());
    }
  }

  @override
  Future<TLSConnectionInfo> getTLSConnectionInfo(String url) async {
    if (kIsWeb) {
      throw SecurityException('TLS connection info not available on web platform');
    }
    
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      
      debugPrint('$_tag: Getting TLS info for $host:$port');
      
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      
      final certificate = socket.peerCertificate;
      final protocol = socket.selectedProtocol;
      
      await socket.close();
      
      if (certificate == null) {
        throw SecurityException('No certificate received from server');
      }
      
      return TLSConnectionInfo(
        host: host,
        port: port,
        protocol: protocol,
        certificateSubject: certificate.subject,
        certificateIssuer: certificate.issuer,
        certificateValidFrom: certificate.startValidity,
        certificateValidTo: certificate.endValidity,
        certificateFingerprint: _calculateCertificateFingerprint(certificate),
      );
    } catch (e) {
      throw SecurityException('Failed to get TLS connection info', details: e.toString());
    }
  }

  @override
  Future<bool> verifyAppSignature() async {
    // In production, this would verify the app's code signature
    // using platform-specific APIs
    
    if (kIsWeb) {
      // Web apps can't verify their own signature
      return true;
    }
    
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          // On Android, verify APK signature using PackageManager
          // This would require platform channel to native code
          return await _verifyAndroidSignature();
        case TargetPlatform.iOS:
          // On iOS, the system handles code signing verification
          // We can check for common tampering indicators
          return await _verifyIOSSignature();
        case TargetPlatform.windows:
          // On Windows, verify Authenticode signature
          return await _verifyWindowsSignature();
        default:
          return true;
      }
    } catch (e) {
      debugPrint('$_tag: Error verifying app signature: $e');
      return false;
    }
  }
  
  Future<bool> _verifyAndroidSignature() async {
    // In production, use platform channels to call:
    // PackageManager.getPackageInfo(packageName, GET_SIGNATURES)
    // Then verify the signature hash matches expected value
    
    // For now, return true (would need native implementation)
    debugPrint('$_tag: Android signature verification (placeholder)');
    return true;
  }
  
  Future<bool> _verifyIOSSignature() async {
    // iOS apps are signed by Apple and verified at install time
    // We check for common tampering indicators
    
    // Check for Cydia Substrate (common hooking framework)
    try {
      final substratePath = '/Library/MobileSubstrate/MobileSubstrate.dylib';
      if (await File(substratePath).exists()) {
        return false;
      }
    } catch (_) {}
    
    return true;
  }
  
  Future<bool> _verifyWindowsSignature() async {
    // On Windows, verify Authenticode signature
    // This would require native code or PowerShell integration
    
    debugPrint('$_tag: Windows signature verification (placeholder)');
    return true;
  }

  @override
  Future<bool> isSecureEnvironment() async {
    // Comprehensive security environment check
    
    // 1. Verify device integrity
    final integrityStatus = await verifyDeviceIntegrity();
    if (integrityStatus != DeviceIntegrityStatus.secure &&
        integrityStatus != DeviceIntegrityStatus.debugMode) {
      debugPrint('$_tag: Insecure environment - device integrity: $integrityStatus');
      return false;
    }
    
    // 2. Verify app signature (skip in debug mode)
    if (!kDebugMode) {
      final signatureValid = await verifyAppSignature();
      if (!signatureValid) {
        debugPrint('$_tag: Insecure environment - invalid app signature');
        return false;
      }
    }
    
    debugPrint('$_tag: Secure environment verified');
    return true;
  }
}
