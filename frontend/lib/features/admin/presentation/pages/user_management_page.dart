import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../core/auth/role_permissions.dart';

/// Simplified User Management Page
/// Displays user list with basic filtering by role
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _searchQuery = '';
  String _selectedRole = 'all';

  // Mock data - matching backend roles: patient, doctor, admin
  final List<_User> _users = [
    _User(
      id: '1',
      name: 'Dr. Sarah Johnson',
      email: 'sarah@medusa.com',
      role: 'doctor',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    _User(
      id: '2',
      name: 'John Smith',
      email: 'john@medusa.com',
      role: 'patient',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    _User(
      id: '3',
      name: 'Dr. Michael Brown',
      email: 'michael@medusa.com',
      role: 'doctor',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    _User(
      id: '4',
      name: 'Emily Davis',
      email: 'emily@medusa.com',
      role: 'patient',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    _User(
      id: '5',
      name: 'Admin User',
      email: 'admin@medusa.com',
      role: 'admin',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    _User(
      id: '6',
      name: 'Dr. Lisa Wilson',
      email: 'lisa@medusa.com',
      role: 'doctor',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    _User(
      id: '7',
      name: 'Robert Johnson',
      email: 'robert@medusa.com',
      role: 'patient',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    _User(
      id: '8',
      name: 'Dr. David Lee',
      email: 'david@medusa.com',
      role: 'doctor',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  List<_User> get filteredUsers {
    return _users.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == 'all' || user.role == _selectedRole;
      return matchesSearch && matchesRole;
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
          Expanded(child: _buildUsersList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.lightDivider, width: 1),
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
                  '${_users.length} total users',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildRoleStats(),
        ],
      ),
    );
  }

  Widget _buildRoleStats() {
    final patients = _users.where((u) => u.role == 'patient').length;
    final doctors = _users.where((u) => u.role == 'doctor').length;
    final admins = _users.where((u) => u.role == 'admin').length;

    return Row(
      children: [
        _buildStatChip('Patients', patients, AppColors.info),
        SizedBox(width: 8.w),
        _buildStatChip('Doctors', doctors, AppColors.success),
        SizedBox(width: 8.w),
        _buildStatChip('Admins', admins, AppColors.warning),
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
          // Search
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
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
          // Role filter
          DropdownButton<String>(
            value: _selectedRole,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Roles')),
              DropdownMenuItem(value: 'patient', child: Text('Patients')),
              DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
              DropdownMenuItem(value: 'admin', child: Text('Admins')),
            ],
            onChanged: (value) => setState(() => _selectedRole = value ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final users = filteredUsers;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'No users found',
              style: FontUtils.title(context: context, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: users.length,
      itemBuilder: (context, index) => _buildUserCard(users[index]),
    );
  }

  Widget _buildUserCard(_User user) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.name,
          style: FontUtils.body(
            context: context,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(user.email),
            SizedBox(height: 8.h),
            Row(
              children: [
                _buildRoleBadge(user.role),
                SizedBox(width: 8.w),
                Text(
                  'Created ${_formatDate(user.createdAt)}',
                  style: FontUtils.caption(
                    context: context,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showUserActions(user),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = _getRoleColor(role);
    final label = RolePermissions.getRoleDisplayName(role);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: FontUtils.caption(
          context: context,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.warning;
      case 'doctor':
        return AppColors.success;
      case 'patient':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 30).floor()} months ago';
    }
  }

  void _showUserActions(_User user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showUserDetails(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit User'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete User', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(_User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', user.email),
            _buildDetailRow('Role', RolePermissions.getRoleDisplayName(user.role)),
            _buildDetailRow('User ID', user.id),
            _buildDetailRow('Created', user.createdAt.toString().substring(0, 10)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: FontUtils.body(
                context: context,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: FontUtils.body(context: context),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(_User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _users.removeWhere((u) => u.id == user.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user.name} deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _User {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;

  _User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });
}
