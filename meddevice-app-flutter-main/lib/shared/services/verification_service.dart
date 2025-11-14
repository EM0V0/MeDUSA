import 'package:flutter/foundation.dart';

/// Verification Service for managing verification codes
/// Handles verification code generation, storage, and validation
class VerificationService {
  static final VerificationService _instance = VerificationService._internal();
  factory VerificationService() => _instance;
  VerificationService._internal();
  
  // Store verification codes with expiration time
  final Map<String, _VerificationData> _codes = {};
  
  // Code expiration duration (default: 10 minutes)
  static const Duration codeExpiration = Duration(minutes: 10);
  
  // Maximum verification attempts (default: 3)
  static const int maxAttempts = 3;
  
  /// Store a verification code for an email
  void storeCode(String email, String code, {VerificationType type = VerificationType.registration}) {
    final normalizedEmail = email.toLowerCase().trim();
    _codes[normalizedEmail] = _VerificationData(
      code: code,
      expiresAt: DateTime.now().add(codeExpiration),
      attempts: 0,
      type: type,
    );
    
    debugPrint('[VerificationService] 💾 Stored verification code for: $normalizedEmail');
    debugPrint('[VerificationService] ⏰ Code expires at: ${_codes[normalizedEmail]!.expiresAt}');
  }
  
  /// Verify a code for an email
  VerificationResult verifyCode(String email, String code) {
    final normalizedEmail = email.toLowerCase().trim();
    
    // Check if code exists
    if (!_codes.containsKey(normalizedEmail)) {
      debugPrint('[VerificationService] ❌ No code found for: $normalizedEmail');
      return VerificationResult.codeNotFound;
    }
    
    final data = _codes[normalizedEmail]!;
    
    // Check if code is expired
    if (DateTime.now().isAfter(data.expiresAt)) {
      debugPrint('[VerificationService] ⏰ Code expired for: $normalizedEmail');
      _codes.remove(normalizedEmail);
      return VerificationResult.codeExpired;
    }
    
    // Check if max attempts reached
    if (data.attempts >= maxAttempts) {
      debugPrint('[VerificationService] 🚫 Max attempts reached for: $normalizedEmail');
      _codes.remove(normalizedEmail);
      return VerificationResult.maxAttemptsReached;
    }
    
    // Increment attempts
    data.attempts++;
    
    // Verify code
    if (data.code == code) {
      debugPrint('[VerificationService] ✅ Code verified successfully for: $normalizedEmail');
      _codes.remove(normalizedEmail); // Remove code after successful verification
      return VerificationResult.success;
    } else {
      debugPrint('[VerificationService] ❌ Invalid code for: $normalizedEmail (Attempt ${data.attempts}/$maxAttempts)');
      return VerificationResult.invalidCode;
    }
  }
  
  /// Check if a code exists and is valid for an email
  bool hasValidCode(String email) {
    final normalizedEmail = email.toLowerCase().trim();
    
    if (!_codes.containsKey(normalizedEmail)) {
      return false;
    }
    
    final data = _codes[normalizedEmail]!;
    
    // Check if expired
    if (DateTime.now().isAfter(data.expiresAt)) {
      _codes.remove(normalizedEmail);
      return false;
    }
    
    return true;
  }
  
  /// Get remaining time for a code
  Duration? getRemainingTime(String email) {
    final normalizedEmail = email.toLowerCase().trim();
    
    if (!_codes.containsKey(normalizedEmail)) {
      return null;
    }
    
    final data = _codes[normalizedEmail]!;
    final remaining = data.expiresAt.difference(DateTime.now());
    
    if (remaining.isNegative) {
      _codes.remove(normalizedEmail);
      return null;
    }
    
    return remaining;
  }
  
  /// Get remaining attempts for a code
  int? getRemainingAttempts(String email) {
    final normalizedEmail = email.toLowerCase().trim();
    
    if (!_codes.containsKey(normalizedEmail)) {
      return null;
    }
    
    final data = _codes[normalizedEmail]!;
    return maxAttempts - data.attempts;
  }
  
  /// Remove a verification code
  void removeCode(String email) {
    final normalizedEmail = email.toLowerCase().trim();
    _codes.remove(normalizedEmail);
    debugPrint('[VerificationService] 🗑️ Removed code for: $normalizedEmail');
  }
  
  /// Clear all verification codes (for testing or cleanup)
  void clearAll() {
    _codes.clear();
    debugPrint('[VerificationService] 🧹 Cleared all verification codes');
  }
}

/// Internal class to store verification data
class _VerificationData {
  final String code;
  final DateTime expiresAt;
  int attempts;
  final VerificationType type;
  
  _VerificationData({
    required this.code,
    required this.expiresAt,
    required this.attempts,
    required this.type,
  });
}

/// Verification result enum
enum VerificationResult {
  success,
  invalidCode,
  codeExpired,
  codeNotFound,
  maxAttemptsReached,
}

/// Verification type enum
enum VerificationType {
  registration,
  passwordReset,
}

/// Extension to get user-friendly messages
extension VerificationResultExtension on VerificationResult {
  String get message {
    switch (this) {
      case VerificationResult.success:
        return 'Verification successful!';
      case VerificationResult.invalidCode:
        return 'Invalid verification code. Please try again.';
      case VerificationResult.codeExpired:
        return 'Verification code has expired. Please request a new code.';
      case VerificationResult.codeNotFound:
        return 'No verification code found. Please request a code first.';
      case VerificationResult.maxAttemptsReached:
        return 'Maximum verification attempts reached. Please request a new code.';
    }
  }
}

