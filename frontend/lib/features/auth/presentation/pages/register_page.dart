import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../core/utils/password_validator.dart';
import '../../../../shared/services/security_education_service.dart';
import '../../../../shared/widgets/password_strength_indicator.dart';
import '../../../../shared/widgets/security_feature_toggle.dart';
import '../bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _selectedRole = 'patient';  // Default to patient (admin not available for self-registration)
  
  // Security education service
  final SecurityEducationService _securityService = SecurityEducationService();
  
  // Security feature states - start with defaults, don't wait for backend
  bool _passwordComplexityEnabled = true;
  bool _passwordHashingEnabled = true;
  bool _inputValidationEnabled = true;
  bool _isLoadingFeatures = false;  // Don't show loading - toggles work immediately
  bool _showSecurityPanel = false;  // Default collapsed, user expands when needed

  @override
  void initState() {
    super.initState();
    // Load in background, but don't block UI
    _loadSecurityFeatures();
  }

  Future<void> _loadSecurityFeatures() async {
    // Sync with backend if available, but UI already shows toggles
    try {
      final config = await _securityService.getSecurityConfig();
      if (config != null && mounted) {
        setState(() {
          _passwordComplexityEnabled = SecurityEducationService.isFeatureEnabled('password_complexity');
          _passwordHashingEnabled = SecurityEducationService.isFeatureEnabled('password_hashing');
          _inputValidationEnabled = SecurityEducationService.isFeatureEnabled('input_validation');
        });
      }
    } catch (e) {
      debugPrint('Error loading security features: $e');
    }
  }

  Future<void> _toggleFeature(String featureId, bool enabled) async {
    // Update UI immediately - don't wait for backend
    setState(() {
      switch (featureId) {
        case 'password_complexity':
          _passwordComplexityEnabled = enabled;
          break;
        case 'password_hashing':
          _passwordHashingEnabled = enabled;
          break;
        case 'input_validation':
          _inputValidationEnabled = enabled;
          break;
      }
    });
    
    // Update local state in service (for consistency)
    SecurityEducationService.toggleFeatureLocally(featureId, enabled);
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled 
              ? '✅ $featureId enabled'
              : '⚠️ $featureId disabled (INSECURE!)'),
          backgroundColor: enabled ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    // Try to sync with backend (fire and forget)
    _securityService.toggleSecurityFeature(featureId, enabled);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Show success message and navigate to dashboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            GoRouter.of(context).go('/dashboard');
          } else if (state is AuthError) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppConstants.defaultPadding.w),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: ResponsiveBreakpoints.of(context).smallerThan(TABLET) ? double.infinity : 400.w,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Logo and Title
                  Column(
                    children: [
                      Icon(
                        Icons.medical_services_rounded,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.xxlarge, context),
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        AppConstants.appName,
                        style: FontUtils.title(
                          context: context,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Medical Data Fusion and Analysis System',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  SizedBox(height: 32.h),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(
                        Icons.person_outlined,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 16.h),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 16.h),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(
                        Icons.work_outlined,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'patient', child: Text('Patient')),
                      DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                      // Note: Admin accounts can only be created by existing admins
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),

                  SizedBox(height: 16.h),

                  // Password Complexity Toggle - visible above password field
                  SecurityFeatureToggleCompact(
                    featureName: 'Password Strength Check',
                    isEnabled: _passwordComplexityEnabled,
                    tip: _passwordComplexityEnabled
                        ? 'Requires 8+ chars, upper, lower, digit, special'
                        : '⚠️ Any password accepted - vulnerable to guessing!',
                    onToggle: (enabled) => _toggleFeature('password_complexity', enabled),
                  ),

                  SizedBox(height: 8.h),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    onChanged: (value) {
                      // Trigger rebuild to update password strength indicator
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      // Only validate password complexity if feature is enabled
                      if (_passwordComplexityEnabled) {
                        return PasswordValidator.validate(value);
                      }
                      // When disabled, accept ANY password (insecure!)
                      SecurityEducationService.logEducational(
                        'Password Complexity DISABLED',
                        'Weak password "$value" accepted! This would be rejected in secure mode.',
                      );
                      return null;
                    },
                  ),

                  SizedBox(height: 8.h),

                  // Password Strength Indicator (only show when complexity enabled)
                  if (_passwordComplexityEnabled)
                    PasswordStrengthIndicator(
                      password: _passwordController.text,
                      showRequirements: true,
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 20.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '⚠️ Password complexity DISABLED - any password accepted!',
                              style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 16.h),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Confirm your password',
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 16.h),

                  // Security Education Section
                  _buildSecurityEducationSection(),

                  SizedBox(height: 24.h),

                  // Register Button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      final hasDisabledFeatures = !_passwordComplexityEnabled || !_inputValidationEnabled;
                      
                      return Column(
                        children: [
                          if (hasDisabledFeatures) ...[
                            Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber, color: Colors.orange, size: 20.sp),
                                      SizedBox(width: 8.w),
                                      Text(
                                        '⚠️ SECURITY REDUCED',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.sp,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  if (!_passwordComplexityEnabled)
                                    Text(
                                      '• Password complexity disabled: weak passwords OK',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade700),
                                    ),
                                  if (!_inputValidationEnabled)
                                    Text(
                                      '• Input validation disabled: vulnerable to injection',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade700),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          ElevatedButton(
                            onPressed: isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              backgroundColor: hasDisabledFeatures ? Colors.orange : null,
                            ),
                            child: isLoading
                                ? SizedBox(
                                    height: 20.h,
                                    width: 20.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    hasDisabledFeatures ? 'Create Account (INSECURE!)' : 'Create Account',
                                    style: FontUtils.body(
                                      context: context,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 16.h),

                  // Login Link
                  TextButton(
                    onPressed: () {
                      GoRouter.of(context).go('/login');
                    },
                    child: const Text('Already have an account? Login here'),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dispatch register event to AuthBloc
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(
      RegisterRequested(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      ),
    );
  }

  /// Build the security education section for registration
  Widget _buildSecurityEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle to show/hide security panel
        InkWell(
          onTap: () => setState(() => _showSecurityPanel = !_showSecurityPanel),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  '🔐 Security Education Lab',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showSecurityPanel ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        
        // Security features panel (expanded)
        if (_showSecurityPanel) ...[
          SizedBox(height: 12.h),
          
          if (_isLoadingFeatures)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Password Complexity Toggle
            SecurityFeatureToggleCompact(
              featureName: 'Password Complexity',
              isEnabled: _passwordComplexityEnabled,
              tip: _passwordComplexityEnabled 
                  ? 'Requires 8+ chars, upper, lower, digit, special' 
                  : '⚠️ Any password accepted - vulnerable to guessing!',
              onToggle: (enabled) => _toggleFeature('password_complexity', enabled),
            ),
            
            // Password Hashing Toggle (read-only due to safety)
            SecurityFeatureToggleCompact(
              featureName: 'Argon2id Password Hashing',
              isEnabled: _passwordHashingEnabled,
              tip: 'Industry-leading hash algorithm (always enabled for safety)',
              isReadOnly: true,
            ),
            
            // Input Validation Toggle
            SecurityFeatureToggleCompact(
              featureName: 'Input Validation',
              isEnabled: _inputValidationEnabled,
              tip: _inputValidationEnabled 
                  ? 'Validates all input data formats' 
                  : '⚠️ No validation - vulnerable to injection!',
              onToggle: (enabled) => _toggleFeature('input_validation', enabled),
            ),
            
            // Educational tip
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Try disabling password complexity and register with "123"!',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}