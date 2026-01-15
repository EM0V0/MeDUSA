import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/icon_utils.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;

  const AuthLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveBreakpoints.of(context).largerThan(TABLET) ? _buildDesktopLayout(context) : child,
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left side - Branding
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(48.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medical_services_rounded,
                      size: 120.w,
                      color: AppColors.onPrimary,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'NeuroMotion',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Advanced Parkinson\'s Disease\nMonitoring System',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.onPrimary.withValues(alpha: 0.9),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32.h),
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.onPrimary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                        crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
                        children: [
                          _buildFeatureItem(
                            context,
                            Icons.security,
                            'End-to-End Encryption',
                          ),
                          SizedBox(height: 16.h), // Increased spacing
                          _buildFeatureItem(
                            context,
                            Icons.cloud_sync,
                            'Real-time Monitoring',
                          ),
                          SizedBox(height: 16.h), // Increased spacing
                          _buildFeatureItem(
                            context,
                            Icons.analytics,
                            'Advanced Analytics',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right side - Auth form
        Expanded(
          flex: 1,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 400.w),
                padding: EdgeInsets.all(32.w),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build a centered feature item with icon and text
  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the row content
        mainAxisSize: MainAxisSize.min, // Take only necessary space
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              color: AppColors.onPrimary,
              size: IconUtils.getProtectedSize(
                context,
                targetSize: 20.0,
                minSize: 18.0,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
