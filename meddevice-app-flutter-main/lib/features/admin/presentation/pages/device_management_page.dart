import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/bluetooth_service.dart' show MedicalBluetoothService;

class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final MedicalBluetoothService _bluetoothService = MedicalBluetoothService();
  String _searchQuery = '';
  String _selectedType = 'all';
  String _selectedStatus = 'all';

  final List<_Device> _devices = [
    _Device('D001', 'NeuroMotion Sensor v2.1', 'sensor', 'online', 'P001', 'John Smith', 98.5, DateTime.now().subtract(const Duration(minutes: 2)), '192.168.1.101', '2.1.4'),
    _Device('D002', 'Parkinson Monitor Pro', 'monitor', 'online', 'P002', 'Emily Davis', 95.2, DateTime.now().subtract(const Duration(minutes: 5)), '192.168.1.102', '3.0.1'),
    _Device('D003', 'Motion Tracker X1', 'tracker', 'offline', 'P003', 'Robert Johnson', 87.3, DateTime.now().subtract(const Duration(hours: 2)), '192.168.1.103', '1.8.2'),
    _Device('D004', 'Smart Health Band', 'wearable', 'online', 'P004', 'Sarah Wilson', 92.1, DateTime.now().subtract(const Duration(minutes: 1)), '192.168.1.104', '4.2.0'),
    _Device('D005', 'Neural Activity Sensor', 'sensor', 'maintenance', null, null, 78.9, DateTime.now().subtract(const Duration(days: 1)), '192.168.1.105', '2.0.8'),
    _Device('D006', 'Gait Analysis Device', 'analyzer', 'online', 'P005', 'Michael Brown', 96.8, DateTime.now().subtract(const Duration(minutes: 3)), '192.168.1.106', '1.5.3'),
    _Device('D007', 'Tremor Detection Unit', 'detector', 'error', 'P006', 'Lisa Anderson', 45.2, DateTime.now().subtract(const Duration(hours: 6)), '192.168.1.107', '2.3.1'),
    _Device('D008', 'Mobility Sensor Array', 'sensor', 'online', 'P007', 'David Wilson', 99.1, DateTime.now().subtract(const Duration(seconds: 30)), '192.168.1.108', '3.1.0'),
  ];

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
          _buildFiltersAndSearch(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDevicesList(),
                _buildDeviceAnalytics(),
                _buildNetworkTopology(),
                _buildMaintenanceSchedule(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        backgroundColor: AppColors.success,
        icon: Icon(
          Icons.add_rounded,
          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        ),
        label: Text(
          'Add Device',
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
    final totalDevices = _devices.length;
    final onlineDevices = _devices.where((d) => d.status == 'online').length;
    final offlineDevices = _devices.where((d) => d.status == 'offline').length;
    final errorDevices = _devices.where((d) => d.status == 'error').length;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withValues(alpha: 0.1),
            AppColors.success.withValues(alpha: 0.05),
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
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.devices_rounded,
                  color: AppColors.success,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Management',
                      style: FontUtils.display(
                        context: context,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Monitor and manage all connected medical devices',
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
                child: _buildStatusCard('Total Devices', totalDevices.toString(), Icons.devices_rounded, AppColors.primary),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusCard('Online', onlineDevices.toString(), Icons.check_circle_rounded, AppColors.success),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusCard('Offline', offlineDevices.toString(), Icons.offline_bolt_rounded, AppColors.lightOnSurfaceVariant),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildStatusCard('Errors', errorDevices.toString(), Icons.error_rounded, AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
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

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: AppColors.lightBackground,
      child: ResponsiveRowColumn(
        layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
            ? ResponsiveRowColumnType.COLUMN 
            : ResponsiveRowColumnType.ROW,
        rowSpacing: 12.w,
        columnSpacing: 12.h,
        children: [
          ResponsiveRowColumnItem(
            rowFlex: 2,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search devices by name or ID...',
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
          ),
          ResponsiveRowColumnItem(
            rowFlex: 1,
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Device Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Types')),
                DropdownMenuItem(value: 'sensor', child: Text('Sensors')),
                DropdownMenuItem(value: 'monitor', child: Text('Monitors')),
                DropdownMenuItem(value: 'tracker', child: Text('Trackers')),
                DropdownMenuItem(value: 'wearable', child: Text('Wearables')),
                DropdownMenuItem(value: 'analyzer', child: Text('Analyzers')),
                DropdownMenuItem(value: 'detector', child: Text('Detectors')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ),
          ResponsiveRowColumnItem(
            rowFlex: 1,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
                DropdownMenuItem(value: 'offline', child: Text('Offline')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'error', child: Text('Error')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
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
        labelColor: AppColors.success,
        unselectedLabelColor: AppColors.lightOnSurfaceVariant,
        indicatorColor: AppColors.success,
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
              Icons.list_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Devices',
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
              Icons.hub_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Network',
          ),
          Tab(
            icon: Icon(
              Icons.build_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Maintenance',
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    final filteredDevices = _devices.where((device) {
      final matchesSearch = device.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          device.deviceId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == 'all' || device.type == _selectedType;
      final matchesStatus = _selectedStatus == 'all' || device.status == _selectedStatus;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    return Container(
      color: AppColors.lightBackground,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: filteredDevices.length + 1, // +1 for Bluetooth connection card
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildBluetoothConnectionCard();
          }
          final device = filteredDevices[index - 1];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(_Device device) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ResponsiveRowColumn(
        layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
            ? ResponsiveRowColumnType.COLUMN 
            : ResponsiveRowColumnType.ROW,
        rowCrossAxisAlignment: CrossAxisAlignment.center,
        columnCrossAxisAlignment: CrossAxisAlignment.start,
        rowSpacing: 16.w,
        columnSpacing: 12.h,
        children: [
          ResponsiveRowColumnItem(
            rowFlex: 2,
            child: Row(
              children: [
                _buildDeviceIcon(device),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: FontUtils.body(
                          context: context,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightOnSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${device.deviceId}',
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                      if (device.patientName != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          'Patient: ${device.patientName}',
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          ResponsiveRowColumnItem(
            rowFlex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildTypeBadge(device.type),
                    SizedBox(width: 8.w),
                    _buildStatusBadge(device.status),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildHealthScore(device.healthScore),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'v${device.firmwareVersion}',
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    _buildDeviceActions(device),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon(_Device device) {
    IconData icon;
    Color color;

    switch (device.type) {
      case 'sensor':
        icon = Icons.sensors_rounded;
        color = AppColors.primary;
        break;
      case 'monitor':
        icon = Icons.monitor_heart_rounded;
        color = AppColors.error;
        break;
      case 'tracker':
        icon = Icons.track_changes_rounded;
        color = AppColors.warning;
        break;
      case 'wearable':
        icon = Icons.watch_rounded;
        color = AppColors.success;
        break;
      case 'analyzer':
        icon = Icons.analytics_rounded;
        color = AppColors.primary;
        break;
      case 'detector':
        icon = Icons.radar_rounded;
        color = AppColors.error;
        break;
      default:
        icon = Icons.device_unknown_rounded;
        color = AppColors.lightOnSurfaceVariant;
    }

    return Container(
      width: IconUtils.getAvatarSize(
        context,
        mobileSize: 48.0,
        desktopSize: 44.0,
        minSize: 40.0,
      ),
      height: IconUtils.getAvatarSize(
        context,
        mobileSize: 48.0,
        desktopSize: 44.0,
        minSize: 40.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: device.status == 'online' 
            ? Border.all(color: AppColors.success, width: 2)
            : device.status == 'error'
                ? Border.all(color: AppColors.error, width: 2)
                : null,
      ),
      child: Icon(
        icon,
        color: color,
        size: IconUtils.getAvatarSize(
          context,
          mobileSize: 24.0,
          desktopSize: 22.0,
          minSize: 20.0,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        type.toUpperCase(),
        style: FontUtils.caption(
          context: context,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'online':
        color = AppColors.success;
        icon = Icons.circle;
        break;
      case 'offline':
        color = AppColors.lightOnSurfaceVariant;
        icon = Icons.circle;
        break;
      case 'maintenance':
        color = AppColors.warning;
        icon = Icons.build_circle;
        break;
      case 'error':
        color = AppColors.error;
        icon = Icons.error;
        break;
      default:
        color = AppColors.lightOnSurfaceVariant;
        icon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 4.w),
          Text(
            status.toUpperCase(),
            style: FontUtils.caption(
              context: context,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScore(double score) {
    Color color;
    if (score >= 90) {
      color = AppColors.success;
    } else if (score >= 70) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: color,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 4.w),
          Text(
            '${score.toStringAsFixed(1)}%',
            style: FontUtils.caption(
              context: context,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceActions(_Device device) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
      ),
      onSelected: (value) => _handleDeviceAction(device, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'details',
          child: ListTile(
            leading: Icon(Icons.info_rounded),
            title: Text('Device Details'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'configure',
          child: ListTile(
            leading: Icon(Icons.settings_rounded),
            title: Text('Configure'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'diagnostics',
          child: ListTile(
            leading: Icon(Icons.bug_report_rounded),
            title: Text('Run Diagnostics'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: device.status == 'online' ? 'shutdown' : 'restart',
          child: ListTile(
            leading: Icon(
              device.status == 'online' 
                  ? Icons.power_off_rounded 
                  : Icons.restart_alt_rounded,
            ),
            title: Text(device.status == 'online' ? 'Shutdown' : 'Restart'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: Icon(Icons.delete_rounded, color: Colors.red),
            title: Text('Remove Device', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceAnalytics() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildAnalyticsCard(
            'Device Performance',
            'Overall system performance metrics',
            Icons.speed_rounded,
            AppColors.success,
            '94.2% avg',
          ),
          SizedBox(height: 16.h),
          _buildAnalyticsCard(
            'Data Throughput',
            'Real-time data processing rates',
            Icons.swap_vert_rounded,
            AppColors.primary,
            '2.4 MB/s',
          ),
          SizedBox(height: 16.h),
          _buildAnalyticsCard(
            'Error Rate',
            'System-wide error occurrence',
            Icons.error_outline_rounded,
            AppColors.error,
            '0.8% rate',
          ),
          SizedBox(height: 16.h),
          _buildAnalyticsCard(
            'Maintenance Alerts',
            'Scheduled and emergency maintenance',
            Icons.build_rounded,
            AppColors.warning,
            '3 pending',
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String description, IconData icon, Color color, String metric) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
              size: IconUtils.getProtectedSize(
                context,
                targetSize: 24.0,
                minSize: 20.0,
              ),
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              metric,
              style: FontUtils.label(
                context: context,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkTopology() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Network Topology',
            style: FontUtils.headline(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.hub_rounded,
                    size: IconUtils.getProtectedSize(
                      context,
                      targetSize: 64.0,
                      minSize: 48.0,
                    ),
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Network Visualization',
                    style: FontUtils.title(
                      context: context,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Interactive network topology view showing device connections, data flows, and network health.',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  _buildNetworkStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStats() {
    return ResponsiveRowColumn(
      layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
          ? ResponsiveRowColumnType.COLUMN 
          : ResponsiveRowColumnType.ROW,
      rowSpacing: 16.w,
      columnSpacing: 12.h,
      children: [
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildNetworkStatItem('Bandwidth', '125 Mbps', Icons.speed_rounded, AppColors.success),
        ),
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildNetworkStatItem('Latency', '12ms', Icons.access_time_rounded, AppColors.warning),
        ),
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildNetworkStatItem('Packet Loss', '0.02%', Icons.network_check_rounded, AppColors.success),
        ),
      ],
    );
  }

  Widget _buildNetworkStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
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

  Widget _buildMaintenanceSchedule() {
    final maintenanceItems = [
      _MaintenanceItem('D003', 'Motion Tracker X1', 'Firmware Update', DateTime.now().add(const Duration(days: 2)), 'high'),
      _MaintenanceItem('D005', 'Neural Activity Sensor', 'Calibration Required', DateTime.now().add(const Duration(days: 5)), 'medium'),
      _MaintenanceItem('D007', 'Tremor Detection Unit', 'Hardware Inspection', DateTime.now().add(const Duration(days: 1)), 'high'),
      _MaintenanceItem('D002', 'Parkinson Monitor Pro', 'Routine Maintenance', DateTime.now().add(const Duration(days: 7)), 'low'),
    ];

    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maintenance Schedule',
            style: FontUtils.headline(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: maintenanceItems.length,
              itemBuilder: (context, index) {
                final item = maintenanceItems[index];
                return _buildMaintenanceItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(_MaintenanceItem item) {
    Color priorityColor;
    switch (item.priority) {
      case 'high':
        priorityColor = AppColors.error;
        break;
      case 'medium':
        priorityColor = AppColors.warning;
        break;
      case 'low':
        priorityColor = AppColors.success;
        break;
      default:
        priorityColor = AppColors.lightOnSurfaceVariant;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: priorityColor.withValues(alpha: 0.2),
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
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.deviceName,
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID: ${item.deviceId}',
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  item.task,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  item.priority.toUpperCase(),
                  style: FontUtils.caption(
                    context: context,
                    color: priorityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _formatScheduledDate(item.scheduledDate),
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatScheduledDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else {
      return 'In ${difference.inDays} days';
    }
  }

  void _handleDeviceAction(_Device device, String action) {
    switch (action) {
      case 'details':
        _showDeviceDetails(device);
        break;
      case 'configure':
        _showConfigureDialog(device);
        break;
      case 'diagnostics':
        _runDiagnostics(device);
        break;
      case 'shutdown':
      case 'restart':
        _toggleDevicePower(device, action);
        break;
      case 'remove':
        _showRemoveConfirmation(device);
        break;
    }
  }

  void _showDeviceDetails(_Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${device.name}'),
            Text('ID: ${device.deviceId}'),
            Text('Type: ${device.type}'),
            Text('Status: ${device.status}'),
            Text('Health Score: ${device.healthScore}%'),
            Text('IP Address: ${device.ipAddress}'),
            Text('Firmware: ${device.firmwareVersion}'),
            if (device.patientName != null) Text('Patient: ${device.patientName}'),
            Text('Last Update: ${device.lastUpdate}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConfigureDialog(_Device device) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configure device: ${device.name}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _runDiagnostics(_Device device) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Running diagnostics for: ${device.name}'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _toggleDevicePower(_Device device, String action) {
    setState(() {
      device.status = action == 'shutdown' ? 'offline' : 'online';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${device.name} has been ${action}ed'),
        backgroundColor: action == 'shutdown' ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _showRemoveConfirmation(_Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Are you sure you want to remove ${device.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _devices.remove(device);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${device.name} has been removed'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothConnectionCard() {
    final isConnected = _bluetoothService.isConnected;
    final connectedDevice = _bluetoothService.connectedDevice;
    final connectionStatus = _bluetoothService.connectionStatus;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isConnected 
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.lightOnSurfaceVariant.withValues(alpha: 0.05),
            isConnected 
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.lightOnSurfaceVariant.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isConnected 
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.lightDivider,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: (isConnected ? AppColors.success : AppColors.lightOnSurfaceVariant)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  isConnected 
                      ? Icons.bluetooth_connected_rounded 
                      : Icons.bluetooth_disabled_rounded,
                  color: isConnected ? AppColors.success : AppColors.lightOnSurfaceVariant,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Live Bluetooth Connection',
                          style: FontUtils.body(
                            context: context,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightOnSurface,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'REAL-TIME',
                            style: FontUtils.caption(
                              context: context,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      connectionStatus,
                      style: FontUtils.caption(
                        context: context,
                        color: isConnected ? AppColors.success : AppColors.lightOnSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 12.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.success : AppColors.lightOnSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (isConnected && connectedDevice != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.memory_rounded,
                        color: AppColors.success,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Device: ${connectedDevice.platformName.isNotEmpty ? connectedDevice.platformName : 'Unknown Device'}',
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.lightOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.success,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'ID: ${connectedDevice.remoteId.toString()}',
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.lightOnSurfaceVariant,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'No active Bluetooth connection from patients',
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddDeviceDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add new device dialog would open here'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class _Device {
  final String deviceId;
  final String name;
  final String type;
  String status;
  final String? patientId;
  final String? patientName;
  final double healthScore;
  final DateTime lastUpdate;
  final String ipAddress;
  final String firmwareVersion;

  _Device(this.deviceId, this.name, this.type, this.status, this.patientId, 
          this.patientName, this.healthScore, this.lastUpdate, this.ipAddress, this.firmwareVersion);
}

class _MaintenanceItem {
  final String deviceId;
  final String deviceName;
  final String task;
  final DateTime scheduledDate;
  final String priority;

  _MaintenanceItem(this.deviceId, this.deviceName, this.task, this.scheduledDate, this.priority);
}
