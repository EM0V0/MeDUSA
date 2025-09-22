import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController(text: 'Dr. Sarah Johnson');
  final _emailController = TextEditingController(text: 'sarah.johnson@medusa.com');
  final _phoneController = TextEditingController(text: '+1 (555) 123-4567');
  final _specialtyController = TextEditingController(text: 'Neurologist');
  final _licenseController = TextEditingController(text: 'MD-12345678');
  final _departmentController = TextEditingController(text: 'Neurology Department');
  final _hospitalController = TextEditingController(text: 'City General Hospital');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _licenseController.dispose();
    _departmentController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            SizedBox(height: 24.h),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildProfileSection(isMobile),
                    SizedBox(height: 24.h),
                    _buildContactSection(isMobile),
                    SizedBox(height: 24.h),
                    _buildProfessionalSection(isMobile),
                    SizedBox(height: 24.h),
                    _buildActionsSection(isMobile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile',
          style: FontUtils.title(
            context: context,
            fontWeight: FontWeight.bold,
            color: AppColors.lightOnSurface,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Manage your personal and professional information',
          style: FontUtils.body(
            context: context,
            color: AppColors.lightOnSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Information',
            style: FontUtils.title(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 24.h),

          // Profile Picture
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: isMobile ? 50.w : 40.w,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    'SJ',
                    style: FontUtils.title(
                      context: context,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement photo upload
                  },
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  ),
                  label: Text(
                    'Change Photo',
                    style: FontUtils.body(
                      context: context,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // Form Fields
          _buildTextField('Full Name', _nameController, isMobile),
          SizedBox(height: 16.h),
          _buildTextField('Email Address', _emailController, isMobile),
          SizedBox(height: 16.h),
          _buildTextField('Phone Number', _phoneController, isMobile),
        ],
      ),
    );
  }

  Widget _buildContactSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: FontUtils.title(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 24.h),
          _buildTextField('Hospital', _hospitalController, isMobile),
          SizedBox(height: 16.h),
          _buildTextField('Department', _departmentController, isMobile),
          SizedBox(height: 16.h),
          _buildTextField('Medical Specialty', _specialtyController, isMobile),
          SizedBox(height: 16.h),
          _buildTextField('License Number', _licenseController, isMobile),
        ],
      ),
    );
  }

  Widget _buildProfessionalSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Information',
            style: TextStyle(
              fontSize: isMobile ? 20.sp : 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Patients',
                  '156',
                  Icons.people_outline,
                  AppColors.primary,
                  isMobile,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildInfoCard(
                  'Reports',
                  '23',
                  Icons.assessment_outlined,
                  AppColors.success,
                  isMobile,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Experience',
                  '8 years',
                  Icons.work_outline,
                  AppColors.warning,
                  isMobile,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildInfoCard(
                  'Certifications',
                  '5',
                  Icons.verified_outlined,
                  AppColors.info,
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: FontUtils.title(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 24.h),
          Center(
            child: SizedBox(
              width: isMobile ? double.infinity : 200.w,
              height: isMobile ? 56.h : 48.h,
              child: ElevatedButton(
                onPressed: () {
                  _saveProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.lightSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Save Changes',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: SizedBox(
              width: isMobile ? double.infinity : 200.w,
              height: isMobile ? 56.h : 48.h,
              child: OutlinedButton(
                onPressed: () {
                  _changePassword();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Change Password',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FontUtils.body(
            context: context,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          style: FontUtils.body(
            context: context,
            color: AppColors.lightOnSurface,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: isMobile ? 16.h : 12.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            color: color,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: FontUtils.title(
              context: context,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: FontUtils.bodyText('Profile updated successfully', context),
      ),
    );
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: FontUtils.titleText('Change Password', context),
        content: FontUtils.bodyText('Password change feature will be implemented soon.', context),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: FontUtils.bodyText('OK', context),
          ),
        ],
      ),
    );
  }
}
