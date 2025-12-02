import 'package:dio/dio.dart';
import '../../../../shared/services/encryption_service.dart';
import '../../../../shared/services/network_service.dart';
import '../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String name, String email, String password, String role);
  Future<void> logout();
  Future<void> refreshToken();
  Future<void> resetPassword(String email, String newPassword);
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
      final data = {
        'email': email,
        'password': password,
      };

      final response = await networkService.post(
        '/auth/login',
        data: data,
      );

      // API v3: Flat response with accessJwt, refreshToken, expiresIn, user
      final responseData = response.data;
      
      print('Login full response: $responseData');
      
      // Store access JWT in network service for future requests
      if (responseData['accessJwt'] != null) {
        networkService.setAuthToken(responseData['accessJwt']);
      }
      
      // TODO: Store refresh token in secure storage
      // final refreshToken = responseData['refreshToken'];
      
      // Extract user data from login response
      if (responseData['user'] == null) {
        throw Exception('Login response missing user data');
      }
      
      final userData = responseData['user'] as Map<String, dynamic>;
      print('Extracted user data: $userData');
      
      // Create user object and attach token
      final user = User.fromJson(userData);
      return user.copyWith(token: responseData['accessJwt']);
    } on DioException catch (e) {
      // Handle specific HTTP error codes
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid email or password. Please check your credentials.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Account not found. Please register first.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('Login failed: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> register(String name, String email, String password, String role) async {
    try {
      // API v3: Simple format with email, password, role (lowercase)
      final data = {
        'email': email,
        'password': password,
        'role': role.toLowerCase(), // API v3 uses lowercase roles
      };

      final response = await networkService.post(
        '/auth/register',
        data: data,
      );

      // API v3: Flat response with userId, accessJwt, refreshToken (no data wrapper)
      final responseData = response.data;
      
      // Store access JWT if provided
      if (responseData['accessJwt'] != null) {
        networkService.setAuthToken(responseData['accessJwt']);
      }
      
      // TODO: Store refresh token in secure storage
      // final refreshToken = responseData['refreshToken'];
      
      // API v3: Returns userId only, not full user object
      // We need to construct the user object manually or fetch it
      final userId = responseData['userId'];
      
      final user = User(
        id: userId,
        email: email,
        name: name, // We don't have name in response, use input
        role: role,
        token: responseData['accessJwt'],
      );
      
      return user;
    } on DioException catch (e) {
      // Handle specific HTTP error codes
      if (e.response?.statusCode == 409) {
        throw Exception('This email is already registered. Please use a different email or try logging in.');
      } else if (e.response?.statusCode == 400) {
        throw Exception('Invalid registration data. Please check your input.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('Registration failed: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await networkService.post('/auth/logout');
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      await networkService.post('/auth/refresh');
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }
  
  @override
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      final data = {
        'email': email,
        'newPassword': newPassword,
      };

      await networkService.post(
        '/auth/reset-password',
        data: data,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Account not found.');
      } else if (e.response?.statusCode == 400) {
        throw Exception('Invalid password format. Password must be at least 8 characters.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('Password reset failed: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }
}
