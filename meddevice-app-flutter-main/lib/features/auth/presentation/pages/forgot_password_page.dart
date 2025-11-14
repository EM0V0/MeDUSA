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
import '../../../../shared/widgets/password_strength_indicator.dart';
import '../bloc/auth_bloc.dart';

/// Forgot Password Page - Three-step password reset flow
/// Step 1: Enter email
/// Step 2: Enter verification code
/// Step 3: Enter new password
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  int _currentStep = 0; // 0: email, 1: code, 2: new password
  String _email = '';
  String _code = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/login'),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is PasswordResetCodeSent) {
            // Move to step 2: Enter code
            setState(() {
              _currentStep = 1;
              _email = state.email;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification code sent to ${state.email}'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ResetCodeVerified) {
            // Move to step 3: Enter new password
            setState(() {
              _currentStep = 2;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Code verified! Please enter your new password.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is PasswordResetSuccess) {
            // Show success and navigate to login
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset successful! Please login with your new password.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
            Future.delayed(const Duration(seconds: 1), () {
              GoRouter.of(context).go('/login');
            });
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
                maxWidth: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                    ? double.infinity 
                    : 450.w,
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

                    // Progress Indicator
                    _buildProgressIndicator(),
                    SizedBox(height: 32.h),

                    // Step Content
                    if (_currentStep == 0) _buildEmailStep(),
                    if (_currentStep == 1) _buildCodeStep(),
                    if (_currentStep == 2) _buildNewPasswordStep(),
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
          Icons.lock_reset_rounded,
          size: IconUtils.getResponsiveIconSize(IconSizeType.xxlarge, context),
          color: AppColors.primary,
        ),
        SizedBox(height: 16.h),
        Text(
          'Reset Your Password',
          style: FontUtils.title(
            context: context,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          _getStepDescription(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case 0:
        return 'Enter your email address to receive a verification code';
      case 1:
        return 'Enter the 6-digit code sent to your email';
      case 2:
        return 'Create a new password for your account';
      default:
        return '';
    }
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        Expanded(child: _buildStepIndicator(0, 'Email')),
        Expanded(child: _buildStepIndicator(1, 'Code')),
        Expanded(child: _buildStepIndicator(2, 'Password')),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Row(
          children: [
            if (step > 0)
              Expanded(
                child: Container(
                  height: 2.h,
                  color: isCompleted ? AppColors.primary : AppColors.outline,
                ),
              ),
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.primary : AppColors.lightSurface,
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, size: 16.sp, color: AppColors.onPrimary)
                    : Text(
                        '${step + 1}',
                        style: TextStyle(
                          color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
              ),
            ),
            if (step < 2)
              Expanded(
                child: Container(
                  height: 2.h,
                  color: isCompleted ? AppColors.primary : AppColors.outline,
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email',
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
        SizedBox(height: 24.h),
        _buildActionButton(
          label: 'Send Verification Code',
          onPressed: _handleSendCode,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Show email hint
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.onPrimaryContainer,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Code sent to: $_email',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        
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
        
        _buildActionButton(
          label: 'Verify Code',
          onPressed: _handleVerifyCode,
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _newPasswordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'New Password',
            hintText: 'Enter new password',
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
              return 'Please enter a password';
            }
            // Use enhanced password validator
            return PasswordValidator.validate(value);
          },
        ),
        SizedBox(height: 12.h),
        
        // Password Strength Indicator
        PasswordStrengthIndicator(
          password: _newPasswordController.text,
          showRequirements: true,
        ),
        
        SizedBox(height: 16.h),
        
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            hintText: 'Re-enter new password',
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
            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        SizedBox(height: 24.h),
        
        _buildActionButton(
          label: 'Reset Password',
          onPressed: _handleResetPassword,
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

  void _handleSendCode() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(RequestPasswordResetRequested(email: _emailController.text.trim()));
  }

  void _handleResendCode() {
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(RequestPasswordResetRequested(email: _email));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending new verification code...'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleVerifyCode() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _code = _codeController.text.trim();
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(VerifyResetCodeRequested(email: _email, code: _code));
  }

  void _handleResetPassword() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(ResetPasswordRequested(
      email: _email,
      newPassword: _newPasswordController.text,
      code: _code,
    ));
  }
}

