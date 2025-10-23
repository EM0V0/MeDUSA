import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/bluetooth_service.dart' show MedicalBluetoothService;

class DeviceScanPage extends StatefulWidget {
  const DeviceScanPage({super.key});

  @override
  State<DeviceScanPage> createState() => _DeviceScanPageState();
}

class _DeviceScanPageState extends State<DeviceScanPage> with TickerProviderStateMixin {
  final MedicalBluetoothService _bluetoothService = MedicalBluetoothService();
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;
  
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;
  
  List<BluetoothDevice> _discoveredDevices = [];
  String _statusMessage = 'Ready to scan';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeBluetooth();
    _setupSubscriptions();
  }

  void _initializeAnimations() {
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeBluetooth() async {
    final initialized = await _bluetoothService.initialize();
    setState(() {
      _isInitialized = initialized;
      if (!initialized) {
        _statusMessage = _bluetoothService.lastError ?? 'Failed to initialize Bluetooth';
      }
    });
  }

  void _setupSubscriptions() {
    _devicesSubscription = _bluetoothService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
        });
      }
    });

    _statusSubscription = _bluetoothService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isInitialized ? _buildContent() : _buildInitializationError(),
          ),
        ],
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
                  Icons.bluetooth_searching_rounded,
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
                      'Device Scanner',
                      style: FontUtils.display(
                        context: context,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Find and connect to your Raspberry Pi medical device',
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
          SizedBox(height: 16.h),
          _buildStatusCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isScanning = _bluetoothService.isScanning;
    final isConnected = _bluetoothService.isConnected;
    
    Color statusColor;
    IconData statusIcon;
    
    if (isConnected) {
      statusColor = AppColors.success;
      statusIcon = Icons.bluetooth_connected_rounded;
    } else if (isScanning) {
      statusColor = AppColors.primary;
      statusIcon = Icons.bluetooth_searching_rounded;
    } else {
      statusColor = AppColors.lightOnSurfaceVariant;
      statusIcon = Icons.bluetooth_rounded;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (isScanning)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _scanAnimation.value * 2 * 3.14159,
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                );
              },
            )
          else
            Icon(
              statusIcon,
              color: statusColor,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected 
                      ? 'Connected to ${_bluetoothService.connectedDevice?.platformName}' 
                      : _statusMessage,
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_discoveredDevices.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '${_discoveredDevices.length} device${_discoveredDevices.length == 1 ? '' : 's'} found',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isScanning && !isConnected)
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: Icon(
                Icons.search_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
              ),
              label: Text(
                'Scan',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
            )
          else if (isScanning)
            ElevatedButton.icon(
              onPressed: _stopScan,
              icon: Icon(
                Icons.stop_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
              ),
              label: Text(
                'Stop',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_bluetoothService.isConnected) {
      return _buildConnectedView();
    } else if (_discoveredDevices.isEmpty && !_bluetoothService.isScanning) {
      return _buildEmptyState();
    } else {
      return _buildDevicesList();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: const BoxDecoration(
                color: AppColors.lightBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_searching_rounded,
                size: IconUtils.getProtectedSize(
                  context,
                  targetSize: 64.0,
                  minSize: 48.0,
                ),
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Devices Found',
              style: FontUtils.title(
                context: context,
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Make sure your Raspberry Pi device is powered on and in pairing mode.',
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: Icon(
                Icons.refresh_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              label: Text(
                'Start Scanning',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Devices',
            style: FontUtils.headline(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                return _buildDeviceCard(device);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';
    
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
            rowFlex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    color: AppColors.primary,
                    size: IconUtils.getAvatarSize(
                      context,
                      mobileSize: 24.0,
                      desktopSize: 20.0,
                      minSize: 18.0,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        deviceName,
                        style: FontUtils.body(
                          context: context,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightOnSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        device.remoteId.toString(),
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          'Medical Device',
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ResponsiveRowColumnItem(
            child: ResponsiveRowColumn(
              layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET)
                  ? ResponsiveRowColumnType.COLUMN
                  : ResponsiveRowColumnType.ROW,
              rowMainAxisAlignment: MainAxisAlignment.end,
              rowSpacing: 8.w,
              columnSpacing: 8.h,
              children: [
                ResponsiveRowColumnItem(
                  child: ElevatedButton.icon(
                    onPressed: () => _connectToDevice(device),
                    icon: Icon(
                      Icons.link_rounded,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                    ),
                    label: Text(
                      'Connect',
                      style: FontUtils.body(
                        context: context,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    ),
                  ),
                ),
                ResponsiveRowColumnItem(
                  child: ElevatedButton.icon(
                    onPressed: () => _setupWiFi(device),
                    icon: Icon(
                      Icons.wifi_rounded,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                    ),
                    label: Text(
                      'WiFi Setup',
                      style: FontUtils.body(
                        context: context,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView() {
    final device = _bluetoothService.connectedDevice;
    if (device == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.bluetooth_connected_rounded,
                  size: IconUtils.getProtectedSize(
                    context,
                    targetSize: 64.0,
                    minSize: 48.0,
                  ),
                  color: AppColors.success,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Connected Successfully!',
                  style: FontUtils.title(
                    context: context,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  device.platformName.isNotEmpty 
                      ? device.platformName 
                      : 'Medical Device',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  device.remoteId.toString(),
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 16.w,
            columnSpacing: 16.h,
            children: [
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/device-connection');
                  },
                  icon: Icon(
                    Icons.dashboard_rounded,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  label: Text(
                    'Device Dashboard',
                    style: FontUtils.body(
                      context: context,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  ),
                ),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: Icon(
                    Icons.bluetooth_disabled_rounded,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  label: Text(
                    'Disconnect',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitializationError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: IconUtils.getProtectedSize(
                context,
                targetSize: 64.0,
                minSize: 48.0,
              ),
              color: AppColors.error,
            ),
            SizedBox(height: 24.h),
            Text(
              'Bluetooth Unavailable',
              style: FontUtils.title(
                context: context,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _statusMessage,
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: _initializeBluetooth,
              icon: Icon(
                Icons.refresh_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              label: Text(
                'Retry',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    _scanAnimationController.repeat();
    await _bluetoothService.startScan();
  }

  Future<void> _stopScan() async {
    _scanAnimationController.stop();
    await _bluetoothService.stopScan();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _scanAnimationController.stop();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: 16.h),
            Text(
              'Connecting to ${device.platformName}...',
              style: FontUtils.body(context: context),
            ),
          ],
        ),
      ),
    );

    final success = await _bluetoothService.connectToDevice(device);
    
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_bluetoothService.lastError ?? 'Connection failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
  }

  /// Navigate to WiFi provisioning page with the selected device
  /// This avoids redundant scanning - the device is already discovered
  void _setupWiFi(BluetoothDevice device) {
    _scanAnimationController.stop();
    
    // Navigate to WiFi provision page, passing the device
    context.go('/wifi-provision', extra: device);
  }
}
