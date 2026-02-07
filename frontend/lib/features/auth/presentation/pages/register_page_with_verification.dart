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
import '../../../../shared/widgets/security_feature_toggle.dart';
import '../bloc/auth_bloc.dart';

/// Register Page with Email Verification - Two-step registration flow
/// Step 1: Fill registration form and send verification code
/// Step 2: Enter verification code and complete registration
class RegisterPageWithVerification extends StatefulWidget {
  const RegisterPageWithVerification({super.key});

  @override
  State<RegisterPageWithVerification> createState() => _RegisterPageWithVerificationState();
}

class _RegisterPageWithVerificationState extends State<RegisterPageWithVerification> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isVerificationStep = false;
  String _selectedRole = 'patient';  // Default to patient (admin not available for self-registration)
  String _registrationEmail = '';

  // Security education
  final SecurityEducationService _securityService = SecurityEducationService();
  bool _passwordComplexityEnabled = true;
  bool _passwordHashingEnabled = true;
  bool _inputValidationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityFeatures();
  }

  Future<void> _loadSecurityFeatures() async {
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

  void _toggleFeature(String featureId, bool enabled) {
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
    SecurityEducationService.toggleFeatureLocally(featureId, enabled);
    _securityService.toggleSecurityFeature(featureId, enabled);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is VerificationCodeSent) {
            // Move to verification step
            setState(() {
              _isVerificationStep = true;
              _registrationEmail = state.email;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification code sent to ${state.email}'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is EmailVerified) {
            // Email verified, proceed with registration
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified! Creating your account...'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Trigger registration
            _handleCompleteRegistration();
          } else if (state is AuthAuthenticated) {
            // Registration complete - show MFA secret if available
            final mfaSecret = state.user.mfaSecret;
            if (mfaSecret != null && mfaSecret.isNotEmpty) {
              _showMfaSecretDialog(context, mfaSecret, state.user.email);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account created successfully!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              GoRouter.of(context).go('/dashboard');
            }
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
                maxWidth: ResponsiveBreakpoints.of(context).smallerThan(TABLET) ? double.infinity : 450.w,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(),
                    SizedBox(height: 32.h),

                    // Step indicator
                    _buildStepIndicator(),
                    SizedBox(height: 24.h),

                    // Content based on step
                    if (!_isVerificationStep)
                      _buildRegistrationForm()
                    else
                      _buildVerificationForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
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
          _isVerificationStep 
              ? 'Verify Your Email' 
              : 'Create Your Account',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        Expanded(
          child: _buildStepItem(
            stepNumber: 1,
            label: 'Registration',
            isActive: !_isVerificationStep,
            isCompleted: _isVerificationStep,
          ),
        ),
        Expanded(
          child: Container(
            height: 2.h,
            color: _isVerificationStep ? AppColors.primary : AppColors.outline,
          ),
        ),
        Expanded(
          child: _buildStepItem(
            stepNumber: 2,
            label: 'Verification',
            isActive: _isVerificationStep,
            isCompleted: false,
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        Container(
          width: 36.w,
          height: 36.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? AppColors.primary : AppColors.lightSurface,
            border: Border.all(
              color: isActive || isCompleted ? AppColors.primary : AppColors.outline,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 18.sp, color: AppColors.onPrimary)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isActive || isCompleted ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            if (_inputValidationEnabled) {
              if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
            } else {
              SecurityEducationService.logEducational(
                'Input Validation DISABLED',
                'No email format validation! Malformed input accepted.',
              );
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
        SizedBox(height: 12.h),

        // Password Complexity Toggle - always visible
        SecurityFeatureToggleCompact(
          featureName: 'Password Strength Check',
          isEnabled: _passwordComplexityEnabled,
          tip: _passwordComplexityEnabled
              ? 'Requires 8+ chars, upper, lower, digit, special'
              : '⚠️ Any password accepted - vulnerable to guessing!',
          onToggle: (enabled) => _toggleFeature('password_complexity', enabled),
        ),

        // Password Hashing Toggle (read-only for safety)
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
            setState(() {});
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (_passwordComplexityEnabled) {
              return PasswordValidator.validate(value);
            }
            // Complexity disabled - accept any password
            SecurityEducationService.logEducational(
              'Password Complexity DISABLED',
              'Weak password accepted! This would be rejected in secure mode.',
            );
            return null;
          },
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
        SizedBox(height: 24.h),

        // Send Verification Code Button
        _buildActionButton(
          label: 'Send Verification Code',
          onPressed: _handleSendVerificationCode,
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
    );
  }

  Widget _buildVerificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email info box
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.onPrimaryContainer,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification code sent!',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Check $_registrationEmail for the 6-digit code',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // Verification Code Field
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Verification Code',
            hintText: 'Enter 6-digit code',
            prefixIcon: Icon(
              Icons.pin_outlined,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the verification code';
            }
            if (value.length != 6) {
              return 'Code must be 6 digits';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),

        // Resend code button
        TextButton(
          onPressed: _handleResendCode,
          child: const Text('Didn\'t receive the code? Resend'),
        ),
        SizedBox(height: 24.h),

        // Verify and Register Button
        _buildActionButton(
          label: 'Verify and Create Account',
          onPressed: _handleVerifyAndRegister,
        ),
        SizedBox(height: 16.h),

        // Back button
        TextButton(
          onPressed: () {
            setState(() {
              _isVerificationStep = false;
              _codeController.clear();
            });
          },
          child: const Text('Back to Registration Form'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.h),
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
                  label,
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }

  void _handleSendVerificationCode() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(SendVerificationCodeRequested(email: _emailController.text.trim()));
  }

  void _handleResendCode() {
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(SendVerificationCodeRequested(email: _registrationEmail));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending new verification code...'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleVerifyAndRegister() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(VerifyEmailRequested(
      email: _registrationEmail,
      code: _codeController.text.trim(),
    ));
  }

  void _handleCompleteRegistration() {
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(
      RegisterRequested(
        name: _nameController.text.trim(),
        email: _registrationEmail,
        password: _passwordController.text,
        role: _selectedRole,
        verificationCode: _codeController.text.trim(),
      ),
    );
  }

  void _showMfaSecretDialog(BuildContext context, String mfaSecret, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.primary, size: 28.sp),
            SizedBox(width: 8.w),
            const Text('MFA Setup Required'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your account has been created! Please save your MFA secret to set up two-factor authentication.',
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Text(
                      '🔑 Your MFA Secret',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SelectableText(
                      mfaSecret,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        color: Colors.green.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Setup Instructions:',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '1. Open Google Authenticator or Authy\n'
                      '2. Tap "+" to add a new account\n'
                      '3. Choose "Enter setup key"\n'
                      '4. Account: $email\n'
                      '5. Key: Copy the secret above\n'
                      '6. Type: Time-based (TOTP)',
                      style: TextStyle(fontSize: 12.sp, height: 1.5),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '⚠️ Save this secret now! You will need it to log in. A welcome email with this secret has also been sent.',
                        style: TextStyle(fontSize: 11.sp, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              GoRouter.of(context).go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('I\'ve saved my secret - Continue'),
          ),
        ],
      ),
    );
  }
}
