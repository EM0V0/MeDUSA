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

  AuthLocalDataSourceImpl({required this.storageService});

  @override
  Future<User?> getLastUser() async {
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

  @override
  Future<void> cacheUser(User user) async {
    try {
      await storageService.storeUser(user.toJson());
    } catch (e) {
      throw Exception('Failed to cache user: $e');
    }
  }

  @override
  Future<void> clearUser() async {
    try {
      await storageService.deleteUser();
    } catch (e) {
      throw Exception('Failed to clear user: $e');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await storageService.getSecureString('auth_token');
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveToken(String token) async {
    try {
      await storageService.setSecureString('auth_token', token);
    } catch (e) {
      throw Exception('Failed to save token: $e');
    }
  }

  @override
  Future<void> clearToken() async {
    try {
      await storageService.removeSecure('auth_token');
    } catch (e) {
      throw Exception('Failed to clear token: $e');
    }
  }
}
