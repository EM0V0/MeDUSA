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

      // API v3: Flat response with accessJwt, refreshToken, expiresIn (no data wrapper)
      final responseData = response.data;
      
      // Store access JWT in network service for future requests
      if (responseData['accessJwt'] != null) {
        networkService.setAuthToken(responseData['accessJwt']);
      }
      
      // TODO: Store refresh token in secure storage
      // final refreshToken = responseData['refreshToken'];
      
      // API v3: Login doesn't return user object, need to fetch from /me endpoint
      // For now, create a minimal User object from email
      return User(
        id: '', // Will be populated from /me endpoint if needed
        email: email,
        name: email.split('@')[0], // Temporary name from email
        role: 'patient', // Default role
      );
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
      // Create User object with provided information
      return User(
        id: responseData['userId'] ?? '',
        email: email,
        name: name,
        role: role.toLowerCase(),
      );
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
