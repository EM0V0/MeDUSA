import 'package:dio/dio.dart';
import '../../../../shared/services/encryption_service.dart';
import '../../../../shared/services/network_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/exceptions/auth_exceptions.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> mfaLogin(String tempToken, String code);
  Future<User> register(String name, String email, String password, String role, {String? verificationCode});
  Future<void> logout();
  Future<void> refreshToken();
  Future<void> resetPassword(String email, String newPassword);
  Future<bool> requestVerification(String email, String type);
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
      
      // Debug logging removed for production

      // Check for MFA requirement
      if (responseData['mfaRequired'] == true) {
        final tempToken = responseData['tempToken'];
        if (tempToken != null) {
           throw MfaRequiredException(tempToken: tempToken);
        }
      }
      
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
      
      // Create user object and attach token
      final user = User.fromJson(userData);
      return user.copyWith(token: responseData['accessJwt']);
    } on DioException catch (e) {
      // Handle specific HTTP error codes
      if (e.response?.statusCode == 429) {
        final detail = e.response?.data;
        final code = detail?['detail']?['code'] ?? 'RATE_LIMIT_EXCEEDED';
        final message = detail?['detail']?['message'] ?? 'Too many login attempts.';
        final retryAfter = detail?['detail']?['retryAfter'] ?? '';
        throw Exception('Bad response: 429 - {detail: {code: $code, message: $message, retryAfter: $retryAfter}}');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Invalid email or password. Please check your credentials.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Account not found. Please register first.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('Login failed: ${e.message ?? 'Unknown error'}');
      }
    } on MfaRequiredException {
      rethrow;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> mfaLogin(String tempToken, String code) async {
    try {
      final data = {
        'tempToken': tempToken,
        'code': code,
      };

      final response = await networkService.post(
        '/auth/mfa/login',
        data: data,
      );

      final responseData = response.data;
      
      // Store access JWT in network service for future requests
      if (responseData['accessJwt'] != null) {
        networkService.setAuthToken(responseData['accessJwt']);
      }
      
      // Extract user data from login response
      if (responseData['user'] == null) {
        throw Exception('MFA Login response missing user data');
      }
      
      final userData = responseData['user'] as Map<String, dynamic>;
      
      // Create user object and attach token
      final user = User.fromJson(userData);
      return user.copyWith(token: responseData['accessJwt']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid MFA code.');
      } else {
        throw Exception('MFA Login failed: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('MFA Login failed: $e');
    }
  }

  @override
  Future<User> register(String name, String email, String password, String role, {String? verificationCode}) async {
    try {
      // API v3: Simple format with email, password, role (lowercase)
      final data = {
        'email': email,
        'password': password,
        'role': role.toLowerCase(), // API v3 uses lowercase roles
        if (verificationCode != null) 'verificationCode': verificationCode,
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
      final mfaSecret = responseData['mfaSecret'];
      
      final user = User(
        id: userId,
        email: email,
        name: name, // We don't have name in response, use input
        role: role,
        token: responseData['accessJwt'],
        mfaSecret: mfaSecret,
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

  @override
  Future<bool> requestVerification(String email, String type) async {
    try {
      final response = await networkService.post(
        '/auth/request-verification',
        data: {
          'email': email,
          'type': type,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('This email is already registered.');
      } else if (e.response?.statusCode == 429) {
        throw Exception('Too many requests. Please wait 60 seconds.');
      } else {
        throw Exception('Failed to send verification code: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Failed to send verification code: $e');
    }
  }
}
