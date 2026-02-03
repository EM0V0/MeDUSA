import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/audit_service.dart';
import '../services/security_service.dart';

// Security event types (moved to top-level)
enum TLSSecurityEvent {
  tlsVersionDowngrade,
  certificateValidationFailure,
  weakCipherSuite,
  connectionTimeout,
  unauthorizedAccess,
  dataIntegrityFailure,
}

/// TLS monitoring and auditing service
/// Designed for medical device security compliance
class TLSMonitoringService {
  static const String _tag = 'TLSMonitoringService';
  
  final AuditService _auditService;
  final SecurityService _securityService;
  
  // TLS monitoring configuration
  static const List<String> _criticalEndpoints = [
    'api.medusa-medical.com',
    '*.execute-api.amazonaws.com',
    '*.s3.amazonaws.com',
  ];

  TLSMonitoringService({
    required AuditService auditService,
    required SecurityService securityService,
  })  : _auditService = auditService,
        _securityService = securityService;

  /// Monitor TLS connection quality
  Future<TLSConnectionReport> monitorTLSConnection(String endpoint) async {
    final startTime = DateTime.now();
    
    try {
      // Get TLS connection info - pass the endpoint URL
      final tlsInfo = await _securityService.getTLSConnectionInfo(endpoint);
      
      // Determine TLS version from protocol
      final protocol = tlsInfo.protocol ?? 'Unknown';
      final isTls13 = protocol.contains('1.3');
      
      // Check certificate validity
      final now = DateTime.now();
      final isValid = tlsInfo.certificateValidFrom != null && 
                      tlsInfo.certificateValidTo != null &&
                      now.isAfter(tlsInfo.certificateValidFrom!) &&
                      now.isBefore(tlsInfo.certificateValidTo!);
      
      // Create connection report
      final report = TLSConnectionReport(
        endpoint: endpoint,
        timestamp: startTime,
        tlsVersion: protocol,
        isTLS13: isTls13,
        certificateValid: isValid,
        connectionTime: DateTime.now().difference(startTime),
        securityScore: _calculateSecurityScoreFromInfo(tlsInfo),
        issues: _identifySecurityIssuesFromInfo(tlsInfo),
      );
      
      // Log audit event
      await _logTLSEvent(report);
      
      // Check security thresholds
      await _checkSecurityThresholds(report);
      
      return report;
    } catch (e) {
      final errorReport = TLSConnectionReport(
        endpoint: endpoint,
        timestamp: startTime,
        tlsVersion: 'Error',
        isTLS13: false,
        certificateValid: false,
        connectionTime: DateTime.now().difference(startTime),
        securityScore: 0,
        issues: ['Connection failed: $e'],
        error: e.toString(),
      );
      
      await _logTLSEvent(errorReport);
      return errorReport;
    }
  }

  /// Batch monitor critical endpoints
  Future<List<TLSConnectionReport>> monitorCriticalEndpoints() async {
    final reports = <TLSConnectionReport>[];
    
    for (final endpoint in _criticalEndpoints) {
      try {
        final report = await monitorTLSConnection(endpoint);
        reports.add(report);
        
        // Brief delay to avoid too frequent requests
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('$_tag: Failed to monitor $endpoint: $e');
      }
    }
    
    // Generate comprehensive security report
    await _generateSecuritySummary(reports);
    
    return reports;
  }

  /// Calculate security score from TLSConnectionInfo (0-100)
  int _calculateSecurityScoreFromInfo(TLSConnectionInfo tlsInfo) {
    int score = 0;
    
    // TLS version score (40 points)
    final protocol = tlsInfo.protocol?.toLowerCase() ?? '';
    if (protocol.contains('1.3')) {
      score += 40;
    } else if (protocol.contains('1.2')) {
      score += 30;
    } else if (protocol.contains('1.1')) {
      score += 10;
    }
    
    // Certificate validity (30 points)
    final now = DateTime.now();
    if (tlsInfo.certificateValidFrom != null && 
        tlsInfo.certificateValidTo != null &&
        now.isAfter(tlsInfo.certificateValidFrom!) &&
        now.isBefore(tlsInfo.certificateValidTo!)) {
      score += 30;
    }
    
    // Connection success (20 points) - if we got here, connection succeeded
    score += 20;
    
    // Certificate expiration check (10 points)
    if (tlsInfo.certificateValidTo != null) {
      final daysToExpiry = tlsInfo.certificateValidTo!.difference(now).inDays;
      if (daysToExpiry > 30) {
        score += 10;
      } else if (daysToExpiry > 7) {
        score += 5;
      }
    }
    
    return score.clamp(0, 100);
  }

  /// Identify security issues from TLSConnectionInfo
  List<String> _identifySecurityIssuesFromInfo(TLSConnectionInfo tlsInfo) {
    final issues = <String>[];
    
    // TLS version check
    final protocol = tlsInfo.protocol?.toLowerCase() ?? '';
    if (!protocol.contains('1.3') && !protocol.contains('1.2')) {
      issues.add('Insecure TLS version: ${tlsInfo.protocol ?? "Unknown"}');
    }
    
    if (!protocol.contains('1.3')) {
      issues.add('TLS 1.3 not used - medical devices require latest TLS');
    }
    
    // Certificate validity check
    final now = DateTime.now();
    if (tlsInfo.certificateValidFrom == null || tlsInfo.certificateValidTo == null) {
      issues.add('Certificate validity dates not available');
    } else if (now.isBefore(tlsInfo.certificateValidFrom!) || now.isAfter(tlsInfo.certificateValidTo!)) {
      issues.add('Invalid or expired certificate');
    }
    
    // Certificate expiration warning
    if (tlsInfo.certificateValidTo != null) {
      final daysToExpiry = tlsInfo.certificateValidTo!.difference(now).inDays;
      
      if (daysToExpiry <= 7) {
        issues.add('Certificate expires in $daysToExpiry days - immediate action required');
      } else if (daysToExpiry <= 30) {
        issues.add('Certificate expires in $daysToExpiry days - renewal needed');
      }
    }
    
    return issues;
  }

  /// Log TLS event to audit log
  Future<void> _logTLSEvent(TLSConnectionReport report) async {
    try {
      final auditData = {
        'endpoint': report.endpoint,
        'tls_version': report.tlsVersion,
        'is_tls_13': report.isTLS13,
        'certificate_valid': report.certificateValid,
        'security_score': report.securityScore,
        'connection_time_ms': report.connectionTime.inMilliseconds,
        'issues_count': report.issues.length,
        'issues': report.issues,
        if (report.error != null) 'error': report.error,
      };
      
      await _auditService.logEvent(
        'TLS_CONNECTION_MONITOR',
        description: jsonEncode(auditData),
        metadata: {
          'component': 'TLSMonitoringService',
          'medical_compliance': 'HIPAA',
          'security_level': report.securityScore >= 80 ? 'HIGH' : 
                           report.securityScore >= 60 ? 'MEDIUM' : 'LOW',
        },
      );
      
      if (kDebugMode) {
        debugPrint('$_tag: TLS monitoring logged for ${report.endpoint}');
      }
    } catch (e) {
      debugPrint('$_tag: Failed to log TLS event: $e');
    }
  }

  /// Check security thresholds and trigger alerts
  Future<void> _checkSecurityThresholds(TLSConnectionReport report) async {
    // Critical security issues (immediate alert)
    if (report.securityScore < 50) {
      await _triggerSecurityAlert(TLSSecurityEvent.tlsVersionDowngrade, report);
    }
    
    if (!report.certificateValid) {
      await _triggerSecurityAlert(TLSSecurityEvent.certificateValidationFailure, report);
    }
    
    if (!report.isTLS13) {
      await _triggerSecurityAlert(TLSSecurityEvent.weakCipherSuite, report);
    }
    
    // Connection performance issues
    if (report.connectionTime.inSeconds > 30) {
      await _triggerSecurityAlert(TLSSecurityEvent.connectionTimeout, report);
    }
    
    // Data integrity check
    if (report.issues.isNotEmpty) {
      await _triggerSecurityAlert(TLSSecurityEvent.dataIntegrityFailure, report);
    }
  }

  /// Trigger security alert
  Future<void> _triggerSecurityAlert(TLSSecurityEvent eventType, TLSConnectionReport report) async {
    try {
      final alertData = {
        'event_type': eventType.toString(),
        'endpoint': report.endpoint,
        'security_score': report.securityScore,
        'issues': report.issues,
        'timestamp': report.timestamp.toIso8601String(),
        'severity': _getEventSeverity(eventType),
      };
      
      await _auditService.logEvent(
        'TLS_SECURITY_ALERT',
        description: jsonEncode(alertData),
        metadata: {
          'alert_type': eventType.toString(),
          'severity': _getEventSeverity(eventType),
          'requires_immediate_action': _requiresImmediateAction(eventType).toString(),
        },
      );
      
      if (kDebugMode) {
        debugPrint('$_tag: SECURITY ALERT - ${eventType.toString()} for ${report.endpoint}');
      }
      
      // In production, this should send to monitoring systems
      // e.g., AWS CloudWatch Alarms, PagerDuty, Slack, etc.
      
    } catch (e) {
      debugPrint('$_tag: Failed to trigger security alert: $e');
    }
  }

  /// Get event severity level
  String _getEventSeverity(TLSSecurityEvent eventType) {
    switch (eventType) {
      case TLSSecurityEvent.tlsVersionDowngrade:
      case TLSSecurityEvent.certificateValidationFailure:
        return 'CRITICAL';
      case TLSSecurityEvent.weakCipherSuite:
      case TLSSecurityEvent.unauthorizedAccess:
        return 'HIGH';
      case TLSSecurityEvent.connectionTimeout:
      case TLSSecurityEvent.dataIntegrityFailure:
        return 'MEDIUM';
    }
  }

  /// Determine if immediate action is required
  bool _requiresImmediateAction(TLSSecurityEvent eventType) {
    return [
      TLSSecurityEvent.tlsVersionDowngrade,
      TLSSecurityEvent.certificateValidationFailure,
      TLSSecurityEvent.unauthorizedAccess,
    ].contains(eventType);
  }

  /// Generate security summary report
  Future<void> _generateSecuritySummary(List<TLSConnectionReport> reports) async {
    final summary = {
      'total_endpoints': reports.length,
      'tls_13_compliant': reports.where((r) => r.isTLS13).length,
      'certificate_valid': reports.where((r) => r.certificateValid).length,
      'average_security_score': reports.isEmpty ? 0 : 
        reports.map((r) => r.securityScore).reduce((a, b) => a + b) ~/ reports.length,
      'critical_issues': reports.where((r) => r.securityScore < 50).length,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _auditService.logEvent(
      'TLS_SECURITY_SUMMARY',
      description: jsonEncode(summary),
      metadata: {
        'report_type': 'daily_tls_summary',
        'compliance_status': summary['tls_13_compliant'] == summary['total_endpoints'] ? 'COMPLIANT' : 'NON_COMPLIANT',
      },
    );
  }

  /// Get TLS compliance status
  Future<TLSComplianceStatus> getComplianceStatus() async {
    final reports = await monitorCriticalEndpoints();
    
    final totalEndpoints = reports.length;
    final tls13Compliant = reports.where((r) => r.isTLS13).length;
    final certificateValid = reports.where((r) => r.certificateValid).length;
    final criticalIssues = reports.where((r) => r.securityScore < 50).length;
    
    final compliancePercentage = totalEndpoints == 0 ? 0 : 
      (tls13Compliant * 100 / totalEndpoints).round();
    
    return TLSComplianceStatus(
      isFullyCompliant: tls13Compliant == totalEndpoints && certificateValid == totalEndpoints,
      compliancePercentage: compliancePercentage,
      totalEndpoints: totalEndpoints,
      tls13CompliantEndpoints: tls13Compliant,
      validCertificates: certificateValid,
      criticalIssues: criticalIssues,
      lastChecked: DateTime.now(),
      reports: reports,
    );
  }
}

/// TLS connection report
class TLSConnectionReport {
  final String endpoint;
  final DateTime timestamp;
  final String tlsVersion;
  final bool isTLS13;
  final bool certificateValid;
  final Duration connectionTime;
  final int securityScore;
  final List<String> issues;
  final String? error;

  TLSConnectionReport({
    required this.endpoint,
    required this.timestamp,
    required this.tlsVersion,
    required this.isTLS13,
    required this.certificateValid,
    required this.connectionTime,
    required this.securityScore,
    required this.issues,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'timestamp': timestamp.toIso8601String(),
      'tls_version': tlsVersion,
      'is_tls_13': isTLS13,
      'certificate_valid': certificateValid,
      'connection_time_ms': connectionTime.inMilliseconds,
      'security_score': securityScore,
      'issues': issues,
      if (error != null) 'error': error,
    };
  }
}

/// TLS compliance status
class TLSComplianceStatus {
  final bool isFullyCompliant;
  final int compliancePercentage;
  final int totalEndpoints;
  final int tls13CompliantEndpoints;
  final int validCertificates;
  final int criticalIssues;
  final DateTime lastChecked;
  final List<TLSConnectionReport> reports;

  TLSComplianceStatus({
    required this.isFullyCompliant,
    required this.compliancePercentage,
    required this.totalEndpoints,
    required this.tls13CompliantEndpoints,
    required this.validCertificates,
    required this.criticalIssues,
    required this.lastChecked,
    required this.reports,
  });

  Map<String, dynamic> toJson() {
    return {
      'is_fully_compliant': isFullyCompliant,
      'compliance_percentage': compliancePercentage,
      'total_endpoints': totalEndpoints,
      'tls_13_compliant_endpoints': tls13CompliantEndpoints,
      'valid_certificates': validCertificates,
      'critical_issues': criticalIssues,
      'last_checked': lastChecked.toIso8601String(),
      'summary': {
        'status': isFullyCompliant ? 'COMPLIANT' : 'NON_COMPLIANT',
        'medical_grade': isFullyCompliant && criticalIssues == 0,
        'fda_ready': compliancePercentage >= 100 && criticalIssues == 0,
        'hipaa_compliant': validCertificates == totalEndpoints,
      },
    };
  }
}