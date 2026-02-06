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
class SecurityEducationService {
  final NetworkService _networkService;
  
  SecurityEducationService({NetworkService? networkService})
      : _networkService = networkService ?? NetworkServiceImpl.secure();

  /// Get the current security configuration
  Future<SecurityConfig?> getSecurityConfig() async {
    try {
      final response = await _networkService.get('/security/config');
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data as String) 
            : response.data;
        return SecurityConfig.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('SecurityEducationService: Error getting config: $e');
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
  Future<Map<String, dynamic>?> toggleSecurityFeature(String featureId, bool enabled) async {
    try {
      final response = await _networkService.post(
        '/security/features/$featureId/toggle?enabled=$enabled',
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
      debugPrint('SecurityEducationService: Error toggling feature: $e');
      return null;
    }
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
