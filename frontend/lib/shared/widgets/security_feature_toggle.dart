import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// A reusable toggle widget for displaying security feature controls
/// 
/// This widget shows a security feature with:
/// - Toggle switch for secure/insecure mode
/// - Expandable educational tip
/// - Visual feedback on current state
/// - Risk warning when disabled
/// 
/// Usage example:
/// ```dart
/// SecurityFeatureToggle(
///   featureId: 'password_complexity',
///   featureName: 'Password Complexity',
///   description: 'Enforces strong password requirements',
///   secureDescription: 'Requires 8+ chars, uppercase, lowercase, digit, special char',
///   insecureRisk: 'Weak passwords can be cracked in seconds',
///   isEnabled: true,
///   onToggle: (enabled) => handleToggle(enabled),
/// )
/// ```
class SecurityFeatureToggle extends StatefulWidget {
  final String featureId;
  final String featureName;
  final String description;
  final String secureDescription;
  final String insecureRisk;
  final bool isEnabled;
  final bool isReadOnly;
  final ValueChanged<bool>? onToggle;
  final String? codeLocation;
  final String? fdaRequirement;
  final IconData? icon;

  const SecurityFeatureToggle({
    super.key,
    required this.featureId,
    required this.featureName,
    required this.description,
    required this.secureDescription,
    required this.insecureRisk,
    required this.isEnabled,
    this.isReadOnly = false,
    this.onToggle,
    this.codeLocation,
    this.fdaRequirement,
    this.icon,
  });

  @override
  State<SecurityFeatureToggle> createState() => _SecurityFeatureToggleState();
}

class _SecurityFeatureToggleState extends State<SecurityFeatureToggle>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSecure = widget.isEnabled;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      decoration: BoxDecoration(
        color: isSecure 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSecure ? Colors.green : Colors.red,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header row with toggle
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  // Status icon
                  Icon(
                    widget.icon ?? (isSecure ? Icons.shield : Icons.warning),
                    color: isSecure ? Colors.green : Colors.red,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  
                  // Feature name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.featureName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: AppColors.lightOnSurface,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          isSecure ? 'SECURE' : 'INSECURE',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isSecure ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Toggle switch
                  if (!widget.isReadOnly)
                    Switch(
                      value: isSecure,
                      onChanged: widget.onToggle,
                      activeColor: Colors.green,
                      activeTrackColor: Colors.green.withValues(alpha: 0.5),
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.withValues(alpha: 0.5),
                    ),
                  
                  // Expand indicator
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: isSecure ? Colors.green : Colors.red),
                  SizedBox(height: 8.h),
                  
                  // Description
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  
                  // Secure behavior
                  _buildInfoRow(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    title: 'When Secure:',
                    content: widget.secureDescription,
                  ),
                  SizedBox(height: 8.h),
                  
                  // Risk when insecure
                  _buildInfoRow(
                    icon: Icons.error,
                    color: Colors.red,
                    title: 'Risk if Disabled:',
                    content: widget.insecureRisk,
                  ),
                  
                  // Code location (if provided)
                  if (widget.codeLocation != null) ...[
                    SizedBox(height: 8.h),
                    _buildInfoRow(
                      icon: Icons.code,
                      color: Colors.blue,
                      title: 'Implementation:',
                      content: widget.codeLocation!,
                    ),
                  ],
                  
                  // FDA requirement (if provided)
                  if (widget.fdaRequirement != null) ...[
                    SizedBox(height: 8.h),
                    _buildInfoRow(
                      icon: Icons.policy,
                      color: Colors.purple,
                      title: 'FDA Requirement:',
                      content: widget.fdaRequirement!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                content,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A compact version of the security toggle for inline use in forms
class SecurityFeatureToggleCompact extends StatelessWidget {
  final String featureName;
  final bool isEnabled;
  final String tip;
  final ValueChanged<bool>? onToggle;
  final bool isReadOnly;

  const SecurityFeatureToggleCompact({
    super.key,
    required this.featureName,
    required this.isEnabled,
    required this.tip,
    this.onToggle,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: (isEnabled ? Colors.green : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: (isEnabled ? Colors.green : Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.lock : Icons.lock_open,
            color: isEnabled ? Colors.green : Colors.orange,
            size: 18.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featureName,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isReadOnly)
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isEnabled,
                onChanged: onToggle,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.orange,
              ),
            ),
        ],
      ),
    );
  }
}
