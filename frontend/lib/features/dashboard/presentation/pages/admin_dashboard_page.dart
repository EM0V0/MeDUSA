import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/role_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final RoleService _roleService = RoleService();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24.h),
            _buildSystemMetrics(),
            SizedBox(height: 24.h),
            if (isDesktop) 
              _buildDesktopLayout()
            else 
              _buildMobileLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.error.withValues(alpha: 0.1),
            AppColors.error.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.error,
              size: IconUtils.getResponsiveIconSize(IconSizeType.xlarge, context),
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Administration',
                  style: FontUtils.display(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Complete control and monitoring of the medical system',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.error,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Administrator - ${_roleService.currentUser?.name ?? 'Admin'}',
                        style: FontUtils.label(
                          context: context,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMetrics() {
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
                Icons.analytics_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'System Health Overview',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 16.w,
            columnSpacing: 16.h,
            children: [
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildMetricCard(
                  'Active Users',
                  '1,247',
                  Icons.people_rounded,
                  AppColors.success,
                  '+12%',
                ),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildMetricCard(
                  'Connected Devices',
                  '856',
                  Icons.devices_rounded,
                  AppColors.primary,
                  '+5%',
                ),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildMetricCard(
                  'System Uptime',
                  '99.9%',
                  Icons.trending_up_rounded,
                  AppColors.success,
                  '24h',
                ),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildMetricCard(
                  'Data Storage',
                  '2.4 TB',
                  Icons.storage_rounded,
                  AppColors.warning,
                  '78%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.1),
          width: 1,
        ),
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
                  size: IconUtils.getProtectedSize(
                    context,
                    targetSize: 20.0,
                    minSize: 18.0,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  trend,
                  style: FontUtils.caption(
                    context: context,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: FontUtils.title(
              context: context,
              color: AppColors.lightOnSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildQuickActions(),
              SizedBox(height: 24.h),
              _buildRecentActivity(),
            ],
          ),
        ),
        SizedBox(width: 24.w),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildSystemAlerts(),
              SizedBox(height: 24.h),
              _buildQuickStats(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildQuickActions(),
        SizedBox(height: 24.h),
        _buildSystemAlerts(),
        SizedBox(height: 24.h),
        _buildRecentActivity(),
        SizedBox(height: 24.h),
        _buildQuickStats(),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _AdminAction('User Management', Icons.people_rounded, AppColors.primary, '/user-management'),
      _AdminAction('Device Management', Icons.devices_rounded, AppColors.success, '/device-management'),
      _AdminAction('System Settings', Icons.settings_rounded, AppColors.warning, '/system-settings'),
      _AdminAction('Audit Logs', Icons.history_rounded, AppColors.error, '/audit-logs'),
      _AdminAction('Backup & Restore', Icons.backup_rounded, AppColors.primary, '/backup'),
      _AdminAction('Security Center', Icons.security_rounded, AppColors.error, '/security'),
    ];

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
                Icons.dashboard_customize_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Quick Actions',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
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
            columnSpacing: 12.h,
            children: actions.map((action) => ResponsiveRowColumnItem(
              rowFlex: 1,
              child: _buildActionCard(action),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(_AdminAction action) {
    return InkWell(
      onTap: () {
        // Navigate to the action route
        context.go(action.route);
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: action.color.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: IconUtils.getProtectedSize(
                  context,
                  targetSize: 24.0,
                  minSize: 20.0,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              action.title,
              style: FontUtils.label(
                context: context,
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAlerts() {
    final alerts = [
      _SystemAlert('High CPU Usage', 'Server load at 85%', Icons.warning_rounded, AppColors.warning),
      _SystemAlert('Failed Login Attempts', '12 attempts from unknown IP', Icons.security_rounded, AppColors.error),
      _SystemAlert('Backup Completed', 'Daily backup successful', Icons.check_circle_rounded, AppColors.success),
    ];

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
                Icons.notifications_active_rounded,
                color: AppColors.error,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'System Alerts',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...alerts.map((alert) => _buildAlertItem(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertItem(_SystemAlert alert) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.icon,
            color: alert.color,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alert.description,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
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
                Icons.history_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Recent Activity',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildActivityItem('Dr. Smith logged in', '2 minutes ago', Icons.login_rounded),
          _buildActivityItem('New device registered', '15 minutes ago', Icons.add_circle_rounded),
          _buildActivityItem('System backup completed', '1 hour ago', Icons.backup_rounded),
          _buildActivityItem('User permissions updated', '2 hours ago', Icons.security_rounded),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
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
    );
  }

  Widget _buildQuickStats() {
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
                Icons.bar_chart_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Quick Stats',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildStatItem('Total Doctors', '156', AppColors.primary),
          _buildStatItem('Total Patients', '1,091', AppColors.success),
          _buildStatItem('Active Sessions', '342', AppColors.warning),
          _buildStatItem('Data Processed', '45.2 GB', AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurface,
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
}

class _AdminAction {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _AdminAction(this.title, this.icon, this.color, this.route);
}

class _SystemAlert {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _SystemAlert(this.title, this.description, this.icon, this.color);
}
