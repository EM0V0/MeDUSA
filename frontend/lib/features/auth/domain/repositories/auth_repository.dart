import '../entities/user.dart';

abstract class AuthRepository {
  // Authentication
  Future<User> login(String email, String password);
  Future<User> mfaLogin(String tempToken, String code);
  Future<User> register(String name, String email, String password, String role, {String? verificationCode});
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> isLoggedIn();
  Future<void> refreshToken();
  
  // Email Verification
  Future<bool> sendVerificationCode(String email);
  Future<bool> verifyEmail(String email, String code);
  
  // Password Reset
  Future<bool> requestPasswordReset(String email);
  Future<bool> verifyResetCode(String email, String code);
  Future<bool> resetPassword(String email, String newPassword, String code);
}
