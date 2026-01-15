import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import 'security_service.dart';

/// Storage service interface for secure data management
abstract class StorageService {
  // Secure Storage (for sensitive data like tokens)
  Future<void> storeSecure(String key, String value, {bool encrypt = true});
  Future<String?> getSecure(String key, {bool decrypt = true});
  Future<void> deleteSecure(String key);
  Future<void> clearAllSecure();

  // Additional secure storage methods
  Future<String?> getSecureString(String key, {bool decrypt = true});
  Future<void> setSecureString(String key, String value, {bool encrypt = true});
  Future<void> removeSecure(String key);

  // Encrypted map storage methods
  Future<Map<String, dynamic>?> getMap(String key, {bool decrypt = true});
  Future<void> setMap(String key, Map<String, dynamic> value, {bool encrypt = true});
  Future<void> setString(String key, String value, {bool encrypt = false});

  // Shared Preferences (for simple key-value pairs)
  Future<void> storeString(String key, String value);
  Future<String?> getString(String key);
  Future<void> storeBool(String key, bool value);
  Future<bool?> getBool(String key);
  Future<void> storeInt(String key, int value);
  Future<int?> getInt(String key);
  Future<void> storeDouble(String key, double value);
  Future<double?> getDouble(String key);
  Future<void> remove(String key);
  Future<void> clear();

  // Secure Hive Storage (for complex objects and caching)
  Future<void> storeUser(Map<String, dynamic> user);
  Future<Map<String, dynamic>?> getUser();
  Future<void> deleteUser();

  Future<void> storeSetting(String key, dynamic value, {bool encrypt = false});
  Future<T?> getSetting<T>(String key, {bool decrypt = false});
  Future<void> deleteSetting(String key);

  Future<void> storeCache(String key, dynamic value, {Duration? ttl, bool encrypt = false});
  Future<T?> getCache<T>(String key, {bool decrypt = false});
  Future<void> deleteCache(String key);
  Future<void> clearExpiredCache();

  // Security-specific storage methods
  Future<void> storeEncryptionKey(String keyId, Uint8List key);
  Future<Uint8List?> getEncryptionKey(String keyId);
  Future<void> storeDeviceFingerprint(String fingerprint);
  Future<String?> getDeviceFingerprint();
  Future<void> storeSecurityConfig(Map<String, dynamic> config);
  Future<Map<String, dynamic>?> getSecurityConfig();

  // Authentication and session management
  Future<bool> hasValidToken();
  Future<String?> getToken();
  Future<void> storeToken(String token);
  Future<void> clearAuthData();
  Future<void> storeSessionData(Map<String, dynamic> sessionData);
  Future<Map<String, dynamic>?> getSessionData();
  Future<void> storeRefreshToken(String refreshToken);
  Future<String?> getRefreshToken();

  // Security audit methods
  Future<void> logStorageAccess(String operation, String key);
  Future<bool> verifyStorageIntegrity();
  Future<void> rotateEncryptionKeys();
}

/// Storage service implementation for secure data management
class StorageServiceImpl implements StorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _sharedPreferences;
  final Box _userBox;
  final Box _settingsBox;
  final Box _cacheBox;
  final SecurityService _securityService;

  // Security constants
  static const String _encryptionKeyPrefix = 'encryption_key_';
  static const String _deviceFingerprintKey = 'device_fingerprint';
  static const String _securityConfigKey = 'security_config';
  static const String _sessionDataKey = 'session_data';
  static const String _accessLogKey = 'storage_access_log';
  static const String _integrityHashKey = 'storage_integrity_hash';

  StorageServiceImpl({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences sharedPreferences,
    required Box userBox,
    required Box settingsBox,
    required Box cacheBox,
    required SecurityService securityService,
  })  : _secureStorage = secureStorage,
        _sharedPreferences = sharedPreferences,
        _userBox = userBox,
        _settingsBox = settingsBox,
        _cacheBox = cacheBox,
        _securityService = securityService;

  // Enhanced Secure Storage Implementation
  @override
  Future<void> storeSecure(String key, String value, {bool encrypt = true}) async {
    try {
      await logStorageAccess('store_secure', key);
      
      String finalValue = value;
      if (encrypt) {
        // Simple base64 encoding as placeholder for encryption
        finalValue = base64Encode(utf8.encode(value));
      }
      
      await _secureStorage.write(
        key: key,
        value: finalValue,
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      
      // Log security event (placeholder)
      Logger.info('Security event: storage_secure_write for key: $key');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<String?> getSecure(String key, {bool decrypt = true}) async {
    try {
      await logStorageAccess('get_secure', key);
      
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;
      
      if (decrypt) {
        try {
          // Simple base64 decoding as placeholder for decryption
          return utf8.decode(base64Decode(value));
        } catch (e) {
          // If decryption fails, return original value (might be unencrypted)
          // Log security event (placeholder)
          Logger.info('Security event: storage_decryption_failed for key: $key');
          return value;
        }
      }
      
      return value;
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> deleteSecure(String key) async {
    try {
      await logStorageAccess('delete_secure', key);
      await _secureStorage.delete(key: key);
      
      // Log security event (placeholder)
      Logger.info('Security event: storage_secure_delete for key: $key');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllSecure() async {
    try {
      await logStorageAccess('clear_all_secure', 'all');
      await _secureStorage.deleteAll();
      
      // Log security event (placeholder)
      Logger.info('Security event: storage_secure_clear_all');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
    }
  }

  @override
  Future<String?> getSecureString(String key, {bool decrypt = true}) async {
    return await getSecure(key, decrypt: decrypt);
  }

  @override
  Future<void> setSecureString(String key, String value, {bool encrypt = true}) async {
    await storeSecure(key, value, encrypt: encrypt);
  }

  @override
  Future<void> removeSecure(String key) async {
    await deleteSecure(key);
  }

  @override
  Future<Map<String, dynamic>?> getMap(String key, {bool decrypt = true}) async {
    try {
      await logStorageAccess('get_map', key);
      
      final data = _sharedPreferences.getString(key);
      if (data == null) return null;
      
      String jsonData = data;
      if (decrypt) {
        try {
          jsonData = utf8.decode(base64Decode(data));
        } catch (e) {
          // If decryption fails, try to parse as unencrypted
          jsonData = data;
        }
      }
      
      return Map<String, dynamic>.from(json.decode(jsonData));
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> setMap(String key, Map<String, dynamic> value, {bool encrypt = true}) async {
    try {
      await logStorageAccess('set_map', key);
      
      String jsonData = json.encode(value);
      if (encrypt) {
        jsonData = base64Encode(utf8.encode(jsonData));
      }
      
      await _sharedPreferences.setString(key, jsonData);
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
    }
  }

  @override
  Future<void> setString(String key, String value, {bool encrypt = false}) async {
    try {
      String finalValue = value;
      if (encrypt) {
        finalValue = base64Encode(utf8.encode(value));
      }
      
      await _sharedPreferences.setString(key, finalValue);
    } catch (e) {
      Logger.error('Error storing string data', error: e);
    }
  }

  // Shared Preferences Implementation
  @override
  Future<void> storeString(String key, String value) async {
    try {
      await _sharedPreferences.setString(key, value);
    } catch (e) {
      Logger.error('Error storing string: $e');
    }
  }

  @override
  Future<String?> getString(String key) async {
    try {
      return _sharedPreferences.getString(key);
    } catch (e) {
      Logger.error('Error reading string: $e');
      return null;
    }
  }

  @override
  Future<void> storeBool(String key, bool value) async {
    try {
      await _sharedPreferences.setBool(key, value);
    } catch (e) {
      Logger.error('Error storing bool: $e');
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    try {
      return _sharedPreferences.getBool(key);
    } catch (e) {
      Logger.error('Error reading bool: $e');
      return null;
    }
  }

  @override
  Future<void> storeInt(String key, int value) async {
    try {
      await _sharedPreferences.setInt(key, value);
    } catch (e) {
      Logger.error('Error storing int: $e');
    }
  }

  @override
  Future<int?> getInt(String key) async {
    try {
      return _sharedPreferences.getInt(key);
    } catch (e) {
      Logger.error('Error reading int: $e');
      return null;
    }
  }

  @override
  Future<void> storeDouble(String key, double value) async {
    try {
      await _sharedPreferences.setDouble(key, value);
    } catch (e) {
      Logger.error('Error storing double: $e');
    }
  }

  @override
  Future<double?> getDouble(String key) async {
    try {
      return _sharedPreferences.getDouble(key);
    } catch (e) {
      Logger.error('Error reading double: $e');
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      await _sharedPreferences.remove(key);
    } catch (e) {
      Logger.error('Error removing key: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _sharedPreferences.clear();
    } catch (e) {
      Logger.error('Error clearing shared preferences: $e');
    }
  }

  // Hive Storage Implementation
  @override
  Future<void> storeUser(Map<String, dynamic> user) async {
    try {
      await _userBox.put('current_user', user);
    } catch (e) {
      Logger.error('Error storing user: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getUser() async {
    try {
      final user = _userBox.get('current_user');
      if (user is Map) {
        return Map<String, dynamic>.from(user);
      }
      return null;
    } catch (e) {
      Logger.error('Error reading user: $e');
      return null;
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      await _userBox.delete('current_user');
    } catch (e) {
      Logger.error('Error deleting user: $e');
    }
  }

  @override
  Future<void> storeSetting(String key, dynamic value, {bool encrypt = false}) async {
    try {
      dynamic finalValue = value;
      if (encrypt && value is String) {
        finalValue = base64Encode(utf8.encode(value));
      }
      await _settingsBox.put(key, finalValue);
    } catch (e) {
      Logger.error('Error storing setting: $e');
    }
  }

  @override
  Future<T?> getSetting<T>(String key, {bool decrypt = false}) async {
    try {
      dynamic value = _settingsBox.get(key);
      
      if (decrypt && value is String) {
        try {
          value = utf8.decode(base64Decode(value));
        } catch (e) {
          // If decryption fails, use original value
        }
      }
      
      if (value is T) {
        return value;
      }
      return null;
    } catch (e) {
      Logger.error('Error reading setting: $e');
      return null;
    }
  }

  @override
  Future<void> deleteSetting(String key) async {
    try {
      await _settingsBox.delete(key);
    } catch (e) {
      Logger.error('Error deleting setting: $e');
    }
  }

  @override
  Future<void> storeCache(String key, dynamic value, {Duration? ttl, bool encrypt = false}) async {
    try {
      dynamic finalValue = value;
      if (encrypt && value is String) {
        finalValue = base64Encode(utf8.encode(value));
      }
      
      final cacheEntry = {
        'value': finalValue,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': ttl?.inMilliseconds,
        'encrypted': encrypt,
      };
      await _cacheBox.put(key, cacheEntry);
    } catch (e) {
      Logger.error('Error storing cache: $e');
    }
  }

  @override
  Future<T?> getCache<T>(String key, {bool decrypt = false}) async {
    try {
      final cacheEntry = _cacheBox.get(key);
      if (cacheEntry is Map) {
        final timestamp = cacheEntry['timestamp'] as int?;
        final ttl = cacheEntry['ttl'] as int?;
        final wasEncrypted = cacheEntry['encrypted'] as bool? ?? false;

        // Check if cache is expired
        if (timestamp != null && ttl != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - timestamp > ttl) {
            // Cache expired, delete it
            await _cacheBox.delete(key);
            return null;
          }
        }

        dynamic value = cacheEntry['value'];
        
        // Decrypt if needed
        if ((decrypt || wasEncrypted) && value is String) {
          try {
            value = utf8.decode(base64Decode(value));
          } catch (e) {
            // If decryption fails, use original value
          }
        }
        
        if (value is T) {
          return value;
        }
      }
      return null;
    } catch (e) {
      Logger.error('Error reading cache: $e');
      return null;
    }
  }

  @override
  Future<void> deleteCache(String key) async {
    try {
      await _cacheBox.delete(key);
    } catch (e) {
      Logger.error('Error deleting cache: $e');
    }
  }

  @override
  Future<void> clearExpiredCache() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final keysToDelete = <String>[];

      for (final key in _cacheBox.keys) {
        final cacheEntry = _cacheBox.get(key);
        if (cacheEntry is Map) {
          final timestamp = cacheEntry['timestamp'] as int?;
          final ttl = cacheEntry['ttl'] as int?;

          if (timestamp != null && ttl != null) {
            if (now - timestamp > ttl) {
              keysToDelete.add(key.toString());
            }
          }
        }
      }

      for (final key in keysToDelete) {
        await _cacheBox.delete(key);
      }

      Logger.info('Cleared ${keysToDelete.length} expired cache entries');
    } catch (e) {
      Logger.error('Error clearing expired cache: $e');
    }
  }

  // Convenience Methods
  @override
  Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getToken() async {
    return await getSecure(AppConstants.tokenKey);
  }

  @override
  Future<void> storeToken(String token) async {
    await storeSecure(AppConstants.tokenKey, token);
  }

  @override
  Future<void> clearAuthData() async {
    await deleteSecure(AppConstants.tokenKey);
    await deleteUser();
    await remove(AppConstants.userKey);
  }

  // Enhanced Security-specific storage methods
  @override
  Future<void> storeEncryptionKey(String keyId, Uint8List key) async {
    try {
      final keyString = base64Encode(key);
      await storeSecure('$_encryptionKeyPrefix$keyId', keyString);
      
      // Log security event (placeholder)
      Logger.info('Security event: encryption_key_stored for keyId: $keyId');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<Uint8List?> getEncryptionKey(String keyId) async {
    try {
      final keyString = await getSecure('$_encryptionKeyPrefix$keyId', decrypt: false);
      if (keyString == null) return null;
      
      return base64Decode(keyString);
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> storeDeviceFingerprint(String fingerprint) async {
    try {
      await storeSecure(_deviceFingerprintKey, fingerprint);
      
      // _securityService.logSecurityEvent (placeholder)
      Logger.info('device_fingerprint_stored');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<String?> getDeviceFingerprint() async {
    try {
      return await getSecure(_deviceFingerprintKey);
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> storeSecurityConfig(Map<String, dynamic> config) async {
    try {
      final configString = json.encode(config);
      await storeSecure(_securityConfigKey, configString);
      
      // _securityService.logSecurityEvent (placeholder)
      Logger.info('security_config_stored');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getSecurityConfig() async {
    try {
      final configString = await getSecure(_securityConfigKey);
      if (configString == null) return null;
      
      return Map<String, dynamic>.from(json.decode(configString));
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> storeSessionData(Map<String, dynamic> sessionData) async {
    try {
      sessionData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      await setMap(_sessionDataKey, sessionData, encrypt: true);
      
      // _securityService.logSecurityEvent (placeholder)
      Logger.info('session_data_stored');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getSessionData() async {
    try {
      return await getMap(_sessionDataKey, decrypt: true);
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> storeRefreshToken(String refreshToken) async {
    try {
      await storeSecure('${AppConstants.tokenKey}_refresh', refreshToken);
      
      // _securityService.logSecurityEvent (placeholder)
      Logger.info('refresh_token_stored');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await getSecure('${AppConstants.tokenKey}_refresh');
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return null;
    }
  }

  @override
  Future<void> logStorageAccess(String operation, String key) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final logEntry = {
        'operation': operation,
        'key': key,
        'timestamp': timestamp,
        'device_fingerprint': await _securityService.generateDeviceFingerprint(),
      };
      
      // Store access log in cache with TTL
      final logKey = '${_accessLogKey}_${timestamp}_$operation';
      await storeCache(logKey, logEntry, ttl: const Duration(days: 30));
    } catch (e) {
      // Don't throw errors for logging failures
      Logger.error('Error logging storage access: $e');
    }
  }

  @override
  Future<bool> verifyStorageIntegrity() async {
    try {
      // Generate current integrity hash
      final currentHash = await _generateStorageIntegrityHash();
      
      // Compare with stored hash
      final storedHash = await getString(_integrityHashKey);
      
      if (storedHash == null) {
        // First time verification, store current hash
        await storeString(_integrityHashKey, currentHash);
        return true;
      }
      
      final isValid = currentHash == storedHash;
      
      // Log security event (placeholder)
      Logger.info('Security event: storage_integrity_check - passed: $isValid');
      
      if (!isValid) {
        // Update hash for next verification
        await storeString(_integrityHashKey, currentHash);
      }
      
      return isValid;
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      return false;
    }
  }

  @override
  Future<void> rotateEncryptionKeys() async {
    try {
      // This would implement key rotation logic in production
      // For now, we'll just log the event
      // _securityService.logSecurityEvent (placeholder)
      Logger.info('encryption_key_rotation');
      
      // In production, this would:
      // 1. Generate new encryption keys
      // 2. Re-encrypt existing data with new keys
      // 3. Safely destroy old keys
      // 4. Update key references
      
    } catch (e) {
      // Log security event (placeholder)
      Logger.info('Security event: storage_error - ${e.toString()}');
      rethrow;
    }
  }

  Future<String> _generateStorageIntegrityHash() async {
    try {
      // Generate hash of critical storage contents
      final criticalData = <String>[];
      
      // Add secure storage keys (without values for privacy)
      final secureKeys = await _secureStorage.readAll();
      for (final key in secureKeys.keys) {
        criticalData.add('secure:$key');
      }
      
      // Add shared preferences keys
      for (final key in _sharedPreferences.getKeys()) {
        criticalData.add('prefs:$key');
      }
      
      // Sort for consistent hashing
      criticalData.sort();
      
      // Generate hash
      final dataString = criticalData.join('|');
      final bytes = utf8.encode(dataString);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      throw Exception('Failed to generate storage integrity hash: $e');
    }
  }
}