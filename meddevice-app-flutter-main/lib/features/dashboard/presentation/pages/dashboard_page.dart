import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConstants.defaultPadding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            SizedBox(height: 28.h),

            // Stats Grid
            _buildStatsGrid(),
            SizedBox(height: 28.h),

            // Chart Section
            _buildChartSection(),
            SizedBox(height: 28.h),

            // Recent Activity
            _buildRecentActivity(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Monitoring Dashboard',
                  style: FontUtils.title(
                    context: context,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Welcome back, Dr. Smith. You have 3 critical patients today.',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (ResponsiveBreakpoints.of(context).largerThan(MOBILE)) ...[
            SizedBox(width: 20.w),
            ElevatedButton.icon(
              onPressed: () {
                _showAddPatientDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              icon: Icon(
                Icons.add,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              label: Text(
                'Add Patient',
                style: FontUtils.body(
                  context: context,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return ResponsiveBreakpoints.of(context).smallerThan(TABLET)
        ? Column(
            children: [
              _buildStatCard('Total Patients', '24', '+2', Icons.people),
              SizedBox(height: 16.h),
              _buildStatCard('Critical Alerts', '3', 'Needs attention', Icons.warning),
              SizedBox(height: 16.h),
              _buildStatCard('Active Sensors', '18', 'Online', Icons.sensors),
              SizedBox(height: 16.h),
              _buildStatCard('Data Quality', '94%', '+2%', Icons.analytics),
            ],
          )
        : Row(
            children: [
              Expanded(child: _buildStatCard('Total Patients', '24', '+2', Icons.people)),
              SizedBox(width: 16.w),
              Expanded(child: _buildStatCard('Critical Alerts', '3', 'Needs attention', Icons.warning)),
              SizedBox(width: 16.w),
              Expanded(child: _buildStatCard('Active Sensors', '18', 'Online', Icons.sensors)),
              SizedBox(width: 16.w),
              Expanded(child: _buildStatCard('Data Quality', '94%', '+2%', Icons.analytics)),
            ],
          );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () => _showStatDetails(title, value, subtitle),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primary,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                value,
                style: FontUtils.title(
                  context: context,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                subtitle,
                style: FontUtils.body(
                  context: context,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive title layout
            ResponsiveBreakpoints.of(context).smallerThan(TABLET)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tremor Activity Overview',
                        style: FontUtils.title(
                          context: context,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightOnSurface,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: _buildTimeRangeSelector(),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Tremor Activity Overview',
                          style: FontUtils.title(
                            context: context,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightOnSurface,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      _buildTimeRangeSelector(),
                    ],
                  ),
            SizedBox(height: 20.h),

            // Enhanced chart area
            Container(
              height: 320.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.lightDivider, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.show_chart,
                      size: IconUtils.getProtectedSize(
                        context,
                        targetSize: 48.0,
                        minSize: 36.0, // Never smaller than 36px
                      ),
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Chart will be displayed here',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.lightOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Real-time tremor data visualization',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SegmentedButton<String>(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.lightOnSurface,
          // Mobile optimization: increase button padding
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.w : 12.w,
            vertical: isMobile ? 12.h : 8.h,
          ),
        ),
        segments: [
          ButtonSegment(
            value: 'realtime',
            label: Text(
              isMobile ? 'Real-time' : 'Real-time',
              // Mobile optimization: ensure minimum readability
              style: FontUtils.body(
                context: context,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ButtonSegment(
            value: 'hourly',
            label: Text(
              'Hourly',
              // Mobile optimization: ensure minimum readability
              style: FontUtils.body(
                context: context,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ButtonSegment(
            value: 'daily',
            label: Text(
              'Daily',
              // Mobile optimization: ensure minimum readability
              style: FontUtils.body(
                context: context,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        selected: const {'realtime'},
        onSelectionChanged: (selection) {
          // TODO: Handle time range change
        },
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Patient Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurface,
                  ),
            ),
            SizedBox(height: 20.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (context, index) => Divider(
                height: 24.h,
                color: AppColors.lightDivider,
              ),
              itemBuilder: (context, index) {
                return _buildActivityItem(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(int index) {
    final activities = [
      {'name': 'John Doe', 'status': 'High tremor detected', 'time': '2 min ago', 'severity': 'high'},
      {'name': 'Jane Smith', 'status': 'Normal activity', 'time': '15 min ago', 'severity': 'normal'},
      {'name': 'Bob Johnson', 'status': 'Medication reminder', 'time': '30 min ago', 'severity': 'info'},
      {'name': 'Alice Brown', 'status': 'Data sync completed', 'time': '1 hour ago', 'severity': 'normal'},
      {'name': 'Charlie Wilson', 'status': 'Sensor offline', 'time': '2 hours ago', 'severity': 'warning'},
    ];

    final activity = activities[index];
    final severity = activity['severity']!;

    Color statusColor;
    IconData statusIcon;

    switch (severity) {
      case 'high':
        statusColor = AppColors.error;
        statusIcon = Icons.warning;
        break;
      case 'warning':
        statusColor = AppColors.warning;
        statusIcon = Icons.info;
        break;
      case 'info':
        statusColor = AppColors.info;
        statusIcon = Icons.notification_important;
        break;
      default:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['name']!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightOnSurface,
                      ),
                ),
                SizedBox(height: 4.h),
                Text(
                  activity['status']!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            activity['time']!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.lightOnSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  void _showAddPatientDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: FontUtils.titleText('Add New Patient', context),
          content: FontUtils.bodyText('This feature will be implemented in the next update.', context),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: FontUtils.bodyText('Cancel', context),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: FontUtils.bodyText(
                      'Patient added successfully!',
                      context
                    ),
                  ),
                );
              },
              child: Text(
                'Add',
                style: FontUtils.body(
                  context: context,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showStatDetails(String title, String value, String subtitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Value: $value'),
              SizedBox(height: 10.h),
              Text('Subtitle: $subtitle'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: FontUtils.bodyText('Close', context),
            ),
          ],
        );
      },
    );
  }
}
