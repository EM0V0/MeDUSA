import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/role_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/role_service.dart';

/// Test page to verify role-based functionality
/// This page displays current user information and role-based permissions
class RoleTestPage extends StatefulWidget {
  const RoleTestPage({super.key});

  @override
  State<RoleTestPage> createState() => _RoleTestPageState();
}

class _RoleTestPageState extends State<RoleTestPage> {
  late RoleService _roleService;

  @override
  void initState() {
    super.initState();
    _roleService = RoleService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role System Test'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            SizedBox(height: 20.h),
            _buildRoleInfoCard(),
            SizedBox(height: 20.h),
            _buildPermissionsCard(),
            SizedBox(height: 20.h),
            _buildNavigationItemsCard(),
            SizedBox(height: 20.h),
            _buildRoleTestButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    final user = _roleService.currentUser;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current User Information',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            if (user != null) ...[
              _buildInfoRow('Name:', user.name),
              _buildInfoRow('Email:', user.email),
              _buildInfoRow('Role:', user.role),
              _buildInfoRow('User ID:', user.id),
              _buildInfoRow('Active:', user.isActive ? 'Yes' : 'No'),
              _buildInfoRow('Last Login:', user.lastLogin?.toString() ?? 'Never'),
            ] else ...[
              Text(
                'No user logged in',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role Information',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            _buildInfoRow('Role Display Name:', _roleService.getRoleDisplayName()),
            _buildInfoRow('Role Description:', _roleService.getRoleDescription()),
            _buildInfoRow('Is Doctor:', _roleService.isDoctor ? 'Yes' : 'No'),
            _buildInfoRow('Is Patient:', _roleService.isPatient ? 'Yes' : 'No'),
            _buildInfoRow('Is Admin:', _roleService.isAdmin ? 'Yes' : 'No'),
            _buildInfoRow('Is Medical Professional:', _roleService.isMedicalProfessional ? 'Yes' : 'No'),
            _buildInfoRow('Dashboard Route:', _roleService.getDashboardRoute()),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard() {
    final permissions = _roleService.getCurrentUserPermissions();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Permissions (${permissions.length})',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            if (permissions.isNotEmpty) ...[
              ...permissions.map((permission) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        permission.description,
                        style: FontUtils.body(context: context),
                      ),
                    ),
                  ],
                ),
              )),
            ] else ...[
              Text(
                'No permissions assigned',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationItemsCard() {
    final navigationItems = _roleService.getFilteredNavigationItems();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigation Items (${navigationItems.length})',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            if (navigationItems.isNotEmpty) ...[
              ...navigationItems.map((item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.navigation,
                        color: AppColors.primary,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: FontUtils.body(
                                context: context,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.route,
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
                ),
              )),
            ] else ...[
              Text(
                'No navigation items available',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTestButtons() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permission Tests',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildPermissionTestButton(
                  'View Patients',
                  AppPermission.viewAllPatientData,
                ),
                _buildPermissionTestButton(
                  'Edit Patient',
                  AppPermission.editPatientData,
                ),
                _buildPermissionTestButton(
                  'Create Reports',
                  AppPermission.createReports,
                ),
                _buildPermissionTestButton(
                  'System Settings',
                  AppPermission.viewSystemSettings,
                ),
                _buildPermissionTestButton(
                  'Manage Users',
                  AppPermission.viewUsers,
                ),
                _buildPermissionTestButton(
                  'View Own Data',
                  AppPermission.viewOwnPatientData,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                _roleService.logCurrentPermissions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Check console for permission details'),
                  ),
                );
              },
              child: const Text('Log Permissions to Console'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTestButton(String label, AppPermission permission) {
    final hasPermission = _roleService.hasPermission(permission);
    
    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Permission Test: $label'),
            content: Text(
              hasPermission
                  ? 'You have permission to $label'
                  : 'You do NOT have permission to $label',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: hasPermission ? AppColors.success : AppColors.error,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: FontUtils.body(
                context: context,
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
}
