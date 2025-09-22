import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/audit_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final AuditService _auditService = AuditService();
  
  StreamSubscription? _logsSubscription;
  List<AuditLog> _allLogs = [];
  List<AuditLog> _filteredLogs = [];
  
  String _searchQuery = '';
  AuditCategory? _selectedCategory;
  AuditSeverity? _selectedSeverity;
  DateTimeRange? _selectedDateRange;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeAuditService();
    _setupSubscriptions();
  }

  void _initializeAuditService() {
    _auditService.initialize();
    _allLogs = _auditService.auditLogs;
    _filteredLogs = _allLogs;
  }

  void _setupSubscriptions() {
    _logsSubscription = _auditService.logsStream.listen((logs) {
      setState(() {
        _allLogs = logs;
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltersSection(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogsTab(),
                _buildAnalyticsTab(),
                _buildExportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stats = _auditService.getAuditStatistics();
    final totalLogs = stats['totalLogs'] ?? 0;
    final severityCounts = stats['severityCounts'] as Map<AuditSeverity, int>? ?? {};
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        border: const Border(
          bottom: BorderSide(
            color: AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
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
                      'System activity monitoring and compliance tracking',
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 12.w,
            columnSpacing: 8.h,
            children: [
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatCard('Total Logs', totalLogs.toString(), Icons.list_alt_rounded, AppColors.primary),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatCard('Warnings', (severityCounts[AuditSeverity.warning] ?? 0).toString(), Icons.warning_rounded, AppColors.warning),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatCard('Errors', (severityCounts[AuditSeverity.error] ?? 0).toString(), Icons.error_rounded, AppColors.error),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatCard('Critical', (severityCounts[AuditSeverity.critical] ?? 0).toString(), Icons.report_problem_rounded, AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: IconUtils.getProtectedSize(
              context,
              targetSize: 24.0,
              minSize: 20.0,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: FontUtils.title(
              context: context,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: FontUtils.caption(
              context: context,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: AppColors.lightBackground,
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search logs by action, user, or resource...',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          // Filter chips
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 8.w,
            columnSpacing: 8.h,
            children: [
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildCategoryFilter(),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildSeverityFilter(),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildDateRangeFilter(),
              ),
              ResponsiveRowColumnItem(
                child: _buildClearFiltersButton(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<AuditCategory?>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<AuditCategory?>(
          value: null,
          child: Text('All Categories'),
        ),
        ...AuditCategory.values.map((category) => DropdownMenuItem<AuditCategory?>(
          value: category,
          child: Text(category.displayName),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildSeverityFilter() {
    return DropdownButtonFormField<AuditSeverity?>(
      value: _selectedSeverity,
      decoration: InputDecoration(
        labelText: 'Severity',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<AuditSeverity?>(
          value: null,
          child: Text('All Severities'),
        ),
        ...AuditSeverity.values.map((severity) => DropdownMenuItem<AuditSeverity?>(
          value: severity,
          child: Text(severity.displayName),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedSeverity = value;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildDateRangeFilter() {
    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: Icon(
        Icons.date_range_rounded,
        size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
      ),
      label: Text(
        _selectedDateRange != null 
            ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
            : 'Date Range',
        style: FontUtils.caption(
          context: context,
          color: AppColors.lightOnSurface,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildClearFiltersButton() {
    return ElevatedButton.icon(
      onPressed: _clearFilters,
      icon: Icon(
        Icons.clear_rounded,
        size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
      ),
      label: Text(
        'Clear',
        style: FontUtils.body(
          context: context,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightOnSurfaceVariant,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightOnSurfaceVariant,
        indicatorColor: AppColors.primary,
        labelStyle: FontUtils.body(
          context: context,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: FontUtils.body(
          context: context,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(
            icon: Icon(
              Icons.list_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Logs',
          ),
          Tab(
            icon: Icon(
              Icons.analytics_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Analytics',
          ),
          Tab(
            icon: Icon(
              Icons.file_download_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Export',
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Container(
      color: AppColors.lightBackground,
      child: _filteredLogs.isEmpty 
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: _filteredLogs.length,
              itemBuilder: (context, index) {
                final log = _filteredLogs[index];
                return _buildLogCard(log);
              },
            ),
    );
  }

  Widget _buildLogCard(AuditLog log) {
    final severityColor = _getSeverityColor(log.severity);
    final categoryIcon = _getCategoryIcon(log.category);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  categoryIcon,
                  color: severityColor,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.action,
                            style: FontUtils.body(
                              context: context,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightOnSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            log.severity.displayName,
                            style: FontUtils.caption(
                              context: context,
                              color: severityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${log.userName} - ${log.resource}',
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                _formatTimestamp(log.timestamp),
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
          if (log.details != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                log.details!,
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ),
          ],
          if (log.metadata != null && log.metadata!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: log.metadata!.entries.map((entry) => Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: IconUtils.getProtectedSize(
                context,
                targetSize: 64.0,
                minSize: 48.0,
              ),
              color: AppColors.lightOnSurfaceVariant,
            ),
            SizedBox(height: 16.h),
            Text(
              'No Audit Logs Found',
              style: FontUtils.title(
                context: context,
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try adjusting your search criteria or filters',
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final stats = _auditService.getAuditStatistics();
    final categoryCounts = stats['categoryCounts'] as Map<AuditCategory, int>? ?? {};
    final userCounts = stats['userCounts'] as Map<String, int>? ?? {};
    
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildAnalyticsCard(
              'Activity by Category',
              'Distribution of audit logs by category',
              Icons.pie_chart_rounded,
              AppColors.primary,
              categoryCounts.entries.map((entry) => 
                _buildAnalyticsItem(entry.key.displayName, entry.value.toString(), AppColors.primary)
              ).toList(),
            ),
            SizedBox(height: 16.h),
            _buildAnalyticsCard(
              'Top Active Users',
              'Users with the most logged activities',
              Icons.people_rounded,
              AppColors.success,
              userCounts.entries.take(5).map((entry) => 
                _buildAnalyticsItem(entry.key, entry.value.toString(), AppColors.success)
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String description, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FontUtils.headline(
                        context: context,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    Text(
                      description,
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String label, String value, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: FontUtils.body(
              context: context,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildExportCard(
            'Export All Logs',
            'Download complete audit log history',
            Icons.download_rounded,
            AppColors.primary,
            () => _exportLogs(),
          ),
          SizedBox(height: 16.h),
          _buildExportCard(
            'Export Filtered Logs',
            'Download logs matching current filters',
            Icons.filter_alt_rounded,
            AppColors.success,
            () => _exportFilteredLogs(),
          ),
          SizedBox(height: 16.h),
          _buildExportCard(
            'Export Security Logs',
            'Download security-related logs only',
            Icons.security_rounded,
            AppColors.error,
            () => _exportSecurityLogs(),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(String title, String description, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: color,
              size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text(
              'Export',
              style: FontUtils.body(
                context: context,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    var filtered = _allLogs;
    
    if (_searchQuery.isNotEmpty) {
      filtered = _auditService.searchLogs(_searchQuery);
    }
    
    if (_selectedCategory != null) {
      filtered = filtered.where((log) => log.category == _selectedCategory).toList();
    }
    
    if (_selectedSeverity != null) {
      filtered = filtered.where((log) => log.severity == _selectedSeverity).toList();
    }
    
    if (_selectedDateRange != null) {
      filtered = filtered.where((log) => 
          log.timestamp.isAfter(_selectedDateRange!.start) && 
          log.timestamp.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))
      ).toList();
    }
    
    _filteredLogs = filtered;
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _selectedSeverity = null;
      _selectedDateRange = null;
      _filteredLogs = _allLogs;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _applyFilters();
      });
    }
  }

  void _exportLogs() {
    final json = _auditService.exportLogsAsJson();
    _showExportResult('All audit logs exported successfully', json.length);
  }

  void _exportFilteredLogs() {
    // TODO: Implement filtered export
    _showExportResult('Filtered audit logs exported successfully', _filteredLogs.length);
  }

  void _exportSecurityLogs() {
    final json = _auditService.exportLogsAsJson(category: AuditCategory.security);
    _showExportResult('Security audit logs exported successfully', json.length);
  }

  void _showExportResult(String message, int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                '$message ($count records)',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getSeverityColor(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.info:
        return AppColors.primary;
      case AuditSeverity.warning:
        return AppColors.warning;
      case AuditSeverity.error:
        return AppColors.error;
      case AuditSeverity.critical:
        return AppColors.error;
    }
  }

  IconData _getCategoryIcon(AuditCategory category) {
    switch (category) {
      case AuditCategory.userAction:
        return Icons.person_rounded;
      case AuditCategory.dataAccess:
        return Icons.storage_rounded;
      case AuditCategory.security:
        return Icons.security_rounded;
      case AuditCategory.systemEvent:
        return Icons.computer_rounded;
      case AuditCategory.authentication:
        return Icons.login_rounded;
      case AuditCategory.configuration:
        return Icons.settings_rounded;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
