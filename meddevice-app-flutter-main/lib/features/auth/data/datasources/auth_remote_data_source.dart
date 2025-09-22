import '../../../../shared/services/encryption_service.dart';
import '../../../../shared/services/network_service.dart';
import '../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String name, String email, String password, String role);
  Future<void> logout();
  Future<void> refreshToken();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final NetworkService networkService;
  final EncryptionService encryptionService;

  AuthRemoteDataSourceImpl({
    required this.networkService,
    required this.encryptionService,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      // For demo purposes, we'll skip encryption
      final data = {
        'email': email,
        'password': password,
      };

      final response = await networkService.post(
        '/user/login',
        data: data,
      );

      return User.fromJson(response.data['user']);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> register(String name, String email, String password, String role) async {
    try {
      // For demo purposes, we'll skip encryption
      final data = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      };

      final response = await networkService.post(
        '/user/register',
        data: data,
      );

      return User.fromJson(response.data['user']);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await networkService.post('/user/logout');
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      await networkService.post('/user/refresh-token');
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }
}
