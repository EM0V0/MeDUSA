import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

/// Two-Factor Authentication service for generating and validating TOTP codes
/// Provides secure 2FA setup, QR code generation, and code verification
class TwoFactorAuthService extends ChangeNotifier {
  static final TwoFactorAuthService _instance = TwoFactorAuthService._internal();
  factory TwoFactorAuthService() => _instance;
  TwoFactorAuthService._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // 2FA Configuration
  static const String _issuer = 'MedDevice Security';
  static const int _secretLength = 32;
  static const int _codeLength = 6;
  static const int _timeStep = 30;
  static const int _windowSize = 1; // Allow 1 step before/after for clock skew

  // Storage keys
  static const String _secretKey = 'totp_secret';
  static const String _enabledKey = 'totp_enabled';
  static const String _backupCodesKey = 'backup_codes';
  static const String _lastUsedCodeKey = 'last_used_code';

  // State
  bool _isEnabled = false;
  String? _secret;
  List<String> _backupCodes = [];
  String? _lastUsedCode;

  // Getters
  bool get isEnabled => _isEnabled;
  String? get secret => _secret;
  List<String> get backupCodes => List.unmodifiable(_backupCodes);
  bool get isSetup => _secret != null && _secret!.isNotEmpty;

  /// Initialize 2FA service and load existing configuration
  Future<void> initialize() async {
    try {
      // Load existing configuration
      final enabledStr = await _secureStorage.read(key: _enabledKey);
      _isEnabled = enabledStr == 'true';

      _secret = await _secureStorage.read(key: _secretKey);

      final backupCodesStr = await _secureStorage.read(key: _backupCodesKey);
      if (backupCodesStr != null) {
        final List<dynamic> codesList = jsonDecode(backupCodesStr);
        _backupCodes = codesList.cast<String>();
      }

      _lastUsedCode = await _secureStorage.read(key: _lastUsedCodeKey);

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing 2FA service: $e');
    }
  }

  /// Generate a new TOTP secret for 2FA setup
  Future<String> generateSecret() async {
    try {
      final random = Random.secure();
      final bytes = Uint8List(_secretLength);
      for (int i = 0; i < _secretLength; i++) {
        bytes[i] = random.nextInt(256);
      }
      
      // Convert to base32
      final secret = _base32Encode(bytes);
      
      // Store temporarily (not enabled until verified)
      _secret = secret;
      await _secureStorage.write(key: _secretKey, value: secret);
      
      // Generate backup codes
      await _generateBackupCodes();
      
      notifyListeners();
      return secret;
    } catch (e) {
      throw Exception('Failed to generate 2FA secret: $e');
    }
  }

  /// Generate QR code URL for authenticator apps
  String getQRCodeUrl(String userEmail) {
    if (_secret == null) {
      throw Exception('2FA secret not generated');
    }

    final params = {
      'secret': _secret!,
      'issuer': _issuer,
      'algorithm': 'SHA1',
      'digits': _codeLength.toString(),
      'period': _timeStep.toString(),
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'otpauth://totp/$_issuer:$userEmail?$queryString';
  }

  /// Get current TOTP code (for testing/display purposes)
  String getCurrentCode() {
    if (_secret == null) {
      throw Exception('2FA not setup');
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return OTP.generateTOTPCodeString(
      _secret!,
      now,
      length: _codeLength,
      interval: _timeStep,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  /// Get time remaining for current code
  int getTimeRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _timeStep - (now % _timeStep);
  }

  /// Verify TOTP code
  Future<bool> verifyCode(String code, {bool isBackupCode = false}) async {
    try {
      if (!_isEnabled && !isSetup) {
        throw Exception('2FA not enabled');
      }

      // Check if it's a backup code
      if (isBackupCode || _backupCodes.contains(code)) {
        return await _verifyBackupCode(code);
      }

      // Verify TOTP code
      return await _verifyTOTPCode(code);
    } catch (e) {
      debugPrint('Error verifying 2FA code: $e');
      return false;
    }
  }

  /// Verify TOTP code with time window
  Future<bool> _verifyTOTPCode(String code) async {
    if (_secret == null) return false;

    // Prevent code reuse
    if (code == _lastUsedCode) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Check current time and window around it
    for (int i = -_windowSize; i <= _windowSize; i++) {
      final time = now + (i * _timeStep);
      final expectedCode = OTP.generateTOTPCodeString(
        _secret!,
        time,
        length: _codeLength,
        interval: _timeStep,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      if (code == expectedCode) {
        // Store last used code to prevent reuse
        _lastUsedCode = code;
        await _secureStorage.write(key: _lastUsedCodeKey, value: code);
        return true;
      }
    }

    return false;
  }

  /// Verify backup code
  Future<bool> _verifyBackupCode(String code) async {
    if (!_backupCodes.contains(code)) {
      return false;
    }

    // Remove used backup code
    _backupCodes.remove(code);
    await _secureStorage.write(key: _backupCodesKey, value: jsonEncode(_backupCodes));
    notifyListeners();

    return true;
  }

  /// Enable 2FA after successful verification
  Future<void> enable() async {
    try {
      if (_secret == null) {
        throw Exception('2FA secret not generated');
      }

      _isEnabled = true;
      await _secureStorage.write(key: _enabledKey, value: 'true');
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to enable 2FA: $e');
    }
  }

  /// Disable 2FA
  Future<void> disable() async {
    try {
      _isEnabled = false;
      await _secureStorage.write(key: _enabledKey, value: 'false');
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to disable 2FA: $e');
    }
  }

  /// Reset 2FA (remove all data)
  Future<void> reset() async {
    try {
      _isEnabled = false;
      _secret = null;
      _backupCodes.clear();
      _lastUsedCode = null;

      await _secureStorage.delete(key: _enabledKey);
      await _secureStorage.delete(key: _secretKey);
      await _secureStorage.delete(key: _backupCodesKey);
      await _secureStorage.delete(key: _lastUsedCodeKey);

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to reset 2FA: $e');
    }
  }

  /// Generate backup codes
  Future<void> _generateBackupCodes() async {
    try {
      final random = Random.secure();
      _backupCodes.clear();

      for (int i = 0; i < 10; i++) {
        // Generate 8-digit backup code
        final code = (random.nextInt(90000000) + 10000000).toString();
        _backupCodes.add(code);
      }

      await _secureStorage.write(key: _backupCodesKey, value: jsonEncode(_backupCodes));
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to generate backup codes: $e');
    }
  }

  /// Regenerate backup codes
  Future<void> regenerateBackupCodes() async {
    await _generateBackupCodes();
  }

  /// Get 2FA status information
  Map<String, dynamic> getStatus() {
    return {
      'isEnabled': _isEnabled,
      'isSetup': isSetup,
      'hasBackupCodes': _backupCodes.isNotEmpty,
      'backupCodesCount': _backupCodes.length,
      'currentCode': isSetup ? getCurrentCode() : null,
      'timeRemaining': isSetup ? getTimeRemaining() : null,
    };
  }

  /// Base32 encoding for TOTP secret
  String _base32Encode(Uint8List bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    String result = '';
    
    for (int i = 0; i < bytes.length; i += 5) {
      int buffer = 0;
      int bufferLength = 0;
      
      for (int j = 0; j < 5 && i + j < bytes.length; j++) {
        buffer = (buffer << 8) | bytes[i + j];
        bufferLength += 8;
      }
      
      while (bufferLength >= 5) {
        bufferLength -= 5;
        result += alphabet[(buffer >> bufferLength) & 31];
      }
      
      if (bufferLength > 0) {
        result += alphabet[(buffer << (5 - bufferLength)) & 31];
      }
    }
    
    return result;
  }

  /// Validate TOTP code format
  bool isValidCodeFormat(String code) {
    if (code.length != _codeLength) return false;
    return RegExp(r'^\d{6}$').hasMatch(code);
  }

  /// Check if backup code format is valid
  bool isValidBackupCodeFormat(String code) {
    if (code.length != 8) return false;
    return RegExp(r'^\d{8}$').hasMatch(code);
  }

  /// Get setup instructions
  List<String> getSetupInstructions() {
    return [
      '1. Install an authenticator app like Google Authenticator or Authy',
      '2. Scan the QR code with your authenticator app',
      '3. Enter the 6-digit code from your app to verify setup',
      '4. Save your backup codes in a secure location',
      '5. You\'ll need to enter a code from your app each time you log in',
    ];
  }

  /// Dispose service
  @override
  void dispose() {
    super.dispose();
  }
}
