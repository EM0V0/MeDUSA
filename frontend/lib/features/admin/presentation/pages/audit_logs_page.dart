import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/security_education_service.dart';
import '../../../../shared/widgets/security_feature_toggle.dart';
import '../../data/services/admin_api_service.dart';

/// Audit Logs Page for Admin
/// Displays system audit logs from the real backend API
class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final AdminApiService _adminApiService = AdminApiService();
  
  String _searchQuery = '';
  String _selectedEventType = 'all';
  String _selectedSeverity = 'all';
  
  List<AuditLogItem> _logs = [];
  bool _isLoading = true;
  String? _error;
  String? _nextToken;

  // Security Education
  bool _auditLoggingEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadSecurityFeatures();
  }

  Future<void> _loadSecurityFeatures() async {
    final audit = SecurityEducationService.isFeatureEnabled('audit_logging');
    if (mounted) {
      setState(() {
        _auditLoggingEnabled = audit;
      });
    }
  }

  Future<void> _toggleAuditFeature(bool enabled) async {
    SecurityEducationService.toggleFeatureLocally('audit_logging', enabled);
    // Sync to backend so audit_service respects the toggle
    final svc = SecurityEducationService();
    svc.toggleSecurityFeature('audit_logging', enabled);
    setState(() {
      _auditLoggingEnabled = enabled;
    });
  }
  
  Future<void> _loadLogs({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    
    try {
      final response = await _adminApiService.getAuditLogs(
        eventType: _selectedEventType == 'all' ? null : _selectedEventType,
        severity: _selectedSeverity == 'all' ? null : _selectedSeverity,
        limit: 100,
        nextToken: loadMore ? _nextToken : null,
      );
      
      if (response.success) {
        setState(() {
          if (loadMore) {
            _logs.addAll(response.items);
          } else {
            _logs = response.items;
          }
          _nextToken = response.nextToken;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load audit logs';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AuditLogItem> get filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    
    return _logs.where((log) {
      final searchLower = _searchQuery.toLowerCase();
      return (log.action?.toLowerCase().contains(searchLower) ?? false) ||
          (log.userId?.toLowerCase().contains(searchLower) ?? false) ||
          (log.ipAddress?.toLowerCase().contains(searchLower) ?? false) ||
          log.eventType.toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SecurityFeatureToggleCompact(
              featureName: 'Audit Logging',
              isEnabled: _auditLoggingEnabled,
              tip: _auditLoggingEnabled
                  ? 'All actions recorded for forensic analysis & compliance'
                  : '⚠️ Audit logging disabled - no incident investigation trail!',
              onToggle: (enabled) => _toggleAuditFeature(enabled),
            ),
          ),
          _buildFiltersAndSearch(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading audit logs from server...'),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            SizedBox(height: 16.h),
            Text('Error loading audit logs', style: FontUtils.title(context: context)),
            SizedBox(height: 8.h),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadLogs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text('No audit logs found', style: FontUtils.title(context: context)),
            SizedBox(height: 8.h),
            Text(
              'Audit logs will appear here as system events occur.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return _buildLogsList();
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
                  '${_logs.length} events recorded • Real-time monitoring',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh logs',
          ),
          SizedBox(width: 8.w),
          // Live indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Live',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Event Type Filter
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedEventType,
              decoration: InputDecoration(
                labelText: 'Event Type',
                filled: true,
                fillColor: AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Events')),
                DropdownMenuItem(value: 'AUTH', child: Text('Authentication')),
                DropdownMenuItem(value: 'AUTHZ', child: Text('Authorization')),
                DropdownMenuItem(value: 'DATA', child: Text('Data Access')),
                DropdownMenuItem(value: 'DEVICE', child: Text('Device')),
                DropdownMenuItem(value: 'SECURITY', child: Text('Security')),
                DropdownMenuItem(value: 'SYSTEM', child: Text('System')),
              ],
              onChanged: (value) {
                setState(() => _selectedEventType = value ?? 'all');
                _loadLogs();
              },
            ),
          ),
          SizedBox(width: 12.w),
          // Severity Filter
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedSeverity,
              decoration: InputDecoration(
                labelText: 'Severity',
                filled: true,
                fillColor: AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Levels')),
                DropdownMenuItem(value: 'INFO', child: Text('Info')),
                DropdownMenuItem(value: 'WARNING', child: Text('Warning')),
                DropdownMenuItem(value: 'ERROR', child: Text('Error')),
                DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
              ],
              onChanged: (value) {
                setState(() => _selectedSeverity = value ?? 'all');
                _loadLogs();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    final logs = filteredLogs;
    
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: logs.length + (_nextToken != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= logs.length) {
          // Load more button
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: ElevatedButton(
                onPressed: () => _loadLogs(loadMore: true),
                child: const Text('Load More'),
              ),
            ),
          );
        }
        
        final log = logs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildLogCard(AuditLogItem log) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
          left: BorderSide(
            color: _getSeverityColor(log.severity),
            width: 4.w,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: _buildEventIcon(log.eventType),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: _getEventTypeColor(log.eventType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                log.eventType,
                style: FontUtils.caption(
                  context: context,
                  color: _getEventTypeColor(log.eventType),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: _getSeverityColor(log.severity).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                log.severity,
                style: FontUtils.caption(
                  context: context,
                  color: _getSeverityColor(log.severity),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              log.action ?? 'No action description',
              style: FontUtils.body(context: context),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                if (log.userId != null) ...[
                  Icon(Icons.person_outline, size: 12.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    log.userId!,
                    style: FontUtils.caption(context: context, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 12.w),
                ],
                Icon(Icons.computer, size: 12.sp, color: Colors.grey),
                SizedBox(width: 4.w),
                Text(
                  log.ipAddress ?? 'Unknown IP',
                  style: FontUtils.caption(context: context, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          _formatTimestamp(log.timestampDateTime),
          style: FontUtils.caption(context: context, color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildEventIcon(String eventType) {
    IconData icon;
    if (eventType.startsWith('AUTH')) {
      icon = Icons.lock_outline;
    } else if (eventType.startsWith('AUTHZ')) {
      icon = Icons.shield_outlined;
    } else if (eventType.startsWith('DATA')) {
      icon = Icons.storage_outlined;
    } else if (eventType.startsWith('DEVICE')) {
      icon = Icons.devices_outlined;
    } else if (eventType.startsWith('SECURITY')) {
      icon = Icons.security_outlined;
    } else {
      icon = Icons.info_outline;
    }

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: _getEventTypeColor(eventType).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(
        icon,
        color: _getEventTypeColor(eventType),
        size: 20.sp,
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Colors.red[700]!;
      case 'ERROR':
        return AppColors.error;
      case 'WARNING':
        return AppColors.warning;
      case 'INFO':
      default:
        return AppColors.success;
    }
  }

  Color _getEventTypeColor(String eventType) {
    if (eventType.startsWith('AUTH')) {
      return Colors.blue;
    } else if (eventType.startsWith('AUTHZ')) {
      return Colors.orange;
    } else if (eventType.startsWith('DATA')) {
      return Colors.green;
    } else if (eventType.startsWith('DEVICE')) {
      return Colors.purple;
    } else if (eventType.startsWith('SECURITY')) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
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
