import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/unified_ble_manager.dart';
import '../../../../shared/services/ble_interface.dart';

/// Web Bluetooth Test Page
/// 
/// This page provides a dedicated interface for testing Web Bluetooth functionality.
/// It uses the UnifiedBleManager which automatically handles Web Bluetooth API calls.
class WebBluetoothTestPage extends StatefulWidget {
  const WebBluetoothTestPage({super.key});

  @override
  State<WebBluetoothTestPage> createState() => _WebBluetoothTestPageState();
}

class _WebBluetoothTestPageState extends State<WebBluetoothTestPage> {
  final UnifiedBleManager _bleManager = UnifiedBleManager();
  
  StreamSubscription? _statusSubscription;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _dataSubscription;
  
  List<UnifiedDevice> _discoveredDevices = [];
  final List<Map<String, dynamic>> _receivedData = [];
  String _status = 'Not initialized';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
    _initialize();
  }

  void _setupSubscriptions() {
    _statusSubscription = _bleManager.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });

    _devicesSubscription = _bleManager.devicesStream.listen((devices) {
      if (mounted) {
        setState(() => _discoveredDevices = devices);
      }
    });

    _dataSubscription = _bleManager.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _receivedData.insert(0, data);
          if (_receivedData.length > 50) {
            _receivedData.removeLast();
          }
        });
      }
    });
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    
    try {
      await _bleManager.initialize();
      setState(() => _status = _bleManager.status);
    } catch (e) {
      setState(() => _status = 'Initialization error: $e');
    }
    
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _devicesSubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Bluetooth Test'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Reinitialize',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          _buildPlatformInfo(),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor = AppColors.lightOnSurfaceVariant;
    IconData statusIcon = Icons.bluetooth;
    
    if (_bleManager.isConnected) {
      statusColor = AppColors.success;
      statusIcon = Icons.bluetooth_connected;
    } else if (_status.toLowerCase().contains('error')) {
      statusColor = AppColors.error;
      statusIcon = Icons.bluetooth_disabled;
    } else if (_status.toLowerCase().contains('scanning') || 
               _status.toLowerCase().contains('connecting')) {
      statusColor = AppColors.warning;
      statusIcon = Icons.bluetooth_searching;
    }

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32.w),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            SizedBox(
              width: 24.w,
              height: 24.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Row(
        children: [
          _buildInfoChip(
            'Platform',
            _bleManager.currentPlatform.name.toUpperCase(),
            Icons.devices,
          ),
          SizedBox(width: 12.w),
          _buildInfoChip(
            'Initialized',
            _bleManager.isInitialized ? 'Yes' : 'No',
            _bleManager.isInitialized ? Icons.check_circle : Icons.cancel,
            color: _bleManager.isInitialized ? AppColors.success : AppColors.error,
          ),
          if (kIsWeb) ...[
            SizedBox(width: 12.w),
            _buildInfoChip(
              'API Supported',
              _bleManager.isWebBluetoothSupported ? 'Yes' : 'No',
              _bleManager.isWebBluetoothSupported 
                  ? Icons.check_circle 
                  : Icons.warning,
              color: _bleManager.isWebBluetoothSupported 
                  ? AppColors.success 
                  : AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.w, color: color ?? AppColors.lightOnSurfaceVariant),
          SizedBox(width: 4.w),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: color ?? AppColors.lightOnSurface,
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

  Widget _buildMainContent() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.lightOnSurfaceVariant,
            tabs: const [
              Tab(text: 'Devices', icon: Icon(Icons.bluetooth)),
              Tab(text: 'Data', icon: Icon(Icons.data_usage)),
              Tab(text: 'Debug', icon: Icon(Icons.bug_report)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDevicesTab(),
                _buildDataTab(),
                _buildDebugTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              if (kIsWeb)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _bleManager.isConnected ? null : _requestDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Select Device'),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _bleManager.isScanning ? _stopScan : _startScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _bleManager.isScanning 
                          ? AppColors.warning 
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    icon: Icon(_bleManager.isScanning 
                        ? Icons.stop 
                        : Icons.bluetooth_searching),
                    label: Text(_bleManager.isScanning ? 'Stop Scan' : 'Start Scan'),
                  ),
                ),
              SizedBox(width: 8.w),
              if (_bleManager.isConnected)
                ElevatedButton.icon(
                  onPressed: _disconnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                  ),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
            ],
          ),
        ),
        if (kIsWeb)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20.w),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Web Bluetooth requires user interaction to select a device. '
                    'Click "Select Device" to open the browser\'s device picker.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _discoveredDevices.isEmpty
              ? _buildEmptyDevices()
              : _buildDevicesList(),
        ),
      ],
    );
  }

  Widget _buildEmptyDevices() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 64.w,
            color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              kIsWeb 
                  ? 'Click "Select Device" to find MeDUSA devices'
                  : 'No devices found. Start scanning to discover nearby devices.',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.lightOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final isConnected = _bleManager.connectedDevice?.id == device.id;

        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? AppColors.success : AppColors.primary,
            ),
            title: Text(
              device.name.isNotEmpty ? device.name : 'Unknown Device',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'ID: ${device.id}\nPlatform: ${device.platform.name}',
              style: TextStyle(fontSize: 12.sp),
            ),
            trailing: isConnected
                ? Chip(
                    label: const Text('Connected'),
                    backgroundColor: AppColors.success.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: AppColors.success,
                      fontSize: 12.sp,
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _connect(device),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDataTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Received Data (${_receivedData.length})',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _receivedData.clear()),
                tooltip: 'Clear data',
              ),
            ],
          ),
        ),
        if (_bleManager.isConnected)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendTestCommand,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test Command'),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _receivedData.isEmpty
              ? Center(
                  child: Text(
                    'No data received yet',
                    style: TextStyle(color: AppColors.lightOnSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _receivedData.length,
                  itemBuilder: (context, index) {
                    final data = _receivedData[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['timestamp'] ?? 'No timestamp',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: AppColors.lightOnSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              data.toString(),
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDebugTab() {
    final stats = _bleManager.getStatistics();
    
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BLE Manager Statistics',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                ...stats.entries.map((entry) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        if (kIsWeb)
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Web Bluetooth Notes',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildNote('Requires HTTPS or localhost'),
                  _buildNote('Only Chrome, Edge, Opera supported'),
                  _buildNote('User must click to trigger device selection'),
                  _buildNote('No background scanning capability'),
                  _buildNote('Safari and Firefox NOT supported'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16.w, color: AppColors.lightOnSurfaceVariant),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Actions
  Future<void> _requestDevice() async {
    setState(() => _isLoading = true);
    
    try {
      final device = await _bleManager.requestDevice();
      if (device != null) {
        debugPrint('Device selected: ${device.name}');
      }
    } catch (e) {
      debugPrint('Error requesting device: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _startScan() async {
    await _bleManager.startScan(timeout: const Duration(seconds: 30));
  }

  Future<void> _stopScan() async {
    await _bleManager.stopScan();
  }

  Future<void> _connect(UnifiedDevice device) async {
    setState(() => _isLoading = true);
    
    try {
      await _bleManager.connect(device);
    } catch (e) {
      debugPrint('Error connecting: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _disconnect() async {
    await _bleManager.disconnect();
  }

  Future<void> _sendTestCommand() async {
    await _bleManager.sendCommand('test', {'timestamp': DateTime.now().toIso8601String()});
  }
}
