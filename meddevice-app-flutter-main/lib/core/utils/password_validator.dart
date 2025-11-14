import '../constants/app_constants.dart';

/// Password validation utility class
/// 
/// Provides comprehensive password strength validation according to:
/// - Minimum length requirement
/// - Uppercase letter requirement
/// - Lowercase letter requirement
/// - Digit requirement
/// - Special character requirement
class PasswordValidator {
  /// Validate password strength and return error message if invalid
  /// 
  /// Returns null if password is valid, otherwise returns error message
  static String? validate(String password) {
    // Check minimum length
    if (password.length < AppConstants.passwordMinLength) {
      return 'Password must be at least ${AppConstants.passwordMinLength} characters';
    }

    // Check uppercase requirement
    if (AppConstants.passwordRequireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check lowercase requirement
    if (AppConstants.passwordRequireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check digit requirement
    if (AppConstants.passwordRequireDigit && !password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check special character requirement
    if (AppConstants.passwordRequireSpecialChar) {
      final specialChars = AppConstants.passwordSpecialChars.split('').map((c) => RegExp.escape(c)).join('');
      if (!password.contains(RegExp('[$specialChars]'))) {
        return 'Password must contain at least one special character (${AppConstants.passwordSpecialChars})';
      }
    }

    return null; // Password is valid
  }

  /// Calculate password strength score (0-4)
  /// 
  /// 0 = Very Weak (fails requirements)
  /// 1 = Weak (meets minimum requirements)
  /// 2 = Fair (meets requirements + some extra)
  /// 3 = Good (strong password)
  /// 4 = Excellent (very strong password)
  static int calculateStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // Base score for meeting minimum length
    if (password.length >= AppConstants.passwordMinLength) {
      score++;
    }

    // Additional points for length
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Points for character variety
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    
    final specialChars = AppConstants.passwordSpecialChars.split('').map((c) => RegExp.escape(c)).join('');
    if (password.contains(RegExp('[$specialChars]'))) score++;

    // Cap at 4
    if (score > 4) score = 4;

    // Penalize if doesn't meet basic requirements
    if (validate(password) != null) {
      return 0;
    }

    // Adjust score to 1-4 range if valid
    if (score < 1) score = 1;

    return score;
  }

  /// Get password strength label
  static String getStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Excellent';
      default:
        return 'Unknown';
    }
  }

  /// Get password strength color
  /// Returns color code as hex string
  static String getStrengthColor(int strength) {
    switch (strength) {
      case 0:
        return '#DC2626'; // Red-600
      case 1:
        return '#EA580C'; // Orange-600
      case 2:
        return '#F59E0B'; // Amber-500
      case 3:
        return '#10B981'; // Green-500
      case 4:
        return '#059669'; // Green-600
      default:
        return '#6B7280'; // Gray-500
    }
  }

  /// Get all password requirements as a list
  static List<PasswordRequirement> getRequirements() {
    return [
      PasswordRequirement(
        label: 'At least ${AppConstants.passwordMinLength} characters',
        validator: (pwd) => pwd.length >= AppConstants.passwordMinLength,
      ),
      if (AppConstants.passwordRequireUppercase)
        PasswordRequirement(
          label: 'At least one uppercase letter (A-Z)',
          validator: (pwd) => pwd.contains(RegExp(r'[A-Z]')),
        ),
      if (AppConstants.passwordRequireLowercase)
        PasswordRequirement(
          label: 'At least one lowercase letter (a-z)',
          validator: (pwd) => pwd.contains(RegExp(r'[a-z]')),
        ),
      if (AppConstants.passwordRequireDigit)
        PasswordRequirement(
          label: 'At least one number (0-9)',
          validator: (pwd) => pwd.contains(RegExp(r'[0-9]')),
        ),
      if (AppConstants.passwordRequireSpecialChar)
        PasswordRequirement(
          label: 'At least one special character (${AppConstants.passwordSpecialChars.substring(0, 10)}...)',
          validator: (pwd) {
            final specialChars = AppConstants.passwordSpecialChars.split('').map((c) => RegExp.escape(c)).join('');
            return pwd.contains(RegExp('[$specialChars]'));
          },
        ),
    ];
  }

  /// Check if password meets all requirements
  static bool meetsAllRequirements(String password) {
    return validate(password) == null;
  }
}

/// Password requirement model
class PasswordRequirement {
  final String label;
  final bool Function(String) validator;

  PasswordRequirement({
    required this.label,
    required this.validator,
  });

  /// Check if this requirement is met
  bool isMet(String password) {
    return validator(password);
  }
}

