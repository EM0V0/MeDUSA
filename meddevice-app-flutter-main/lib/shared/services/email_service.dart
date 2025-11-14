import 'dart:math';
import 'package:flutter/foundation.dart';
import 'network_service.dart';

/// Email Service for sending verification codes and notifications
/// Provides functionality for email verification during registration and password reset
abstract class EmailService {
  /// Send verification code to email
  Future<bool> sendVerificationCode(String email, String code);
  
  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email, String code);
  
  /// Generate a random 6-digit verification code
  String generateVerificationCode();
}

class EmailServiceImpl implements EmailService {
  final NetworkService networkService;
  
  EmailServiceImpl({required this.networkService});
  
  @override
  Future<bool> sendVerificationCode(String email, String code) async {
    try {
      debugPrint('[EmailService] 📧 Sending verification code to: $email');
      
      final response = await networkService.post(
        '/auth/send-verification-code',
        data: {
          'email': email,
          'code': code,
          'type': 'registration',
        },
      );
      
      debugPrint('[EmailService] ✅ Verification code sent successfully');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[EmailService] ❌ Failed to send verification code: $e');
      return false;
    }
  }
  
  @override
  Future<bool> sendPasswordResetEmail(String email, String code) async {
    try {
      debugPrint('[EmailService] 📧 Sending password reset code to: $email');
      
      final response = await networkService.post(
        '/auth/send-password-reset-code',
        data: {
          'email': email,
          'code': code,
          'type': 'password_reset',
        },
      );
      
      debugPrint('[EmailService] ✅ Password reset code sent successfully');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[EmailService] ❌ Failed to send password reset code: $e');
      return false;
    }
  }
  
  @override
  String generateVerificationCode() {
    // Generate a random 6-digit code
    final random = Random.secure();
    final code = (random.nextInt(900000) + 100000).toString();
    debugPrint('[EmailService] 🔢 Generated verification code: $code');
    return code;
  }
}

// Mock implementation has been removed - use real email service only

