import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedRole = 'all';
  String _selectedStatus = 'all';

  final List<_User> _users = [
    _User('1', 'Dr. Sarah Johnson', 'sarah.johnson@medusa.com', 'doctor', 'active', DateTime.now().subtract(const Duration(minutes: 5)), 'Cardiology'),
    _User('2', 'John Smith', 'john.smith@medusa.com', 'patient', 'active', DateTime.now().subtract(const Duration(hours: 2)), null),
    _User('3', 'Dr. Michael Brown', 'michael.brown@medusa.com', 'doctor', 'active', DateTime.now().subtract(const Duration(minutes: 15)), 'Neurology'),
    _User('4', 'Emily Davis', 'emily.davis@medusa.com', 'patient', 'inactive', DateTime.now().subtract(const Duration(days: 3)), null),
    _User('5', 'Admin User', 'admin@medusa.com', 'admin', 'active', DateTime.now().subtract(const Duration(minutes: 1)), null),
    _User('6', 'Dr. Lisa Wilson', 'lisa.wilson@medusa.com', 'doctor', 'pending', DateTime.now().subtract(const Duration(hours: 1)), 'Pediatrics'),
    _User('7', 'Robert Johnson', 'robert.johnson@medusa.com', 'patient', 'active', DateTime.now().subtract(const Duration(hours: 4)), null),
    _User('8', 'Dr. David Lee', 'david.lee@medusa.com', 'doctor', 'suspended', DateTime.now().subtract(const Duration(days: 1)), 'Orthopedics'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                _buildUsersList(),
                _buildUserAnalytics(),
                _buildUserPermissions(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        backgroundColor: AppColors.primary,
        icon: Icon(
          Icons.person_add_rounded,
          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        ),
        label: Text(
          'Add User',
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.people_rounded,
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
                  'User Management',
                  style: FontUtils.display(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Manage users, roles, and permissions across the system',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildUserStats(),
        ],
      ),
    );
  }

  Widget _buildUserStats() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u.status == 'active').length;
    final doctorsCount = _users.where((u) => u.role == 'doctor').length;
    final patientsCount = _users.where((u) => u.role == 'patient').length;

    return Row(
      children: [
        _buildStatChip('Total', totalUsers.toString(), AppColors.primary),
        SizedBox(width: 8.w),
        _buildStatChip('Active', activeUsers.toString(), AppColors.success),
        SizedBox(width: 8.w),
        _buildStatChip('Doctors', doctorsCount.toString(), AppColors.warning),
        SizedBox(width: 8.w),
        _buildStatChip('Patients', patientsCount.toString(), AppColors.error),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: FontUtils.label(
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
                hintText: 'Search users by name or email...',
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
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Roles')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
                DropdownMenuItem(value: 'patient', child: Text('Patients')),
                DropdownMenuItem(value: 'admin', child: Text('Administrators')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
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
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
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
              Icons.people_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Users List',
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
              Icons.security_rounded,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            text: 'Permissions',
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final filteredUsers = _users.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == 'all' || user.role == _selectedRole;
      final matchesStatus = _selectedStatus == 'all' || user.status == _selectedStatus;
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    return Container(
      color: AppColors.lightBackground,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(_User user) {
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
            child: Row(
              children: [
                _buildUserAvatar(user),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: FontUtils.body(
                          context: context,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightOnSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.department != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          user.department!,
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
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRoleBadge(user.role),
                    SizedBox(height: 4.h),
                    _buildStatusBadge(user.status),
                  ],
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last seen',
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatLastSeen(user.lastLogin),
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                _buildUserActions(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(_User user) {
    Color backgroundColor;
    IconData icon;

    switch (user.role) {
      case 'doctor':
        backgroundColor = AppColors.primary;
        icon = Icons.local_hospital_rounded;
        break;
      case 'patient':
        backgroundColor = AppColors.success;
        icon = Icons.person_rounded;
        break;
      case 'admin':
        backgroundColor = AppColors.error;
        icon = Icons.admin_panel_settings_rounded;
        break;
      default:
        backgroundColor = AppColors.lightOnSurfaceVariant;
        icon = Icons.person_outline_rounded;
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
        color: backgroundColor,
        shape: BoxShape.circle,
        border: user.status == 'active' 
            ? Border.all(color: AppColors.success, width: 2)
            : null,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: IconUtils.getAvatarSize(
          context,
          mobileSize: 24.0,
          desktopSize: 22.0,
          minSize: 20.0,
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String displayRole;

    switch (role) {
      case 'doctor':
        color = AppColors.primary;
        displayRole = 'Doctor';
        break;
      case 'patient':
        color = AppColors.success;
        displayRole = 'Patient';
        break;
      case 'admin':
        color = AppColors.error;
        displayRole = 'Admin';
        break;
      default:
        color = AppColors.lightOnSurfaceVariant;
        displayRole = 'Unknown';
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
      child: Text(
        displayRole,
        style: FontUtils.caption(
          context: context,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayStatus;

    switch (status) {
      case 'active':
        color = AppColors.success;
        displayStatus = 'Active';
        break;
      case 'inactive':
        color = AppColors.lightOnSurfaceVariant;
        displayStatus = 'Inactive';
        break;
      case 'pending':
        color = AppColors.warning;
        displayStatus = 'Pending';
        break;
      case 'suspended':
        color = AppColors.error;
        displayStatus = 'Suspended';
        break;
      default:
        color = AppColors.lightOnSurfaceVariant;
        displayStatus = 'Unknown';
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
      child: Text(
        displayStatus,
        style: FontUtils.caption(
          context: context,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserActions(_User user) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
      ),
      onSelected: (value) => _handleUserAction(user, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: ListTile(
            leading: Icon(Icons.visibility_rounded),
            title: Text('View Details'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_rounded),
            title: Text('Edit User'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: user.status == 'active' ? 'suspend' : 'activate',
          child: ListTile(
            leading: Icon(
              user.status == 'active' 
                  ? Icons.block_rounded 
                  : Icons.check_circle_rounded,
            ),
            title: Text(user.status == 'active' ? 'Suspend User' : 'Activate User'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'permissions',
          child: ListTile(
            leading: Icon(Icons.security_rounded),
            title: Text('Permissions'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_rounded, color: Colors.red),
            title: Text('Delete User', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    );
  }

  String _formatLastSeen(DateTime lastLogin) {
    final now = DateTime.now();
    final difference = now.difference(lastLogin);

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

  Widget _buildUserAnalytics() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildAnalyticsCard(
            'User Growth',
            'Monthly user registration trends',
            Icons.trending_up_rounded,
            AppColors.success,
            '+15% this month',
          ),
          SizedBox(height: 16.h),
          _buildAnalyticsCard(
            'Active Sessions',
            'Current active user sessions',
            Icons.people_rounded,
            AppColors.primary,
            '342 active now',
          ),
          SizedBox(height: 16.h),
          _buildAnalyticsCard(
            'User Engagement',
            'Average session duration and activity',
            Icons.access_time_rounded,
            AppColors.warning,
            '24.5 min avg',
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

  Widget _buildUserPermissions() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role-Based Permissions',
            style: FontUtils.headline(
              context: context,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView(
              children: [
                _buildPermissionCard(
                  'Doctor Permissions',
                  'Full access to patient data and medical records',
                  Icons.local_hospital_rounded,
                  AppColors.primary,
                  ['View Patient Data', 'Edit Medical Records', 'Prescribe Medication', 'Generate Reports'],
                ),
                SizedBox(height: 12.h),
                _buildPermissionCard(
                  'Patient Permissions',
                  'Access to personal health data and communication',
                  Icons.person_rounded,
                  AppColors.success,
                  ['View Own Data', 'Message Doctors', 'Update Profile', 'Schedule Appointments'],
                ),
                SizedBox(height: 12.h),
                _buildPermissionCard(
                  'Administrator Permissions',
                  'Full system access and management capabilities',
                  Icons.admin_panel_settings_rounded,
                  AppColors.error,
                  ['User Management', 'System Settings', 'Audit Logs', 'Security Controls', 'Backup Management'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(String title, String description, IconData icon, Color color, List<String> permissions) {
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
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: permissions.map((permission) => Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                permission,
                style: FontUtils.caption(
                  context: context,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  void _handleUserAction(_User user, String action) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'suspend':
      case 'activate':
        _toggleUserStatus(user);
        break;
      case 'permissions':
        _showPermissionsDialog(user);
        break;
      case 'delete':
        _showDeleteConfirmation(user);
        break;
    }
  }

  void _showUserDetails(_User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.name}'),
            Text('Email: ${user.email}'),
            Text('Role: ${user.role}'),
            Text('Status: ${user.status}'),
            if (user.department != null) Text('Department: ${user.department}'),
            Text('Last Login: ${user.lastLogin}'),
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

  void _showEditUserDialog(_User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit user: ${user.name}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _toggleUserStatus(_User user) {
    setState(() {
      user.status = user.status == 'active' ? 'suspended' : 'active';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} has been ${user.status}'),
        backgroundColor: user.status == 'active' ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _showPermissionsDialog(_User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Manage permissions for: ${user.name}'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _showDeleteConfirmation(_User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _users.remove(user);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.name} has been deleted'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create new user dialog would open here'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _User {
  final String id;
  final String name;
  final String email;
  final String role;
  String status;
  final DateTime lastLogin;
  final String? department;

  _User(this.id, this.name, this.email, this.role, this.status, this.lastLogin, this.department);
}
