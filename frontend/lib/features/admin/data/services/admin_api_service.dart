import 'package:flutter/foundation.dart';
import '../../../../shared/services/network_service.dart';

/// Service for admin-related API calls
class AdminApiService {
  final NetworkService _networkService;
  
  AdminApiService({NetworkService? networkService}) 
      : _networkService = networkService ?? NetworkServiceImpl.secure();
  
  // ============== Audit Logs ==============
  
  /// Fetch audit logs from the backend
  Future<AuditLogsResponse> getAuditLogs({
    String? eventType,
    String? userId,
    String? severity,
    String? startTime,
    String? endTime,
    int limit = 100,
    String? nextToken,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (eventType != null && eventType != 'all') {
        queryParams['eventType'] = eventType;
      }
      if (userId != null) queryParams['userId'] = userId;
      if (severity != null && severity != 'all') {
        queryParams['severity'] = severity;
      }
      if (startTime != null) queryParams['startTime'] = startTime;
      if (endTime != null) queryParams['endTime'] = endTime;
      queryParams['limit'] = limit.toString();
      if (nextToken != null) queryParams['nextToken'] = nextToken;
      
      final response = await _networkService.get(
        '/admin/audit-logs',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?)
            ?.map((item) => AuditLogItem.fromJson(item as Map<String, dynamic>))
            .toList() ?? [];
        
        return AuditLogsResponse(
          success: true,
          items: items,
          count: data['count'] as int? ?? items.length,
          nextToken: data['nextToken'] as String?,
        );
      }
      
      return AuditLogsResponse(
        success: false,
        items: [],
        error: 'Failed to fetch audit logs',
      );
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return AuditLogsResponse(
        success: false,
        items: [],
        error: e.toString(),
      );
    }
  }
  
  // ============== Dashboard Stats ==============
  
  /// Fetch dashboard statistics
  Future<DashboardStats?> getDashboardStats() async {
    try {
      final response = await _networkService.get('/admin/dashboard/stats');
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return DashboardStats.fromJson(data['data'] as Map<String, dynamic>? ?? data);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      return null;
    }
  }
  
  // ============== System Settings ==============
  
  /// Fetch system settings
  Future<SystemSettings?> getSystemSettings() async {
    try {
      final response = await _networkService.get('/admin/settings');
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return SystemSettings.fromJson(data['data'] as Map<String, dynamic>? ?? data);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
      return null;
    }
  }
  
  /// Update system settings
  Future<bool> updateSystemSettings({
    bool? requireMfa,
    int? sessionTimeout,
    bool? passwordComplexity,
    bool? emailNotifications,
    bool? criticalAlerts,
    bool? dataRetention,
    int? dataRetentionDays,
    bool? autoBackup,
    bool? maintenanceMode,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (requireMfa != null) data['requireMfa'] = requireMfa;
      if (sessionTimeout != null) data['sessionTimeout'] = sessionTimeout;
      if (passwordComplexity != null) data['passwordComplexity'] = passwordComplexity;
      if (emailNotifications != null) data['emailNotifications'] = emailNotifications;
      if (criticalAlerts != null) data['criticalAlerts'] = criticalAlerts;
      if (dataRetention != null) data['dataRetention'] = dataRetention;
      if (dataRetentionDays != null) data['dataRetentionDays'] = dataRetentionDays;
      if (autoBackup != null) data['autoBackup'] = autoBackup;
      if (maintenanceMode != null) data['maintenanceMode'] = maintenanceMode;
      
      final response = await _networkService.put(
        '/admin/settings',
        data: data,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating system settings: $e');
      return false;
    }
  }
  
  // ============== User Management ==============
  
  /// Fetch all users
  Future<UsersResponse> getUsers({
    String? role,
    int limit = 50,
    String? nextToken,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (role != null && role != 'all') queryParams['role'] = role;
      queryParams['limit'] = limit.toString();
      if (nextToken != null) queryParams['nextToken'] = nextToken;
      
      final response = await _networkService.get(
        '/admin/users',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?)
            ?.map((item) => UserItem.fromJson(item as Map<String, dynamic>))
            .toList() ?? [];
        
        return UsersResponse(
          success: true,
          users: items,
          nextToken: data['nextToken'] as String?,
        );
      }
      
      return UsersResponse(
        success: false,
        users: [],
        error: 'Failed to fetch users',
      );
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return UsersResponse(
        success: false,
        users: [],
        error: e.toString(),
      );
    }
  }
  
  /// Update a user
  Future<bool> updateUser(String userId, {String? name, String? role}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (role != null) data['role'] = role;
      
      final response = await _networkService.put(
        '/admin/users/$userId',
        data: data,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user: $e');
      return false;
    }
  }
  
  /// Delete/deactivate a user
  Future<bool> deleteUser(String userId) async {
    try {
      final response = await _networkService.delete('/admin/users/$userId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }
  
  // ============== Profile ==============
  
  /// Fetch current user profile
  Future<UserProfile?> getProfile() async {
    try {
      final response = await _networkService.get('/profile');
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return UserProfile.fromJson(data['data'] as Map<String, dynamic>? ?? data);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }
  
  /// Update current user profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? specialty,
    String? licenseNumber,
    String? department,
    String? hospital,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (specialty != null) data['specialty'] = specialty;
      if (licenseNumber != null) data['licenseNumber'] = licenseNumber;
      if (department != null) data['department'] = department;
      if (hospital != null) data['hospital'] = hospital;
      
      final response = await _networkService.put(
        '/profile',
        data: data,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
  
  // ============== User Settings ==============
  
  /// Fetch current user settings (notifications, security, etc.)
  Future<UserSettings?> getUserSettings() async {
    try {
      final response = await _networkService.get('/settings/user');
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return UserSettings.fromJson(data['data'] as Map<String, dynamic>? ?? data);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching user settings: $e');
      return null;
    }
  }
  
  /// Update current user settings
  Future<bool> updateUserSettings({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    bool? criticalAlerts,
    bool? dailyReports,
    bool? weeklyReports,
    bool? twoFactorAuth,
    bool? biometricAuth,
    bool? autoLogout,
    String? sessionTimeout,
    double? alertThreshold,
    int? dataRetentionDays,
    bool? debugMode,
    String? backupFrequency,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (emailNotifications != null) data['emailNotifications'] = emailNotifications;
      if (pushNotifications != null) data['pushNotifications'] = pushNotifications;
      if (smsNotifications != null) data['smsNotifications'] = smsNotifications;
      if (criticalAlerts != null) data['criticalAlerts'] = criticalAlerts;
      if (dailyReports != null) data['dailyReports'] = dailyReports;
      if (weeklyReports != null) data['weeklyReports'] = weeklyReports;
      if (twoFactorAuth != null) data['twoFactorAuth'] = twoFactorAuth;
      if (biometricAuth != null) data['biometricAuth'] = biometricAuth;
      if (autoLogout != null) data['autoLogout'] = autoLogout;
      if (sessionTimeout != null) data['sessionTimeout'] = sessionTimeout;
      if (alertThreshold != null) data['alertThreshold'] = alertThreshold;
      if (dataRetentionDays != null) data['dataRetentionDays'] = dataRetentionDays;
      if (debugMode != null) data['debugMode'] = debugMode;
      if (backupFrequency != null) data['backupFrequency'] = backupFrequency;
      
      final response = await _networkService.put(
        '/settings/user',
        data: data,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user settings: $e');
      return false;
    }
  }
}

// ============== Response Models ==============

class AuditLogsResponse {
  final bool success;
  final List<AuditLogItem> items;
  final int count;
  final String? nextToken;
  final String? error;
  
  AuditLogsResponse({
    required this.success,
    required this.items,
    this.count = 0,
    this.nextToken,
    this.error,
  });
}

class AuditLogItem {
  final String logId;
  final String eventType;
  final String severity;
  final String? userId;
  final String? userRole;
  final String? action;
  final String? ipAddress;
  final String timestamp;
  final String? resourceType;
  final String? resourceId;
  final Map<String, dynamic>? details;
  
  AuditLogItem({
    required this.logId,
    required this.eventType,
    required this.severity,
    this.userId,
    this.userRole,
    this.action,
    this.ipAddress,
    required this.timestamp,
    this.resourceType,
    this.resourceId,
    this.details,
  });
  
  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      logId: json['logId'] as String? ?? json['id'] as String? ?? '',
      eventType: json['eventType'] as String? ?? json['event_type'] as String? ?? 'UNKNOWN',
      severity: json['severity'] as String? ?? 'INFO',
      userId: json['userId'] as String?,
      userRole: json['userRole'] as String?,
      action: json['action'] as String?,
      ipAddress: json['ipAddress'] as String?,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      resourceType: json['resourceType'] as String?,
      resourceId: json['resourceId'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
  
  DateTime get timestampDateTime {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return DateTime.now();
    }
  }
}

class DashboardStats {
  final int totalUsers;
  final int doctorCount;
  final int patientCount;
  final int totalDevices;
  final int activeDevices;
  final int activeSessions;
  final int totalSessions;
  final int totalReports;
  final String systemUptime;
  final String dataStorage;
  
  DashboardStats({
    this.totalUsers = 0,
    this.doctorCount = 0,
    this.patientCount = 0,
    this.totalDevices = 0,
    this.activeDevices = 0,
    this.activeSessions = 0,
    this.totalSessions = 0,
    this.totalReports = 0,
    this.systemUptime = '99.9%',
    this.dataStorage = '0 GB',
  });
  
  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['totalUsers'] as int? ?? 0,
      doctorCount: json['doctorCount'] as int? ?? json['totalDoctors'] as int? ?? 0,
      patientCount: json['patientCount'] as int? ?? json['totalPatients'] as int? ?? 0,
      totalDevices: json['totalDevices'] as int? ?? 0,
      activeDevices: json['activeDevices'] as int? ?? 0,
      activeSessions: json['activeSessions'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
      totalReports: json['totalReports'] as int? ?? 0,
      systemUptime: json['systemUptime'] as String? ?? '99.9%',
      dataStorage: json['dataStorage'] as String? ?? '0 GB',
    );
  }
}

class SystemSettings {
  final bool requireMfa;
  final bool emailNotifications;
  final bool criticalAlerts;
  final bool dataRetention;
  final bool autoBackup;
  final bool maintenanceMode;
  final bool passwordComplexity;
  final int sessionTimeout;
  final int dataRetentionDays;
  
  SystemSettings({
    this.requireMfa = true,
    this.emailNotifications = true,
    this.criticalAlerts = true,
    this.dataRetention = true,
    this.autoBackup = true,
    this.maintenanceMode = false,
    this.passwordComplexity = true,
    this.sessionTimeout = 30,
    this.dataRetentionDays = 365,
  });
  
  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      requireMfa: json['requireMfa'] as bool? ?? true,
      emailNotifications: json['emailNotifications'] as bool? ?? true,
      criticalAlerts: json['criticalAlerts'] as bool? ?? true,
      dataRetention: json['dataRetention'] as bool? ?? true,
      autoBackup: json['autoBackup'] as bool? ?? true,
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      passwordComplexity: json['passwordComplexity'] as bool? ?? true,
      sessionTimeout: json['sessionTimeout'] as int? ?? 30,
      dataRetentionDays: json['dataRetentionDays'] as int? ?? 365,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'requireMfa': requireMfa,
      'emailNotifications': emailNotifications,
      'criticalAlerts': criticalAlerts,
      'dataRetention': dataRetention,
      'autoBackup': autoBackup,
      'maintenanceMode': maintenanceMode,
      'passwordComplexity': passwordComplexity,
      'sessionTimeout': sessionTimeout,
      'dataRetentionDays': dataRetentionDays,
    };
  }
}

class UsersResponse {
  final bool success;
  final List<UserItem> users;
  final String? nextToken;
  final String? error;
  
  UsersResponse({
    required this.success,
    required this.users,
    this.nextToken,
    this.error,
  });
}

class UserItem {
  final String id;
  final String email;
  final String role;
  final String name;
  final bool emailVerified;
  final bool mfaEnabled;
  final DateTime createdAt;
  final bool isActive;
  
  UserItem({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.emailVerified = false,
    this.mfaEnabled = false,
    required this.createdAt,
    this.isActive = true,
  });
  
  factory UserItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt'] as String? ?? '');
    } catch (e) {
      parsedDate = DateTime.now();
    }
    
    return UserItem(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      name: json['name'] as String? ?? json['email'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
      mfaEnabled: json['mfaEnabled'] as bool? ?? false,
      createdAt: parsedDate,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? specialty;
  final String? licenseNumber;
  final String? department;
  final String? hospital;
  
  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.specialty,
    this.licenseNumber,
    this.department,
    this.hospital,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      phone: json['phone'] as String?,
      specialty: json['specialty'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      department: json['department'] as String?,
      hospital: json['hospital'] as String?,
    );
  }
}

class UserSettings {
  final bool emailNotifications;
  final bool pushNotifications;
  final bool smsNotifications;
  final bool criticalAlerts;
  final bool dailyReports;
  final bool weeklyReports;
  final bool twoFactorAuth;
  final bool biometricAuth;
  final bool autoLogout;
  final String sessionTimeout;
  final double alertThreshold;
  final int dataRetentionDays;
  final bool debugMode;
  final String backupFrequency;
  
  UserSettings({
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.smsNotifications = false,
    this.criticalAlerts = true,
    this.dailyReports = true,
    this.weeklyReports = false,
    this.twoFactorAuth = false,
    this.biometricAuth = true,
    this.autoLogout = true,
    this.sessionTimeout = '30 minutes',
    this.alertThreshold = 7.5,
    this.dataRetentionDays = 365,
    this.debugMode = false,
    this.backupFrequency = 'Daily',
  });
  
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      emailNotifications: json['emailNotifications'] as bool? ?? true,
      pushNotifications: json['pushNotifications'] as bool? ?? true,
      smsNotifications: json['smsNotifications'] as bool? ?? false,
      criticalAlerts: json['criticalAlerts'] as bool? ?? true,
      dailyReports: json['dailyReports'] as bool? ?? true,
      weeklyReports: json['weeklyReports'] as bool? ?? false,
      twoFactorAuth: json['twoFactorAuth'] as bool? ?? false,
      biometricAuth: json['biometricAuth'] as bool? ?? true,
      autoLogout: json['autoLogout'] as bool? ?? true,
      sessionTimeout: json['sessionTimeout'] as String? ?? '30 minutes',
      alertThreshold: (json['alertThreshold'] as num?)?.toDouble() ?? 7.5,
      dataRetentionDays: json['dataRetentionDays'] as int? ?? 365,
      debugMode: json['debugMode'] as bool? ?? false,
      backupFrequency: json['backupFrequency'] as String? ?? 'Daily',
    );
  }
}
