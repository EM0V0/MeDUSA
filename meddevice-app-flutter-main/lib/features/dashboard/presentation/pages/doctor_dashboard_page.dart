import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/role_service.dart';
import '../../../../shared/widgets/patient_selector.dart';

/// Enhanced dashboard page specifically designed for doctors
/// Features patient selection and multi-patient data visualization
class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final RoleService _roleService = RoleService();
  PatientInfo? _selectedPatient;
  String _selectedTimeRange = 'today';
  String _selectedDataType = 'tremor';

  final List<String> _timeRanges = ['today', 'week', 'month', 'quarter'];
  final List<String> _dataTypes = ['tremor', 'medication', 'activity', 'sleep'];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConstants.defaultPadding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24.h),
            
            if (isMobile) ...[
              _buildPatientSelector(),
              SizedBox(height: 20.h),
              _buildControlsSection(),
              SizedBox(height: 20.h),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildPatientSelector()),
                  SizedBox(width: 20.w),
                  Expanded(flex: 3, child: _buildControlsSection()),
                ],
              ),
              SizedBox(height: 24.h),
            ],
            
            _buildOverviewStats(),
            SizedBox(height: 24.h),
            _buildDataVisualizationSection(isMobile),
            SizedBox(height: 24.h),
            _buildRecentAlertsSection(),
          ],
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
            Colors.white,
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.lightDivider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.dashboard_rounded,
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
                  'Medical Dashboard',
                  style: FontUtils.headline(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Monitor and analyze your patients\' health data',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_hospital_rounded,
                  color: AppColors.success,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Dr. ${_roleService.currentUser?.name ?? 'Doctor'}',
                  style: FontUtils.label(
                    context: context,
                    color: AppColors.success,
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

  Widget _buildPatientSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightOnSurface.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: PatientSelector(
          selectedPatientId: _selectedPatient?.id,
          onPatientSelected: (patient) {
            setState(() {
              _selectedPatient = patient;
            });
          },
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightOnSurface.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Controls',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 16.h),
            
            // Time range selector with refined label
            Text(
              'Time Range',
              style: FontUtils.label(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 8.h),
            _buildTimeRangeSelector(),
            
            SizedBox(height: 20.h),
            
            // Data type selector with refined label
            Text(
              'Data Type',
              style: FontUtils.label(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 8.h),
            _buildDataTypeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _timeRanges.map((range) {
        final isSelected = _selectedTimeRange == range;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTimeRange = range;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary 
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary 
                    : AppColors.lightDivider,
              ),
            ),
            child: Text(
              range.toUpperCase(),
              style: FontUtils.caption(
                context: context,
                color: isSelected 
                    ? AppColors.onPrimary 
                    : AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDataTypeSelector() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _dataTypes.map((type) {
        final isSelected = _selectedDataType == type;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDataType = type;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary 
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary 
                    : AppColors.lightDivider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getDataTypeIcon(type),
                  size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                  color: isSelected 
                      ? AppColors.onPrimary 
                      : AppColors.lightOnSurface,
                ),
                SizedBox(width: 4.w),
                Text(
                  type.toUpperCase(),
                  style: FontUtils.caption(
                    context: context,
                    color: isSelected 
                        ? AppColors.onPrimary 
                        : AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOverviewStats() {
    if (_selectedPatient == null) {
      return _buildNoPatientSelected();
    }

    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedPatient!.name} - Overview',
                    style: FontUtils.title(
                      context: context,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightOnSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(_selectedPatient!.severity).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _selectedPatient!.severity.displayName,
                    style: FontUtils.caption(
                      context: context,
                      color: _getSeverityColor(_selectedPatient!.severity),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            if (isMobile) 
              Column(
                children: [
                  _buildStatCard('Avg Tremor Score', _selectedPatient!.averageTremorScore.toStringAsFixed(1), Icons.trending_up),
                  SizedBox(height: 12.h),
                  _buildStatCard('Medication Adherence', _selectedPatient!.medicationAdherencePercent, Icons.medication),
                  SizedBox(height: 12.h),
                  _buildStatCard('Last Reading', _selectedPatient!.formattedLastReading, Icons.access_time),
                  SizedBox(height: 12.h),
                  _buildStatCard('Sensor Status', _selectedPatient!.sensorStatus.displayName, Icons.sensors),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildStatCard('Avg Tremor Score', _selectedPatient!.averageTremorScore.toStringAsFixed(1), Icons.trending_up)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildStatCard('Medication Adherence', _selectedPatient!.medicationAdherencePercent, Icons.medication)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildStatCard('Last Reading', _selectedPatient!.formattedLastReading, Icons.access_time)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildStatCard('Sensor Status', _selectedPatient!.sensorStatus.displayName, Icons.sensors)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: IconUtils.getProtectedSize(
                  context,
                  targetSize: 20.0,
                  minSize: 18.0, // Never smaller than 18px
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: FontUtils.title(
              context: context,
              fontWeight: FontWeight.w700,
              color: AppColors.lightOnSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildNoPatientSelected() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_search,
                size: IconUtils.getProtectedSize(
                  context,
                  targetSize: 64.0,
                  minSize: 48.0, // Never smaller than 48px for large icons
                ),
                color: AppColors.lightOnSurfaceVariant,
              ),
              SizedBox(height: 16.h),
              Text(
                'Select a Patient',
                style: FontUtils.title(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose a patient from the selector above to view their health data and analytics',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataVisualizationSection(bool isMobile) {
    if (_selectedPatient == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedDataType.toUpperCase()} Data - ${_selectedTimeRange.toUpperCase()}',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 16.h),
            
            // Placeholder for chart with protected dimensions
            Container(
              height: IconUtils.getProtectedHeight(
                context,
                targetHeight: 300.0,
                minHeight: 250.0, // Never smaller than 250px for charts
              ),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.lightDivider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: IconUtils.getProtectedSize(
                      context,
                      targetSize: 48.0,
                      minSize: 36.0, // Never smaller than 36px for chart icons
                    ),
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Interactive Chart Coming Soon',
                    style: FontUtils.title(
                      context: context,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Displaying ${_selectedPatient!.name}\'s $_selectedDataType data for $_selectedTimeRange',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  Wrap(
                    spacing: 8.w,
                    children: [
                      _buildChartLegendItem('Normal', AppColors.success),
                      _buildChartLegendItem('Elevated', AppColors.warning),
                      _buildChartLegendItem('High', AppColors.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: FontUtils.caption(
            context: context,
            color: AppColors.lightOnSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAlertsSection() {
    if (_selectedPatient == null) {
      return const SizedBox.shrink();
    }

    // Demo alerts for the selected patient
    final alerts = [
      Alert(
        id: '1',
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        type: AlertType.highTremor,
        message: 'Tremor intensity above normal range detected',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        severity: AlertSeverity.warning,
        isRead: false,
      ),
      Alert(
        id: '2',
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        type: AlertType.medicationReminder,
        message: 'Medication dose reminder',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        severity: AlertSeverity.info,
        isRead: true,
      ),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Alerts',
                    style: FontUtils.title(
                      context: context,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${alerts.where((a) => !a.isRead).length} unread',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            ...alerts.map((alert) => _buildAlertCard(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: alert.isRead 
            ? AppColors.lightBackground 
            : _getAlertSeverityColor(alert.severity).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: alert.isRead 
              ? AppColors.lightDivider 
              : _getAlertSeverityColor(alert.severity).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getAlertTypeIcon(alert.type),
            color: _getAlertSeverityColor(alert.severity),
            size: 20.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: FontUtils.body(
                    context: context,
                    fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
                Text(
                  alert.formattedTimestamp,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!alert.isRead)
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: _getAlertSeverityColor(alert.severity),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getDataTypeIcon(String type) {
    switch (type) {
      case 'tremor':
        return Icons.trending_up;
      case 'medication':
        return Icons.medication;
      case 'activity':
        return Icons.directions_walk;
      case 'sleep':
        return Icons.bedtime;
      default:
        return Icons.analytics;
    }
  }

  Color _getSeverityColor(PatientSeverity severity) {
    switch (severity) {
      case PatientSeverity.mild:
        return AppColors.success;
      case PatientSeverity.moderate:
        return AppColors.warning;
      case PatientSeverity.severe:
        return AppColors.error;
    }
  }

  IconData _getAlertTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.highTremor:
        return Icons.warning;
      case AlertType.medicationReminder:
        return Icons.medication;
      case AlertType.sensorOffline:
        return Icons.sensors_off;
      case AlertType.lowBattery:
        return Icons.battery_alert;
    }
  }

  Color _getAlertSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return AppColors.info;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.critical:
        return AppColors.error;
    }
  }
}

/// Alert data model
class Alert {
  final String id;
  final String patientId;
  final String patientName;
  final AlertType type;
  final String message;
  final DateTime timestamp;
  final AlertSeverity severity;
  final bool isRead;

  const Alert({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.isRead,
  });

  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

enum AlertType {
  highTremor,
  medicationReminder,
  sensorOffline,
  lowBattery,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}
