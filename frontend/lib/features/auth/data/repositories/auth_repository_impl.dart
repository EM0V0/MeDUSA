import 'package:flutter/foundation.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/exceptions/auth_exceptions.dart';
import '../../../../shared/services/email_service.dart';
import '../../../../shared/services/verification_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final EmailService emailService;
  final VerificationService verificationService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.emailService,
    required this.verificationService,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      // Attempt remote login
      final user = await remoteDataSource.login(email, password);
      
      // Save token if present
      if (user.token != null) {
        await localDataSource.saveToken(user.token!);
      }
      
      // Cache user data locally
      await localDataSource.cacheUser(user);
      
      return user;
    } on MfaRequiredException {
      rethrow;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> mfaLogin(String tempToken, String code) async {
    try {
      // Attempt remote mfa login
      final user = await remoteDataSource.mfaLogin(tempToken, code);
      
      // Save token if present
      if (user.token != null) {
        await localDataSource.saveToken(user.token!);
      }
      
      // Cache user data locally
      await localDataSource.cacheUser(user);
      
      return user;
    } catch (e) {
      throw Exception('MFA Login failed: $e');
    }
  }

  @override
  Future<User> register(String name, String email, String password, String role, {String? verificationCode}) async {
    try {
      // Attempt remote registration with verification code
      final user = await remoteDataSource.register(name, email, password, role, verificationCode: verificationCode);
      
      // Save token if present
      if (user.token != null) {
        await localDataSource.saveToken(user.token!);
      }
      
      // Cache user data locally
      await localDataSource.cacheUser(user);
      
      return user;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Attempt remote logout
      await remoteDataSource.logout();
    } catch (e) {
      // Continue with local logout even if remote fails
      debugPrint('Remote logout failed: $e');
    } finally {
      // Always clear local data
      await localDataSource.clearUser();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      // Get cached user from local storage
      return await localDataSource.getLastUser();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      await remoteDataSource.refreshToken();
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }
  
  @override
  Future<bool> sendVerificationCode(String email) async {
    try {
      // Call backend /auth/request-verification - backend generates, stores, and emails the code
      return await remoteDataSource.requestVerification(email, 'registration');
    } catch (e) {
      throw Exception('Failed to send verification code: $e');
    }
  }
  
  @override
  Future<bool> verifyEmail(String email, String code) async {
    try {
      // Store code locally - actual verification happens during registration on backend
      verificationService.storeCode(
        email,
        code,
        type: VerificationType.registration,
      );
      return true;
    } catch (e) {
      throw Exception('Email verification failed: $e');
    }
  }
  
  @override
  Future<bool> requestPasswordReset(String email) async {
    try {
      // Generate reset code
      final code = emailService.generateVerificationCode();
      
      // Store code for verification
      verificationService.storeCode(
        email,
        code,
        type: VerificationType.passwordReset,
      );
      
      // Send code via email
      final sent = await emailService.sendPasswordResetEmail(email, code);
      
      if (!sent) {
        throw Exception('Failed to send password reset code');
      }
      
      return true;
    } catch (e) {
      throw Exception('Failed to request password reset: $e');
    }
  }
  
  @override
  Future<bool> verifyResetCode(String email, String code) async {
    try {
      final result = verificationService.verifyCode(email, code);
      
      if (result == VerificationResult.success) {
        // Store the code again for password reset step
        verificationService.storeCode(
          email,
          code,
          type: VerificationType.passwordReset,
        );
        return true;
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      throw Exception('Reset code verification failed: $e');
    }
  }
  
  @override
  Future<bool> resetPassword(String email, String newPassword, String code) async {
    try {
      // Verify code one more time before resetting password
      final result = verificationService.verifyCode(email, code);
      
      if (result != VerificationResult.success) {
        throw Exception(result.message);
      }
      
      // Call remote data source to reset password
      await remoteDataSource.resetPassword(email, newPassword);
      
      return true;
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }
}