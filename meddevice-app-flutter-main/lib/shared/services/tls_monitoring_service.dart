import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/audit_service.dart';
import '../services/security_service.dart';

// 安全事件类型（移到顶级）
enum TLSSecurityEvent {
  tlsVersionDowngrade,
  certificateValidationFailure,
  weakCipherSuite,
  connectionTimeout,
  unauthorizedAccess,
  dataIntegrityFailure,
}

/// TLS监控和审计服务
/// 专为医疗设备安全合规设计
class TLSMonitoringService {
  static const String _tag = 'TLSMonitoringService';
  
  final AuditService _auditService;
  final SecurityService _securityService;
  
  // TLS监控配置
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

  /// 监控TLS连接质量
  Future<TLSConnectionReport> monitorTLSConnection(String endpoint) async {
    final startTime = DateTime.now();
    
    try {
      final uri = Uri.parse(endpoint.startsWith('http') ? endpoint : 'https://$endpoint');
      
      // 获取TLS连接信息
      final tlsInfo = await _securityService.getTLSConnectionInfo();
      
      // 创建连接报告
      final report = TLSConnectionReport(
        endpoint: endpoint,
        timestamp: startTime,
        tlsVersion: tlsInfo['tls_version'] ?? 'Unknown',
        isTLS13: tlsInfo['is_tls_13'] ?? false,
        certificateValid: tlsInfo['is_certificate_valid'] ?? false,
        connectionTime: DateTime.now().difference(startTime),
        securityScore: _calculateSecurityScore(tlsInfo),
        issues: _identifySecurityIssues(tlsInfo),
      );
      
      // 记录审计日志
      await _logTLSEvent(report);
      
      // 检查安全阈值
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

  /// 批量监控关键端点
  Future<List<TLSConnectionReport>> monitorCriticalEndpoints() async {
    final reports = <TLSConnectionReport>[];
    
    for (final endpoint in _criticalEndpoints) {
      try {
        final report = await monitorTLSConnection(endpoint);
        reports.add(report);
        
        // 短暂延迟避免请求过于频繁
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('$_tag: Failed to monitor $endpoint: $e');
      }
    }
    
    // 生成综合安全报告
    await _generateSecuritySummary(reports);
    
    return reports;
  }

  /// 计算安全评分 (0-100)
  int _calculateSecurityScore(Map<String, dynamic> tlsInfo) {
    int score = 0;
    
    // TLS版本评分 (40分)
    final tlsVersion = tlsInfo['tls_version']?.toString().toLowerCase() ?? '';
    if (tlsVersion.contains('1.3')) {
      score += 40;
    } else if (tlsVersion.contains('1.2')) {
      score += 30;
    } else if (tlsVersion.contains('1.1')) {
      score += 10;
    }
    // TLS 1.0及以下得0分
    
    // 证书有效性 (30分)
    if (tlsInfo['is_certificate_valid'] == true) {
      score += 30;
    }
    
    // 连接成功性 (20分)
    if (tlsInfo['error'] == null) {
      score += 20;
    }
    
    // 证书有效期检查 (10分)
    final endValidity = tlsInfo['certificate_end_validity'];
    if (endValidity != null) {
      final expiry = DateTime.parse(endValidity);
      final daysToExpiry = expiry.difference(DateTime.now()).inDays;
      
      if (daysToExpiry > 30) {
        score += 10;
      } else if (daysToExpiry > 7) {
        score += 5;
      }
      // 7天内过期得0分
    }
    
    return score.clamp(0, 100);
  }

  /// 识别安全问题
  List<String> _identifySecurityIssues(Map<String, dynamic> tlsInfo) {
    final issues = <String>[];
    
    // TLS版本检查
    final tlsVersion = tlsInfo['tls_version']?.toString().toLowerCase() ?? '';
    if (!tlsVersion.contains('1.3') && !tlsVersion.contains('1.2')) {
      issues.add('Insecure TLS version: $tlsVersion');
    }
    
    if (!tlsVersion.contains('1.3')) {
      issues.add('TLS 1.3 not used - medical devices require latest TLS');
    }
    
    // 证书检查
    if (tlsInfo['is_certificate_valid'] != true) {
      issues.add('Invalid or untrusted certificate');
    }
    
    // 证书过期检查
    final endValidity = tlsInfo['certificate_end_validity'];
    if (endValidity != null) {
      final expiry = DateTime.parse(endValidity);
      final daysToExpiry = expiry.difference(DateTime.now()).inDays;
      
      if (daysToExpiry <= 7) {
        issues.add('Certificate expires in $daysToExpiry days - immediate action required');
      } else if (daysToExpiry <= 30) {
        issues.add('Certificate expires in $daysToExpiry days - renewal needed');
      }
    }
    
    // 连接错误检查
    if (tlsInfo['error'] != null) {
      issues.add('Connection error: ${tlsInfo['error']}');
    }
    
    return issues;
  }

  /// 记录TLS事件到审计日志
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

  /// 检查安全阈值并触发警报
  Future<void> _checkSecurityThresholds(TLSConnectionReport report) async {
    // 严重安全问题 (立即警报)
    if (report.securityScore < 50) {
      await _triggerSecurityAlert(TLSSecurityEvent.tlsVersionDowngrade, report);
    }
    
    if (!report.certificateValid) {
      await _triggerSecurityAlert(TLSSecurityEvent.certificateValidationFailure, report);
    }
    
    if (!report.isTLS13) {
      await _triggerSecurityAlert(TLSSecurityEvent.weakCipherSuite, report);
    }
    
    // 连接性能问题
    if (report.connectionTime.inSeconds > 30) {
      await _triggerSecurityAlert(TLSSecurityEvent.connectionTimeout, report);
    }
    
    // 数据完整性检查
    if (report.issues.isNotEmpty) {
      await _triggerSecurityAlert(TLSSecurityEvent.dataIntegrityFailure, report);
    }
  }

  /// 触发安全警报
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
      
      // 在生产环境中，这里应该发送到监控系统
      // 例如：AWS CloudWatch Alarms, PagerDuty, Slack等
      
    } catch (e) {
      debugPrint('$_tag: Failed to trigger security alert: $e');
    }
  }

  /// 获取事件严重程度
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

  /// 判断是否需要立即处理
  bool _requiresImmediateAction(TLSSecurityEvent eventType) {
    return [
      TLSSecurityEvent.tlsVersionDowngrade,
      TLSSecurityEvent.certificateValidationFailure,
      TLSSecurityEvent.unauthorizedAccess,
    ].contains(eventType);
  }

  /// 生成安全摘要报告
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

  /// 获取TLS合规状态
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

/// TLS连接报告
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

/// TLS合规状态
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