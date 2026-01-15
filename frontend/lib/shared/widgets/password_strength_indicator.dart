import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/utils/password_validator.dart';
import '../../core/theme/app_colors.dart';

/// Password strength indicator widget
/// 
/// Displays a visual strength bar and requirements checklist
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showRequirements;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showRequirements = true,
  });

  @override
  Widget build(BuildContext context) {
    final strength = PasswordValidator.calculateStrength(password);
    final strengthLabel = PasswordValidator.getStrengthLabel(strength);
    final requirements = PasswordValidator.getRequirements();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar
        _buildStrengthBar(strength, strengthLabel),
        
        if (showRequirements && password.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _buildRequirements(requirements),
        ],
      ],
    );
  }

  /// Build strength bar visualization
  Widget _buildStrengthBar(int strength, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _getStrengthColor(strength),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: List.generate(4, (index) {
            final isActive = index < strength;
            return Expanded(
              child: Container(
                height: 4.h,
                margin: EdgeInsets.only(right: index < 3 ? 4.w : 0),
                decoration: BoxDecoration(
                  color: isActive ? _getStrengthColor(strength) : AppColors.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Build requirements checklist
  Widget _buildRequirements(List<PasswordRequirement> requirements) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.onSurfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppColors.onSurfaceVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8.h),
          ...requirements.map((req) => _buildRequirementItem(req)),
        ],
      ),
    );
  }

  /// Build individual requirement item
  Widget _buildRequirementItem(PasswordRequirement requirement) {
    final isMet = requirement.isMet(password);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14.sp,
            color: isMet ? AppColors.success : AppColors.onSurfaceVariant.withOpacity(0.5),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              requirement.label,
              style: TextStyle(
                fontSize: 11.sp,
                color: isMet ? AppColors.lightOnSurface : AppColors.onSurfaceVariant,
                decoration: isMet ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get color for strength level
  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
        return AppColors.error;
      case 1:
        return const Color(0xFFEA580C); // Orange-600
      case 2:
        return const Color(0xFFF59E0B); // Amber-500
      case 3:
        return AppColors.success;
      case 4:
        return const Color(0xFF059669); // Green-600
      default:
        return AppColors.onSurfaceVariant;
    }
  }
}

