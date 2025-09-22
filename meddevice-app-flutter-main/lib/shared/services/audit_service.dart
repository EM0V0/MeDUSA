import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Audit log service for tracking system activities and user actions
/// Provides comprehensive logging for compliance and security monitoring
class AuditService extends ChangeNotifier {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final List<AuditLog> _auditLogs = [];
  final StreamController<List<AuditLog>> _logsController = StreamController<List<AuditLog>>.broadcast();

  // Getters
  List<AuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  Stream<List<AuditLog>> get logsStream => _logsController.stream;

  /// Initialize audit service with sample data
  void initialize() {
    _generateSampleLogs();
    notifyListeners();
  }

  /// Log a general event (for TLS monitoring service)
  Future<void> logEvent(String event, {
    String? description,
    Map<String, dynamic>? metadata,
    String severity = 'info',
  }) async {
    final log = AuditLog(
      id: 'event_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: 'system',
      userName: 'System',
      action: event,
      resource: 'system',
      category: AuditCategory.system,
      severity: severity == 'critical' ? AuditSeverity.critical 
                : severity == 'warning' ? AuditSeverity.warning 
                : AuditSeverity.info,
      details: description ?? event,
      metadata: metadata,
      ipAddress: '127.0.0.1',
      userAgent: 'MeDUSA Security Monitor',
    );
    
    _addLog(log);
  }

  /// Log a user action
  void logUserAction({
    required String userId,
    required String userName,
    required String action,
    required String resource,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    final log = AuditLog(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: userId,
      userName: userName,
      action: action,
      resource: resource,
      category: AuditCategory.userAction,
      severity: AuditSeverity.info,
      details: details,
      metadata: metadata,
      ipAddress: '192.168.1.100', // In real app, get actual IP
      userAgent: 'Flutter App',
    );
    
    _addLog(log);
  }

  /// Log a system event
  void logSystemEvent({
    required String event,
    required String description,
    AuditSeverity severity = AuditSeverity.info,
    Map<String, dynamic>? metadata,
  }) {
    final log = AuditLog(
      id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: 'system',
      userName: 'System',
      action: event,
      resource: 'system',
      category: AuditCategory.systemEvent,
      severity: severity,
      details: description,
      metadata: metadata,
      ipAddress: 'localhost',
      userAgent: 'System',
    );
    
    _addLog(log);
  }

  /// Log a security event
  void logSecurityEvent({
    required String userId,
    required String userName,
    required String event,
    required String description,
    AuditSeverity severity = AuditSeverity.warning,
    String? ipAddress,
    Map<String, dynamic>? metadata,
  }) {
    final log = AuditLog(
      id: 'sec_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: userId,
      userName: userName,
      action: event,
      resource: 'security',
      category: AuditCategory.security,
      severity: severity,
      details: description,
      metadata: metadata,
      ipAddress: ipAddress ?? '192.168.1.100',
      userAgent: 'Flutter App',
    );
    
    _addLog(log);
  }

  /// Log data access
  void logDataAccess({
    required String userId,
    required String userName,
    required String dataType,
    required String action, // view, create, update, delete
    String? recordId,
    Map<String, dynamic>? metadata,
  }) {
    final log = AuditLog(
      id: 'data_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: userId,
      userName: userName,
      action: action,
      resource: dataType,
      category: AuditCategory.dataAccess,
      severity: AuditSeverity.info,
      details: recordId != null ? 'Record ID: $recordId' : null,
      metadata: metadata,
      ipAddress: '192.168.1.100',
      userAgent: 'Flutter App',
    );
    
    _addLog(log);
  }

  /// Add log entry
  void _addLog(AuditLog log) {
    _auditLogs.insert(0, log); // Add to beginning for newest first
    
    // Keep only last 1000 logs in memory
    if (_auditLogs.length > 1000) {
      _auditLogs.removeRange(1000, _auditLogs.length);
    }
    
    _logsController.add(_auditLogs);
    notifyListeners();
    
    // In real app, also save to database
    debugPrint('Audit Log: ${log.action} by ${log.userName} on ${log.resource}');
  }

  /// Get logs by category
  List<AuditLog> getLogsByCategory(AuditCategory category) {
    return _auditLogs.where((log) => log.category == category).toList();
  }

  /// Get logs by severity
  List<AuditLog> getLogsBySeverity(AuditSeverity severity) {
    return _auditLogs.where((log) => log.severity == severity).toList();
  }

  /// Get logs by user
  List<AuditLog> getLogsByUser(String userId) {
    return _auditLogs.where((log) => log.userId == userId).toList();
  }

  /// Get logs in date range
  List<AuditLog> getLogsInDateRange(DateTime start, DateTime end) {
    return _auditLogs.where((log) => 
        log.timestamp.isAfter(start) && log.timestamp.isBefore(end)).toList();
  }

  /// Search logs
  List<AuditLog> searchLogs(String query) {
    final lowerQuery = query.toLowerCase();
    return _auditLogs.where((log) => 
        log.action.toLowerCase().contains(lowerQuery) ||
        log.resource.toLowerCase().contains(lowerQuery) ||
        log.userName.toLowerCase().contains(lowerQuery) ||
        (log.details?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  /// Get audit statistics
  Map<String, dynamic> getAuditStatistics() {
    final total = _auditLogs.length;
    final categoryCounts = <AuditCategory, int>{};
    final severityCounts = <AuditSeverity, int>{};
    final userCounts = <String, int>{};
    
    for (final log in _auditLogs) {
      categoryCounts[log.category] = (categoryCounts[log.category] ?? 0) + 1;
      severityCounts[log.severity] = (severityCounts[log.severity] ?? 0) + 1;
      userCounts[log.userName] = (userCounts[log.userName] ?? 0) + 1;
    }
    
    return {
      'totalLogs': total,
      'categoryCounts': categoryCounts,
      'severityCounts': severityCounts,
      'userCounts': userCounts,
      'oldestLog': _auditLogs.isNotEmpty ? _auditLogs.last.timestamp : null,
      'newestLog': _auditLogs.isNotEmpty ? _auditLogs.first.timestamp : null,
    };
  }

  /// Export logs as JSON
  String exportLogsAsJson({
    DateTime? startDate,
    DateTime? endDate,
    AuditCategory? category,
    AuditSeverity? severity,
  }) {
    var logsToExport = _auditLogs;
    
    if (startDate != null && endDate != null) {
      logsToExport = getLogsInDateRange(startDate, endDate);
    }
    
    if (category != null) {
      logsToExport = logsToExport.where((log) => log.category == category).toList();
    }
    
    if (severity != null) {
      logsToExport = logsToExport.where((log) => log.severity == severity).toList();
    }
    
    final jsonData = logsToExport.map((log) => log.toJson()).toList();
    return jsonEncode(jsonData);
  }

  /// Generate sample audit logs for demonstration
  void _generateSampleLogs() {
    final now = DateTime.now();
    
    // User login/logout events
    _addLog(AuditLog(
      id: 'audit_001',
      timestamp: now.subtract(const Duration(minutes: 5)),
      userId: 'user_001',
      userName: 'Dr. Sarah Johnson',
      action: 'login',
      resource: 'authentication',
      category: AuditCategory.security,
      severity: AuditSeverity.info,
      details: 'Successful login',
      ipAddress: '192.168.1.101',
      userAgent: 'Flutter App v1.0',
    ));

    _addLog(AuditLog(
      id: 'audit_002',
      timestamp: now.subtract(const Duration(minutes: 10)),
      userId: 'user_002',
      userName: 'John Smith',
      action: 'view',
      resource: 'patient_data',
      category: AuditCategory.dataAccess,
      severity: AuditSeverity.info,
      details: 'Viewed patient medical records',
      metadata: {'patientId': 'P001', 'recordType': 'medical_history'},
      ipAddress: '192.168.1.102',
      userAgent: 'Flutter App v1.0',
    ));

    _addLog(AuditLog(
      id: 'audit_003',
      timestamp: now.subtract(const Duration(minutes: 15)),
      userId: 'system',
      userName: 'System',
      action: 'backup_completed',
      resource: 'system',
      category: AuditCategory.systemEvent,
      severity: AuditSeverity.info,
      details: 'Daily system backup completed successfully',
      metadata: {'backupSize': '2.1GB', 'duration': '45 minutes'},
      ipAddress: 'localhost',
      userAgent: 'System',
    ));

    _addLog(AuditLog(
      id: 'audit_004',
      timestamp: now.subtract(const Duration(minutes: 20)),
      userId: 'user_003',
      userName: 'Unknown User',
      action: 'failed_login',
      resource: 'authentication',
      category: AuditCategory.security,
      severity: AuditSeverity.warning,
      details: 'Failed login attempt with invalid credentials',
      metadata: {'attemptCount': 3, 'email': 'invalid@email.com'},
      ipAddress: '192.168.1.999',
      userAgent: 'Unknown',
    ));

    _addLog(AuditLog(
      id: 'audit_005',
      timestamp: now.subtract(const Duration(minutes: 25)),
      userId: 'admin_001',
      userName: 'Admin User',
      action: 'create',
      resource: 'user_account',
      category: AuditCategory.userAction,
      severity: AuditSeverity.info,
      details: 'Created new user account',
      metadata: {'newUserId': 'user_004', 'role': 'doctor'},
      ipAddress: '192.168.1.103',
      userAgent: 'Flutter App v1.0',
    ));

    _addLog(AuditLog(
      id: 'audit_006',
      timestamp: now.subtract(const Duration(hours: 1)),
      userId: 'user_001',
      userName: 'Dr. Sarah Johnson',
      action: 'update',
      resource: 'patient_data',
      category: AuditCategory.dataAccess,
      severity: AuditSeverity.info,
      details: 'Updated patient treatment plan',
      metadata: {'patientId': 'P002', 'changes': ['medication', 'dosage']},
      ipAddress: '192.168.1.101',
      userAgent: 'Flutter App v1.0',
    ));

    _addLog(AuditLog(
      id: 'audit_007',
      timestamp: now.subtract(const Duration(hours: 2)),
      userId: 'system',
      userName: 'System',
      action: 'alert_triggered',
      resource: 'monitoring',
      category: AuditCategory.systemEvent,
      severity: AuditSeverity.error,
      details: 'Critical system alert: High CPU usage detected',
      metadata: {'cpuUsage': '95%', 'duration': '10 minutes'},
      ipAddress: 'localhost',
      userAgent: 'System Monitor',
    ));

    _addLog(AuditLog(
      id: 'audit_008',
      timestamp: now.subtract(const Duration(hours: 3)),
      userId: 'user_002',
      userName: 'John Smith',
      action: 'delete',
      resource: 'message',
      category: AuditCategory.dataAccess,
      severity: AuditSeverity.warning,
      details: 'Deleted message from conversation',
      metadata: {'messageId': 'msg_123', 'conversationId': 'conv_456'},
      ipAddress: '192.168.1.102',
      userAgent: 'Flutter App v1.0',
    ));
  }

  /// Dispose service
  @override
  void dispose() {
    _logsController.close();
    super.dispose();
  }
}

/// Audit log entry model
class AuditLog {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String action;
  final String resource;
  final AuditCategory category;
  final AuditSeverity severity;
  final String? details;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;
  final String? userAgent;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.action,
    required this.resource,
    required this.category,
    required this.severity,
    this.details,
    this.metadata,
    this.ipAddress,
    this.userAgent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'action': action,
      'resource': resource,
      'category': category.name,
      'severity': severity.name,
      'details': details,
      'metadata': metadata,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'],
      userName: json['userName'],
      action: json['action'],
      resource: json['resource'],
      category: AuditCategory.values.firstWhere((e) => e.name == json['category']),
      severity: AuditSeverity.values.firstWhere((e) => e.name == json['severity']),
      details: json['details'],
      metadata: json['metadata'],
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
    );
  }
}

/// Audit log categories
enum AuditCategory {
  userAction,
  dataAccess,
  security,
  system,
  systemEvent,
  authentication,
  configuration,
}

/// Audit log severity levels
enum AuditSeverity {
  info,
  warning,
  error,
  critical,
}

extension AuditCategoryExtension on AuditCategory {
  String get displayName {
    switch (this) {
      case AuditCategory.userAction:
        return 'User Action';
      case AuditCategory.dataAccess:
        return 'Data Access';
      case AuditCategory.security:
        return 'Security';
      case AuditCategory.system:
        return 'System';
      case AuditCategory.systemEvent:
        return 'System Event';
      case AuditCategory.authentication:
        return 'Authentication';
      case AuditCategory.configuration:
        return 'Configuration';
    }
  }
}

extension AuditSeverityExtension on AuditSeverity {
  String get displayName {
    switch (this) {
      case AuditSeverity.info:
        return 'Info';
      case AuditSeverity.warning:
        return 'Warning';
      case AuditSeverity.error:
        return 'Error';
      case AuditSeverity.critical:
        return 'Critical';
    }
  }
}

/// Implementation of AuditService for dependency injection
class AuditServiceImpl extends AuditService {
  // Use singleton pattern - delegate to parent singleton
  AuditServiceImpl() : super._internal();
}
