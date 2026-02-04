import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

/// Audit Logs Page for Admin
/// Displays system audit logs for security and compliance monitoring
class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  String _searchQuery = '';
  String _selectedEventType = 'all';
  String _selectedSeverity = 'all';

  // Mock audit log data
  final List<_AuditLog> _logs = [
    _AuditLog(
      id: 'log_001',
      eventType: 'AUTH_LOGIN_SUCCESS',
      severity: 'INFO',
      userId: 'usr_5170e6f3',
      userEmail: 'andysun12@outlook.com',
      action: 'User logged in successfully',
      ipAddress: '128.220.159.215',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    _AuditLog(
      id: 'log_002',
      eventType: 'AUTH_LOGIN_FAILURE',
      severity: 'WARNING',
      userId: null,
      userEmail: 'unknown@example.com',
      action: 'Failed login attempt - invalid password',
      ipAddress: '192.168.1.100',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    _AuditLog(
      id: 'log_003',
      eventType: 'DATA_CREATE',
      severity: 'INFO',
      userId: 'usr_e679f321',
      userEmail: 'zsun54@jh.edu',
      action: 'Created new patient session',
      ipAddress: '128.220.159.215',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    _AuditLog(
      id: 'log_004',
      eventType: 'AUTHZ_ACCESS_DENIED',
      severity: 'ERROR',
      userId: 'usr_5170e6f3',
      userEmail: 'andysun12@outlook.com',
      action: 'Attempted to access admin endpoint',
      ipAddress: '128.220.159.215',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _AuditLog(
      id: 'log_005',
      eventType: 'DEVICE_REGISTER',
      severity: 'INFO',
      userId: 'usr_48e4ea5b',
      userEmail: 'baiyianying1999@gmail.com',
      action: 'Registered new device dev_001',
      ipAddress: '128.220.159.215',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _AuditLog(
      id: 'log_006',
      eventType: 'SECURITY_RATE_LIMIT',
      severity: 'CRITICAL',
      userId: null,
      userEmail: null,
      action: 'Rate limit exceeded from IP',
      ipAddress: '45.33.32.156',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _AuditLog(
      id: 'log_007',
      eventType: 'AUTH_MFA_SUCCESS',
      severity: 'INFO',
      userId: 'usr_e679f321',
      userEmail: 'zsun54@jh.edu',
      action: 'MFA verification successful',
      ipAddress: '128.220.159.215',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  List<_AuditLog> get filteredLogs {
    return _logs.where((log) {
      final matchesSearch = log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (log.userEmail?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          log.ipAddress.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedEventType == 'all' || log.eventType.startsWith(_selectedEventType);
      final matchesSeverity = _selectedSeverity == 'all' || log.severity == _selectedSeverity;
      return matchesSearch && matchesType && matchesSeverity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltersAndSearch(),
          Expanded(child: _buildLogsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.history_rounded,
              color: AppColors.error,
              size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Logs',
                  style: FontUtils.display(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${_logs.length} events recorded',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildSeverityStats(),
        ],
      ),
    );
  }

  Widget _buildSeverityStats() {
    final info = _logs.where((l) => l.severity == 'INFO').length;
    final warning = _logs.where((l) => l.severity == 'WARNING').length;
    final error = _logs.where((l) => l.severity == 'ERROR').length;
    final critical = _logs.where((l) => l.severity == 'CRITICAL').length;

    return Row(
      children: [
        _buildStatChip('Info', info, AppColors.info),
        SizedBox(width: 6.w),
        _buildStatChip('Warn', warning, AppColors.warning),
        SizedBox(width: 6.w),
        _buildStatChip('Error', error, AppColors.error),
        SizedBox(width: 6.w),
        _buildStatChip('Critical', critical, Colors.purple),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            count.toString(),
            style: FontUtils.caption(
              context: context,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.lightOutline),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SizedBox(width: 12.w),
          DropdownButton<String>(
            value: _selectedEventType,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Events')),
              DropdownMenuItem(value: 'AUTH', child: Text('Auth')),
              DropdownMenuItem(value: 'DATA', child: Text('Data')),
              DropdownMenuItem(value: 'DEVICE', child: Text('Device')),
              DropdownMenuItem(value: 'SECURITY', child: Text('Security')),
            ],
            onChanged: (value) => setState(() => _selectedEventType = value ?? 'all'),
          ),
          SizedBox(width: 12.w),
          DropdownButton<String>(
            value: _selectedSeverity,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Severity')),
              DropdownMenuItem(value: 'INFO', child: Text('Info')),
              DropdownMenuItem(value: 'WARNING', child: Text('Warning')),
              DropdownMenuItem(value: 'ERROR', child: Text('Error')),
              DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
            ],
            onChanged: (value) => setState(() => _selectedSeverity = value ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    final logs = filteredLogs;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'No logs found',
              style: FontUtils.title(context: context, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: logs.length,
      itemBuilder: (context, index) => _buildLogCard(logs[index]),
    );
  }

  Widget _buildLogCard(_AuditLog log) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ExpansionTile(
        leading: _buildSeverityIcon(log.severity),
        title: Text(
          log.eventType,
          style: FontUtils.body(
            context: context,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _formatTimestamp(log.timestamp),
          style: FontUtils.caption(context: context, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Action', log.action),
                _buildDetailRow('User', log.userEmail ?? 'N/A'),
                _buildDetailRow('IP Address', log.ipAddress),
                _buildDetailRow('Log ID', log.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityIcon(String severity) {
    final color = _getSeverityColor(severity);
    final icon = _getSeverityIcon(severity);
    
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'INFO':
        return AppColors.info;
      case 'WARNING':
        return AppColors.warning;
      case 'ERROR':
        return AppColors.error;
      case 'CRITICAL':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'INFO':
        return Icons.info_outline;
      case 'WARNING':
        return Icons.warning_outlined;
      case 'ERROR':
        return Icons.error_outline;
      case 'CRITICAL':
        return Icons.dangerous_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: FontUtils.body(
                context: context,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: FontUtils.body(context: context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _AuditLog {
  final String id;
  final String eventType;
  final String severity;
  final String? userId;
  final String? userEmail;
  final String action;
  final String ipAddress;
  final DateTime timestamp;

  _AuditLog({
    required this.id,
    required this.eventType,
    required this.severity,
    this.userId,
    this.userEmail,
    required this.action,
    required this.ipAddress,
    required this.timestamp,
  });
}
