import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

/// Device Management Page for Admin
/// Allows administrators to view and manage registered devices
class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  String _searchQuery = '';
  String _selectedStatus = 'all';

  // Mock data for devices
  final List<_Device> _devices = [
    _Device(
      id: 'dev_001',
      name: 'MeDUSA Sensor A1',
      type: 'Tremor Sensor',
      status: 'active',
      assignedTo: 'John Smith',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    _Device(
      id: 'dev_002',
      name: 'MeDUSA Sensor B2',
      type: 'Tremor Sensor',
      status: 'active',
      assignedTo: 'Emily Davis',
      lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    _Device(
      id: 'dev_003',
      name: 'MeDUSA Sensor C3',
      type: 'Tremor Sensor',
      status: 'offline',
      assignedTo: null,
      lastSeen: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _Device(
      id: 'dev_004',
      name: 'MeDUSA Sensor D4',
      type: 'Tremor Sensor',
      status: 'maintenance',
      assignedTo: 'Robert Johnson',
      lastSeen: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  List<_Device> get filteredDevices {
    return _devices.where((device) {
      final matchesSearch = device.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          device.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == 'all' || device.status == _selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltersAndSearch(),
          Expanded(child: _buildDevicesList()),
        ],
      ),
    );
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
                  '${_devices.length} registered devices',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusStats(),
        ],
      ),
    );
  }

  Widget _buildStatusStats() {
    final active = _devices.where((d) => d.status == 'active').length;
    final offline = _devices.where((d) => d.status == 'offline').length;
    final maintenance = _devices.where((d) => d.status == 'maintenance').length;

    return Row(
      children: [
        _buildStatChip('Active', active, AppColors.success),
        SizedBox(width: 8.w),
        _buildStatChip('Offline', offline, AppColors.error),
        SizedBox(width: 8.w),
        _buildStatChip('Maintenance', maintenance, AppColors.warning),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: FontUtils.caption(
              context: context,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            count.toString(),
            style: FontUtils.caption(
              context: context,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search devices...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.lightOutline),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SizedBox(width: 16.w),
          DropdownButton<String>(
            value: _selectedStatus,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'offline', child: Text('Offline')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    final devices = filteredDevices;

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'No devices found',
              style: FontUtils.title(context: context, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: devices.length,
      itemBuilder: (context, index) => _buildDeviceCard(devices[index]),
    );
  }

  Widget _buildDeviceCard(_Device device) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _getStatusColor(device.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.sensors,
            color: _getStatusColor(device.status),
          ),
        ),
        title: Text(
          device.name,
          style: FontUtils.body(
            context: context,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text('ID: ${device.id}'),
            SizedBox(height: 4.h),
            Row(
              children: [
                _buildStatusBadge(device.status),
                SizedBox(width: 8.w),
                Text(
                  device.assignedTo ?? 'Unassigned',
                  style: FontUtils.caption(
                    context: context,
                    color: device.assignedTo != null ? AppColors.lightOnSurface : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showDeviceActions(device),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: FontUtils.caption(
          context: context,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'offline':
        return AppColors.error;
      case 'maintenance':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  void _showDeviceActions(_Device device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Device: ${device.name}')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Assign to Patient'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Assign feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build, color: AppColors.warning),
              title: const Text('Mark for Maintenance'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maintenance feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Remove Device', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Remove feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Device {
  final String id;
  final String name;
  final String type;
  final String status;
  final String? assignedTo;
  final DateTime lastSeen;

  _Device({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.assignedTo,
    required this.lastSeen,
  });
}
