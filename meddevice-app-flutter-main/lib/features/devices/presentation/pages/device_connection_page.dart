import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/bluetooth_service.dart' show MedicalBluetoothService;

class DeviceConnectionPage extends StatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  State<DeviceConnectionPage> createState() => _DeviceConnectionPageState();
}

class _DeviceConnectionPageState extends State<DeviceConnectionPage> with TickerProviderStateMixin {
  final MedicalBluetoothService _bluetoothService = MedicalBluetoothService();
  late TabController _tabController;
  
  StreamSubscription? _dataSubscription;
  StreamSubscription? _statusSubscription;
  
  final List<Map<String, dynamic>> _recentData = [];
  String _connectionStatus = 'Checking connection...';
  bool _isCollecting = false;
  Map<String, dynamic>? _deviceInfo;

  // Data collection statistics
  int _totalDataPoints = 0;
  double _averageHeartRate = 0.0;
  double _averageTemperature = 0.0;
  String _lastDataTime = 'Never';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupSubscriptions();
    _checkConnection();
  }

  void _setupSubscriptions() {
    _dataSubscription = _bluetoothService.dataStream.listen((data) {
      setState(() {
        _recentData.insert(0, data);
        if (_recentData.length > 50) {
          _recentData.removeLast();
        }
        _updateStatistics();
      });
    });

    _statusSubscription = _bluetoothService.statusStream.listen((status) {
      setState(() {
        _connectionStatus = status;
      });
    });
  }

  void _checkConnection() {
    if (!_bluetoothService.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotConnectedDialog();
      });
    } else {
      _requestDeviceInfo();
    }
  }

  void _updateStatistics() {
    if (_recentData.isEmpty) return;

    _totalDataPoints = _recentData.length;
    
    // Calculate averages for heart rate and temperature
    double totalHeartRate = 0;
    double totalTemperature = 0;
    int heartRateCount = 0;
    int temperatureCount = 0;

    for (var data in _recentData) {
      if (data['heartRate'] != null) {
        totalHeartRate += (data['heartRate'] as num).toDouble();
        heartRateCount++;
      }
      if (data['temperature'] != null) {
        totalTemperature += (data['temperature'] as num).toDouble();
        temperatureCount++;
      }
    }

    _averageHeartRate = heartRateCount > 0 ? totalHeartRate / heartRateCount : 0;
    _averageTemperature = temperatureCount > 0 ? totalTemperature / temperatureCount : 0;
    
    if (_recentData.isNotEmpty) {
      _lastDataTime = _recentData.first['timestamp'] ?? 'Unknown';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataSubscription?.cancel();
    _statusSubscription?.cancel();
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
                _buildDashboardTab(),
                _buildDataTab(),
                _buildControlTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final device = _bluetoothService.connectedDevice;
    final isConnected = _bluetoothService.isConnected;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isConnected 
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            isConnected 
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.error.withValues(alpha: 0.05),
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
              color: (isConnected ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              isConnected 
                  ? Icons.bluetooth_connected_rounded 
                  : Icons.bluetooth_disabled_rounded,
              color: isConnected ? AppColors.success : AppColors.error,
              size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device?.platformName ?? 'Device Dashboard',
                  style: FontUtils.display(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _connectionStatus,
                  style: FontUtils.body(
                    context: context,
                    color: isConnected 
                        ? AppColors.success 
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: (isConnected ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: (isConnected ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.3),
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
                    color: isConnected ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: FontUtils.label(
                    context: context,
                    color: isConnected ? AppColors.success : AppColors.error,
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
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightOnSurfaceVariant,
        indicatorColor: AppColors.primary,
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
              Icons.dashboard_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Dashboard',
          ),
          Tab(
            icon: Icon(
              Icons.show_chart_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Data',
          ),
          Tab(
            icon: Icon(
              Icons.control_camera_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Control',
          ),
          Tab(
            icon: Icon(
              Icons.settings_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatisticsCards(),
            SizedBox(height: 24.h),
            _buildRecentDataCard(),
            SizedBox(height: 24.h),
            _buildDeviceInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return ResponsiveRowColumn(
      layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
          ? ResponsiveRowColumnType.COLUMN 
          : ResponsiveRowColumnType.ROW,
      rowSpacing: 16.w,
      columnSpacing: 16.h,
      children: [
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildStatCard(
            'Data Points',
            _totalDataPoints.toString(),
            Icons.data_usage_rounded,
            AppColors.primary,
          ),
        ),
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildStatCard(
            'Avg Heart Rate',
            '${_averageHeartRate.toStringAsFixed(1)} bpm',
            Icons.favorite_rounded,
            AppColors.error,
          ),
        ),
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildStatCard(
            'Avg Temperature',
            '${_averageTemperature.toStringAsFixed(1)} C',
            Icons.thermostat_rounded,
            AppColors.warning,
          ),
        ),
        ResponsiveRowColumnItem(
          rowFlex: 1,
          child: _buildStatCard(
            'Collection Status',
            _isCollecting ? 'Active' : 'Stopped',
            _isCollecting ? Icons.play_circle_rounded : Icons.pause_circle_rounded,
            _isCollecting ? AppColors.success : AppColors.lightOnSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
      child: Column(
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
                targetSize: 24.0,
                minSize: 20.0,
              ),
            ),
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
          Text(
            title,
            style: FontUtils.caption(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDataCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Recent Data',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Last: $_lastDataTime',
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_recentData.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  children: [
                    Icon(
                      Icons.data_usage_rounded,
                      size: IconUtils.getProtectedSize(
                        context,
                        targetSize: 48.0,
                        minSize: 36.0,
                      ),
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No data received yet',
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200.h,
              child: ListView.builder(
                itemCount: _recentData.take(10).length,
                itemBuilder: (context, index) {
                  final data = _recentData[index];
                  return _buildDataItem(data);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataItem(Map<String, dynamic> data) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sensors_rounded,
            color: AppColors.primary,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HR: ${data['heartRate'] ?? 'N/A'} | Temp: ${data['temperature'] ?? 'N/A'} C',
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  data['timestamp'] ?? 'Unknown time',
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

  Widget _buildDeviceInfoCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Device Information',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_deviceInfo != null) ...[
            _buildInfoRow('Device ID', _deviceInfo!['deviceId'] ?? 'Unknown'),
            _buildInfoRow('Firmware Version', _deviceInfo!['firmware'] ?? 'Unknown'),
            _buildInfoRow('Battery Level', '${_deviceInfo!['battery'] ?? 'Unknown'}%'),
            _buildInfoRow('Uptime', _deviceInfo!['uptime'] ?? 'Unknown'),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Loading device information...',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Visualization',
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: IconUtils.getProtectedSize(
                      context,
                      targetSize: 64.0,
                      minSize: 48.0,
                    ),
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Real-time Data Charts',
                    style: FontUtils.title(
                      context: context,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Interactive charts showing heart rate, temperature, and movement data will be displayed here.',
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
        ],
      ),
    );
  }

  Widget _buildControlTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Control',
            style: FontUtils.headline(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 16.w,
            columnSpacing: 16.h,
            children: [
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildControlCard(
                  'Data Collection',
                  _isCollecting ? 'Stop collecting sensor data' : 'Start collecting sensor data',
                  _isCollecting ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  _isCollecting ? AppColors.error : AppColors.success,
                  () => _toggleDataCollection(),
                ),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: _buildControlCard(
                  'Device Info',
                  'Request current device information',
                  Icons.info_rounded,
                  AppColors.primary,
                  () => _requestDeviceInfo(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(String title, String description, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
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
      child: Column(
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
                targetSize: 32.0,
                minSize: 24.0,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            description,
            style: FontUtils.caption(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text(
              _isCollecting && title == 'Data Collection' ? 'Stop' : 'Execute',
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

  Widget _buildSettingsTab() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Settings',
            style: FontUtils.headline(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
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
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.bluetooth_disabled_rounded,
                    color: AppColors.error,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  title: Text(
                    'Disconnect Device',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Disconnect from the current device',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                  ),
                  onTap: _disconnect,
                ),
                Divider(height: 1.h),
                ListTile(
                  leading: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primary,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  title: Text(
                    'Reconnect',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Attempt to reconnect to the device',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                  ),
                  onTap: _reconnect,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotConnectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Device Not Connected'),
        content: const Text('You need to connect to a device first. Would you like to go to the device scanner?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous page
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/device-scan');
            },
            child: const Text('Scan Devices'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDataCollection() async {
    if (_isCollecting) {
      await _bluetoothService.stopDataCollection();
    } else {
      await _bluetoothService.startDataCollection();
    }
    setState(() {
      _isCollecting = !_isCollecting;
    });
  }

  Future<void> _requestDeviceInfo() async {
    await _bluetoothService.getDeviceInfo();
    // Device info will be received through the data stream
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reconnect() async {
    final device = _bluetoothService.connectedDevice;
    if (device != null) {
      await _bluetoothService.connectToDevice(device);
    }
  }
}
