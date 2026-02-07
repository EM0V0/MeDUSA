import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'network_service.dart';

/// Security feature model representing a single security control
class SecurityFeature {
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final String category;
  final String riskIfDisabled;
  final String fdaRequirement;
  final String educationalExplanation;
  final String codeLocation;
  final String? cweReference;
  final String? owaspReference;

  SecurityFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.category,
    required this.riskIfDisabled,
    required this.fdaRequirement,
    required this.educationalExplanation,
    required this.codeLocation,
    this.cweReference,
    this.owaspReference,
  });

  factory SecurityFeature.fromJson(Map<String, dynamic> json) {
    return SecurityFeature(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      enabled: json['enabled'] as bool,
      category: json['category'] as String,
      riskIfDisabled: json['riskIfDisabled'] as String,
      fdaRequirement: json['fdaRequirement'] as String,
      educationalExplanation: json['educationalExplanation'] as String,
      codeLocation: json['codeLocation'] as String,
      cweReference: json['cweReference'] as String?,
      owaspReference: json['owaspReference'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'category': category,
    'riskIfDisabled': riskIfDisabled,
    'fdaRequirement': fdaRequirement,
    'educationalExplanation': educationalExplanation,
    'codeLocation': codeLocation,
    'cweReference': cweReference,
    'owaspReference': owaspReference,
  };
}

/// Security configuration model
class SecurityConfig {
  final String mode;
  final bool educationalLogging;
  final List<SecurityFeature> features;
  final List<String> categories;

  SecurityConfig({
    required this.mode,
    required this.educationalLogging,
    required this.features,
    required this.categories,
  });

  factory SecurityConfig.fromJson(Map<String, dynamic> json) {
    final featuresJson = json['features'] as List<dynamic>? ?? [];
    return SecurityConfig(
      mode: json['mode'] as String? ?? 'secure',
      educationalLogging: json['educationalLogging'] as bool? ?? false,
      features: featuresJson.map((f) => SecurityFeature.fromJson(f as Map<String, dynamic>)).toList(),
      categories: (json['categories'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  List<SecurityFeature> getFeaturesByCategory(String category) {
    return features.where((f) => f.category == category).toList();
  }

  int get enabledCount => features.where((f) => f.enabled).length;
  int get totalCount => features.length;
}

/// Password hashing demonstration result
class PasswordHashingDemo {
  final String inputPassword;
  final String hashedOutput;
  final int hashLength;
  final String algorithm;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> timing;
  final Map<String, dynamic> securityExplanation;

  PasswordHashingDemo({
    required this.inputPassword,
    required this.hashedOutput,
    required this.hashLength,
    required this.algorithm,
    required this.parameters,
    required this.timing,
    required this.securityExplanation,
  });

  factory PasswordHashingDemo.fromJson(Map<String, dynamic> json) {
    return PasswordHashingDemo(
      inputPassword: json['inputPassword'] as String,
      hashedOutput: json['hashedOutput'] as String,
      hashLength: json['hashLength'] as int,
      algorithm: json['algorithm'] as String,
      parameters: json['parameters'] as Map<String, dynamic>,
      timing: json['timing'] as Map<String, dynamic>,
      securityExplanation: json['securityExplanation'] as Map<String, dynamic>,
    );
  }
}

/// JWT token demonstration result
class JwtTokenDemo {
  final String fullToken;
  final Map<String, dynamic> tokenParts;
  final Map<String, dynamic> security;
  final Map<String, dynamic> attackPrevention;

  JwtTokenDemo({
    required this.fullToken,
    required this.tokenParts,
    required this.security,
    required this.attackPrevention,
  });

  factory JwtTokenDemo.fromJson(Map<String, dynamic> json) {
    return JwtTokenDemo(
      fullToken: json['fullToken'] as String,
      tokenParts: json['tokenParts'] as Map<String, dynamic>,
      security: json['security'] as Map<String, dynamic>,
      attackPrevention: json['attackPrevention'] as Map<String, dynamic>,
    );
  }
}

/// RBAC demonstration result
class RbacDemo {
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic> permissionMatrix;
  final Map<String, dynamic> roles;
  final Map<String, dynamic> implementation;

  RbacDemo({
    required this.currentUser,
    required this.permissionMatrix,
    required this.roles,
    required this.implementation,
  });

  factory RbacDemo.fromJson(Map<String, dynamic> json) {
    return RbacDemo(
      currentUser: json['currentUser'] as Map<String, dynamic>,
      permissionMatrix: json['permissionMatrix'] as Map<String, dynamic>,
      roles: json['roles'] as Map<String, dynamic>,
      implementation: json['implementation'] as Map<String, dynamic>,
    );
  }
}

/// Replay protection demonstration result
class ReplayProtectionDemo {
  final String generatedNonce;
  final Map<String, dynamic> nonceFormat;
  final Map<String, dynamic> validationTest;
  final Map<String, dynamic> attackPrevention;
  final List<String> workflow;

  ReplayProtectionDemo({
    required this.generatedNonce,
    required this.nonceFormat,
    required this.validationTest,
    required this.attackPrevention,
    required this.workflow,
  });

  factory ReplayProtectionDemo.fromJson(Map<String, dynamic> json) {
    return ReplayProtectionDemo(
      generatedNonce: json['generatedNonce'] as String,
      nonceFormat: json['nonceFormat'] as Map<String, dynamic>,
      validationTest: json['validationTest'] as Map<String, dynamic>,
      attackPrevention: json['attackPrevention'] as Map<String, dynamic>,
      workflow: (json['workflow'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Security Education Service
/// 
/// Provides access to security education features and demonstrations.
/// This service helps users understand how each security feature works
/// and why it's important for medical device security.
/// 
/// OFFLINE MODE: When the backend is unreachable, the service maintains
/// local state for feature toggles to enable educational demonstrations.
class SecurityEducationService {
  final NetworkService _networkService;
  
  /// Local state for offline mode
  static bool _offlineMode = false;
  static String _currentMode = 'educational';
  static final Map<String, bool> _localFeatureStates = {
    'password_complexity': true,
    'password_hashing': true,
    'input_validation': true,
    'mfa_totp': true,
    'jwt_authentication': true,
    'rate_limiting': true,
    'replay_protection': true,
    'audit_logging': true,
    'tls_https': true,
    'certificate_pinning': true,
    'rbac': true,
    'session_management': true,
  };
  
  SecurityEducationService({NetworkService? networkService})
      : _networkService = networkService ?? NetworkServiceImpl.secure();

  /// Check if running in offline/local mode
  static bool get isOfflineMode => _offlineMode;
  
  /// Get current mode (local or from backend)
  static String get currentMode => _currentMode;

  /// Check if a feature is enabled (works offline)
  static bool isFeatureEnabled(String featureId) {
    return _localFeatureStates[featureId] ?? true;
  }

  /// Toggle a feature locally (for UI responsiveness)
  static void toggleFeatureLocally(String featureId, bool enabled) {
    _localFeatureStates[featureId] = enabled;
    debugPrint('SecurityEducationService: Toggled $featureId to $enabled (local)');
  }

  /// Set mode locally
  static void setModeLocally(String mode) {
    _currentMode = mode;
    debugPrint('SecurityEducationService: Mode set to $mode (local)');
    
    // If secure mode, enable all features
    if (mode == 'secure') {
      _localFeatureStates.updateAll((key, value) => true);
    }
  }

  /// Get default offline config
  static SecurityConfig getDefaultConfig() {
    return SecurityConfig(
      mode: _currentMode,
      educationalLogging: true,
      categories: ['Authentication', 'Authorization', 'Transport Security', 'Replay Protection', 'Audit & Logging', 'Input Validation', 'Secure Storage', 'Rate Limiting'],
      features: [
        SecurityFeature(
          id: 'password_complexity',
          name: 'Password Complexity',
          description: 'Enforces strong password requirements (12+ chars, mixed case, numbers, symbols)',
          enabled: _localFeatureStates['password_complexity'] ?? true,
          category: 'Authentication',
          riskIfDisabled: 'Weak passwords can be easily brute-forced',
          fdaRequirement: 'FDA Premarket Guidance 2023: Authentication Controls',
          educationalExplanation: 'Strong passwords are the first line of defense',
          codeLocation: 'backend-py/password_validator.py',
          cweReference: 'CWE-521',
        ),
        SecurityFeature(
          id: 'password_hashing',
          name: 'Argon2id Password Hashing',
          description: 'Uses Argon2id (memory-hard) algorithm for secure password storage',
          enabled: _localFeatureStates['password_hashing'] ?? true,
          category: 'Authentication',
          riskIfDisabled: 'Stored passwords could be reverse-engineered',
          fdaRequirement: 'FDA Premarket Guidance 2023: Cryptographic Protection',
          educationalExplanation: 'Modern password hashing prevents rainbow table attacks',
          codeLocation: 'backend-py/auth.py',
          cweReference: 'CWE-916',
        ),
        SecurityFeature(
          id: 'mfa_totp',
          name: 'Multi-Factor Authentication (TOTP)',
          description: 'Time-based One-Time Password for additional login security',
          enabled: _localFeatureStates['mfa_totp'] ?? true,
          category: 'Authentication',
          riskIfDisabled: 'Account compromise with stolen password',
          fdaRequirement: 'FDA Premarket Guidance 2023: Multi-Factor Authentication',
          educationalExplanation: 'MFA requires something you know AND something you have',
          codeLocation: 'backend-py/auth.py',
          cweReference: 'CWE-308',
        ),
        SecurityFeature(
          id: 'rate_limiting',
          name: 'Rate Limiting',
          description: 'Limits login attempts to prevent brute-force attacks',
          enabled: _localFeatureStates['rate_limiting'] ?? true,
          category: 'Rate Limiting',
          riskIfDisabled: 'Unlimited login attempts enable brute-force attacks',
          fdaRequirement: 'FDA Premarket Guidance 2023: Access Controls',
          educationalExplanation: 'Rate limiting slows down automated attacks',
          codeLocation: 'backend-py/main.py',
          cweReference: 'CWE-307',
        ),
        SecurityFeature(
          id: 'jwt_authentication',
          name: 'JWT Token Authentication',
          description: 'Secure token-based authentication with expiration',
          enabled: _localFeatureStates['jwt_authentication'] ?? true,
          category: 'Authorization',
          riskIfDisabled: 'Sessions could be hijacked or forged',
          fdaRequirement: 'FDA Premarket Guidance 2023: Session Management',
          educationalExplanation: 'JWT tokens carry signed claims that expire',
          codeLocation: 'backend-py/auth.py',
          cweReference: 'CWE-613',
        ),
        SecurityFeature(
          id: 'input_validation',
          name: 'Input Validation',
          description: 'Sanitizes and validates all user input',
          enabled: _localFeatureStates['input_validation'] ?? true,
          category: 'Input Validation',
          riskIfDisabled: 'SQL injection, XSS, and command injection vulnerabilities',
          fdaRequirement: 'FDA Premarket Guidance 2023: Input Validation',
          educationalExplanation: 'Never trust user input - always validate',
          codeLocation: 'backend-py/main.py',
          cweReference: 'CWE-20',
        ),
        SecurityFeature(
          id: 'replay_protection',
          name: 'Replay Protection',
          description: 'Prevents replay attacks using nonces and timestamps',
          enabled: _localFeatureStates['replay_protection'] ?? true,
          category: 'Replay Protection',
          riskIfDisabled: 'Attackers can replay captured requests',
          fdaRequirement: 'FDA Premarket Guidance 2023: Data Integrity',
          educationalExplanation: 'Each request must be unique and time-bound',
          codeLocation: 'backend-py/replay_protection.py',
          cweReference: 'CWE-294',
        ),
        SecurityFeature(
          id: 'audit_logging',
          name: 'Audit Logging',
          description: 'Comprehensive logging of security-relevant events',
          enabled: _localFeatureStates['audit_logging'] ?? true,
          category: 'Audit & Logging',
          riskIfDisabled: 'No trail for incident investigation',
          fdaRequirement: 'FDA Premarket Guidance 2023: Audit Trail',
          educationalExplanation: 'Complete audit trails enable forensic analysis',
          codeLocation: 'backend-py/audit_service.py',
          cweReference: 'CWE-778',
        ),
      ],
    );
  }

  /// Get the current security configuration
  Future<SecurityConfig?> getSecurityConfig() async {
    try {
      final response = await _networkService.get('/security/config');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        _offlineMode = false;
        final config = SecurityConfig.fromJson(data as Map<String, dynamic>);
        // Sync local state with backend
        for (var feature in config.features) {
          _localFeatureStates[feature.id] = feature.enabled;
        }
        _currentMode = config.mode;
        return config;
      }
      return _enableOfflineMode();
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting config: $e');
      return _enableOfflineMode();
    }
  }

  SecurityConfig _enableOfflineMode() {
    _offlineMode = true;
    debugPrint('SecurityEducationService: Backend unreachable, using LOCAL MODE');
    debugPrint('SecurityEducationService: All toggles will work locally for educational purposes');
    return getDefaultConfig();
  }

  /// Get live security status (for real-time dashboard updates)
  Future<Map<String, dynamic>?> getLiveStatus() async {
    try {
      final response = await _networkService.get('/security/live-status');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting live status: $e');
      return null;
    }
  }

  /// Switch security mode at RUNTIME (no restart needed!)
  /// 
  /// Modes:
  /// - 'secure': All features enabled, cannot be toggled
  /// - 'educational': All features enabled + verbose logging + can toggle
  /// - 'insecure': Features can be disabled for demos
  Future<Map<String, dynamic>?> setSecurityMode(String mode) async {
    // Always update local state first for responsiveness
    setModeLocally(mode);
    
    try {
      final response = await _networkService.post(
        '/security/mode?mode=$mode',
        data: {},
      );
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        logEducational('Mode Switch', 'Security mode changed to: $mode');
        return data as Map<String, dynamic>;
      }
      return _offlineModeResponse(mode);
    } catch (e) {
      debugPrint('SecurityEducationService: Error setting mode: $e');
      return _offlineModeResponse(mode);
    }
  }

  Map<String, dynamic> _offlineModeResponse(String mode) {
    logEducational('Mode Switch (LOCAL)', 'Security mode changed to: $mode (offline mode)');
    return {
      'success': true,
      'mode': mode,
      'message': 'Mode changed locally (backend unreachable)',
      'offline': true,
    };
  }

  /// Toggle educational logging at RUNTIME
  Future<Map<String, dynamic>?> setEducationalLogging(bool enabled) async {
    try {
      final response = await _networkService.post(
        '/security/logging?enabled=$enabled',
        data: {},
      );
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error setting logging: $e');
      return null;
    }
  }

  /// Get a specific security feature by ID
  Future<SecurityFeature?> getSecurityFeature(String featureId) async {
    try {
      final response = await _networkService.get('/security/features/$featureId');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return SecurityFeature.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting feature: $e');
      return null;
    }
  }

  /// Toggle a security feature (admin only, educational mode only)
  /// Works in offline mode by updating local state.
  Future<Map<String, dynamic>?> toggleSecurityFeature(String featureId, bool enabled) async {
    // Always update local state first for responsiveness
    toggleFeatureLocally(featureId, enabled);
    
    try {
      final response = await _networkService.post(
        '/security/features/$featureId/toggle?enabled=$enabled',
        data: {},
      );
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        logEducational('Feature Toggle', '$featureId set to ${enabled ? "ENABLED" : "DISABLED"}');
        return data as Map<String, dynamic>;
      }
      return _offlineToggleResponse(featureId, enabled);
    } catch (e) {
      debugPrint('SecurityEducationService: Error toggling feature: $e');
      return _offlineToggleResponse(featureId, enabled);
    }
  }

  Map<String, dynamic> _offlineToggleResponse(String featureId, bool enabled) {
    logEducational('Feature Toggle (LOCAL)', '$featureId set to ${enabled ? "ENABLED" : "DISABLED"} (offline mode)');
    return {
      'success': true,
      'featureId': featureId,
      'enabled': enabled,
      'message': 'Feature toggled locally (backend unreachable)',
      'offline': true,
    };
  }

  /// Get password hashing demonstration
  Future<PasswordHashingDemo?> demoPasswordHashing() async {
    try {
      final response = await _networkService.get('/security/demo/password-hashing');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return PasswordHashingDemo.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting password demo: $e');
      return null;
    }
  }

  /// Get JWT token demonstration
  Future<JwtTokenDemo?> demoJwtToken() async {
    try {
      final response = await _networkService.get('/security/demo/jwt-token');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return JwtTokenDemo.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting JWT demo: $e');
      return null;
    }
  }

  /// Get RBAC demonstration
  Future<RbacDemo?> demoRbac() async {
    try {
      final response = await _networkService.get('/security/demo/rbac');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return RbacDemo.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting RBAC demo: $e');
      return null;
    }
  }

  /// Get replay protection demonstration
  Future<ReplayProtectionDemo?> demoReplayProtection() async {
    try {
      final response = await _networkService.get('/security/demo/replay-protection');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return ReplayProtectionDemo.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting replay demo: $e');
      return null;
    }
  }

  /// Log security educational message to console
  static void logEducational(String feature, String message) {
    if (kDebugMode) {
      debugPrint('''
╔══════════════════════════════════════════════════════════════════════════════╗
║ 📚 SECURITY EDUCATION: $feature
╠══════════════════════════════════════════════════════════════════════════════╣
║ $message
╚══════════════════════════════════════════════════════════════════════════════╝
''');
    }
  }
}
