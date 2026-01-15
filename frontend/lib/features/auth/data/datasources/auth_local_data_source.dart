import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user.dart';

abstract class AuthLocalDataSource {
  Future<User?> getLastUser();
  Future<void> cacheUser(User user);
  Future<void> clearUser();
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  // Using dynamic here to avoid analyzer resolution issues while preserving behavior
  final dynamic storageService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthLocalDataSourceImpl({this.storageService});

  @override
  Future<User?> getLastUser() async {
    if (storageService != null) {
      try {
        final userData = await storageService.getUser();
        if (userData != null) {
          return User.fromJson(userData);
        }
        return null;
      } catch (e) {
        return null;
      }
    }
    
    try {
      final jsonStr = await _secureStorage.read(key: 'user_data');
      if (jsonStr != null) {
        return User.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      // Ignore error
    }
    return null;
  }

  @override
  Future<void> cacheUser(User user) async {
    if (storageService != null) {
      try {
        await storageService.storeUser(user.toJson());
        return;
      } catch (e) {
        throw Exception('Failed to cache user: $e');
      }
    }
    
    try {
      await _secureStorage.write(key: 'user_data', value: jsonEncode(user.toJson()));
    } catch (e) {
      throw Exception('Failed to cache user: $e');
    }
  }

  @override
  Future<void> clearUser() async {
    if (storageService != null) {
      try {
        await storageService.deleteUser();
        return;
      } catch (e) {
        throw Exception('Failed to clear user: $e');
      }
    }
    
    await _secureStorage.delete(key: 'user_data');
  }

  @override
  Future<String?> getToken() async {
    if (storageService != null) {
      try {
        return await storageService.getSecureString('auth_token');
      } catch (e) {
        return null;
      }
    }
    return await _secureStorage.read(key: 'auth_token');
  }

  @override
  Future<void> saveToken(String token) async {
    if (storageService != null) {
      try {
        await storageService.setSecureString('auth_token', token);
        return;
      } catch (e) {
        throw Exception('Failed to save token: $e');
      }
    }
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  @override
  Future<void> clearToken() async {
    if (storageService != null) {
      try {
        await storageService.removeSecure('auth_token');
        return;
      } catch (e) {
        throw Exception('Failed to clear token: $e');
      }
    }
    await _secureStorage.delete(key: 'auth_token');
  }
}
