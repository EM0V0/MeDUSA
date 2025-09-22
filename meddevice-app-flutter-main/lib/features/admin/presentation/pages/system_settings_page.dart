import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // General Settings
  bool _maintenanceMode = false;
  bool _autoBackup = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  int _sessionTimeout = 30; // minutes
  String _timezone = 'UTC+8';
  
  // Security Settings
  bool _twoFactorAuth = true;
  bool _passwordComplexity = true;
  bool _loginAttemptLimit = true;
  int _maxLoginAttempts = 5;
  int _passwordExpiry = 90; // days
  
  // Data Settings
  bool _dataEncryption = true;
  bool _auditLogging = true;
  int _dataRetention = 365; // days
  String _backupFrequency = 'daily';
  
  // System Performance
  int _maxConcurrentUsers = 100;
  bool _performanceMonitoring = true;
  bool _errorReporting = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildSecurityTab(),
                _buildDataTab(),
                _buildPerformanceTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSettings,
        backgroundColor: AppColors.success,
        icon: Icon(
          Icons.save_rounded,
          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        ),
        label: Text(
          'Save Settings',
          style: FontUtils.body(
            context: context,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning.withValues(alpha: 0.1),
            AppColors.warning.withValues(alpha: 0.05),
          ],
        ),
        border: const Border(
          bottom: BorderSide(
            color: AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.settings_rounded,
              color: AppColors.warning,
              size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Settings',
                  style: FontUtils.display(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Configure system-wide settings and preferences',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _maintenanceMode 
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: _maintenanceMode 
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: _maintenanceMode ? AppColors.error : AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  _maintenanceMode ? 'Maintenance Mode' : 'System Online',
                  style: FontUtils.label(
                    context: context,
                    color: _maintenanceMode ? AppColors.error : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.warning,
        unselectedLabelColor: AppColors.lightOnSurfaceVariant,
        indicatorColor: AppColors.warning,
        isScrollable: ResponsiveBreakpoints.of(context).smallerThan(TABLET),
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
              Icons.tune_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'General',
          ),
          Tab(
            icon: Icon(
              Icons.security_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Security',
          ),
          Tab(
            icon: Icon(
              Icons.storage_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Data',
          ),
          Tab(
            icon: Icon(
              Icons.speed_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Performance',
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSettingsCard(
              'System Configuration',
              'Basic system settings and operational modes',
              Icons.settings_applications_rounded,
              AppColors.primary,
              [
                _buildSwitchTile(
                  'Maintenance Mode',
                  'Enable maintenance mode to restrict system access',
                  _maintenanceMode,
                  (value) => setState(() => _maintenanceMode = value),
                  icon: Icons.build_rounded,
                ),
                _buildSwitchTile(
                  'Auto Backup',
                  'Automatically backup system data daily',
                  _autoBackup,
                  (value) => setState(() => _autoBackup = value),
                  icon: Icons.backup_rounded,
                ),
                _buildDropdownTile(
                  'Timezone',
                  'System timezone for all operations',
                  _timezone,
                  ['UTC+8', 'UTC+0', 'UTC-5', 'UTC-8'],
                  (value) => setState(() => _timezone = value!),
                  icon: Icons.access_time_rounded,
                ),
                _buildSliderTile(
                  'Session Timeout',
                  'User session timeout in minutes',
                  _sessionTimeout.toDouble(),
                  5.0,
                  120.0,
                  (value) => setState(() => _sessionTimeout = value.round()),
                  '$_sessionTimeout min',
                  icon: Icons.timer_rounded,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildSettingsCard(
              'Notifications',
              'Configure system notification preferences',
              Icons.notifications_rounded,
              AppColors.success,
              [
                _buildSwitchTile(
                  'Email Notifications',
                  'Send system alerts via email',
                  _emailNotifications,
                  (value) => setState(() => _emailNotifications = value),
                  icon: Icons.email_rounded,
                ),
                _buildSwitchTile(
                  'SMS Notifications',
                  'Send critical alerts via SMS',
                  _smsNotifications,
                  (value) => setState(() => _smsNotifications = value),
                  icon: Icons.sms_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSettingsCard(
              'Authentication & Access',
              'Security settings for user authentication',
              Icons.verified_user_rounded,
              AppColors.error,
              [
                _buildSwitchTile(
                  'Two-Factor Authentication',
                  'Require 2FA for all administrative accounts',
                  _twoFactorAuth,
                  (value) => setState(() => _twoFactorAuth = value),
                  icon: Icons.security_rounded,
                ),
                _buildSwitchTile(
                  'Password Complexity',
                  'Enforce strong password requirements',
                  _passwordComplexity,
                  (value) => setState(() => _passwordComplexity = value),
                  icon: Icons.password_rounded,
                ),
                _buildSwitchTile(
                  'Login Attempt Limit',
                  'Limit failed login attempts per account',
                  _loginAttemptLimit,
                  (value) => setState(() => _loginAttemptLimit = value),
                  icon: Icons.block_rounded,
                ),
                _buildSliderTile(
                  'Max Login Attempts',
                  'Maximum failed attempts before account lockout',
                  _maxLoginAttempts.toDouble(),
                  3.0,
                  10.0,
                  (value) => setState(() => _maxLoginAttempts = value.round()),
                  '$_maxLoginAttempts attempts',
                  icon: Icons.warning_rounded,
                ),
                _buildSliderTile(
                  'Password Expiry',
                  'Days before password must be changed',
                  _passwordExpiry.toDouble(),
                  30.0,
                  365.0,
                  (value) => setState(() => _passwordExpiry = value.round()),
                  '$_passwordExpiry days',
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSettingsCard(
              'Data Management',
              'Settings for data storage, backup, and retention',
              Icons.storage_rounded,
              AppColors.primary,
              [
                _buildSwitchTile(
                  'Data Encryption',
                  'Encrypt all stored patient data',
                  _dataEncryption,
                  (value) => setState(() => _dataEncryption = value),
                  icon: Icons.enhanced_encryption_rounded,
                ),
                _buildSwitchTile(
                  'Audit Logging',
                  'Log all system activities for compliance',
                  _auditLogging,
                  (value) => setState(() => _auditLogging = value),
                  icon: Icons.history_rounded,
                ),
                _buildDropdownTile(
                  'Backup Frequency',
                  'How often to backup system data',
                  _backupFrequency,
                  ['hourly', 'daily', 'weekly', 'monthly'],
                  (value) => setState(() => _backupFrequency = value!),
                  icon: Icons.backup_table_rounded,
                ),
                _buildSliderTile(
                  'Data Retention',
                  'Days to retain system data before archival',
                  _dataRetention.toDouble(),
                  30.0,
                  1825.0, // 5 years
                  (value) => setState(() => _dataRetention = value.round()),
                  '$_dataRetention days',
                  icon: Icons.archive_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSettingsCard(
              'System Performance',
              'Configure performance and monitoring settings',
              Icons.speed_rounded,
              AppColors.warning,
              [
                _buildSwitchTile(
                  'Performance Monitoring',
                  'Monitor system performance metrics',
                  _performanceMonitoring,
                  (value) => setState(() => _performanceMonitoring = value),
                  icon: Icons.monitor_heart_rounded,
                ),
                _buildSwitchTile(
                  'Error Reporting',
                  'Automatically report system errors',
                  _errorReporting,
                  (value) => setState(() => _errorReporting = value),
                  icon: Icons.bug_report_rounded,
                ),
                _buildSliderTile(
                  'Max Concurrent Users',
                  'Maximum number of concurrent system users',
                  _maxConcurrentUsers.toDouble(),
                  10.0,
                  500.0,
                  (value) => setState(() => _maxConcurrentUsers = value.round()),
                  '$_maxConcurrentUsers users',
                  icon: Icons.people_rounded,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildSystemStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(String title, String description, IconData icon, Color color, List<Widget> children) {
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
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                ),
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

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged, {IconData? icon}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: icon != null ? Icon(
          icon,
          color: AppColors.lightOnSurfaceVariant,
          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        ) : null,
        title: Text(
          title,
          style: FontUtils.body(
            context: context,
            color: AppColors.lightOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: FontUtils.caption(
            context: context,
            color: AppColors.lightOnSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.success,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDropdownTile<T>(String title, String subtitle, T value, List<T> items, ValueChanged<T?> onChanged, {IconData? icon}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: AppColors.lightOnSurfaceVariant,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
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
          SizedBox(height: 8.h),
          DropdownButtonFormField<T>(
            value: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            items: items.map((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString()),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(String title, String subtitle, double value, double min, double max, ValueChanged<double> onChanged, String displayValue, {IconData? icon}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: AppColors.lightOnSurfaceVariant,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  displayValue,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
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
                Icons.monitor_heart_rounded,
                color: AppColors.success,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'System Status',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 16.w,
            columnSpacing: 12.h,
            children: [
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusItem('CPU Usage', '45%', AppColors.success, Icons.memory_rounded),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusItem('Memory', '2.1GB', AppColors.warning, Icons.storage_rounded),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusItem('Disk Space', '78%', AppColors.error, Icons.storage_rounded),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusItem('Network', 'Online', AppColors.success, Icons.wifi_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: FontUtils.body(
              context: context,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: FontUtils.caption(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    // TODO: Implement actual settings save logic
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
            Text(
              'Settings saved successfully',
              style: FontUtils.body(
                context: context,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
