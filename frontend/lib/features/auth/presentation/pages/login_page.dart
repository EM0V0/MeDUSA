import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/security_education_service.dart';
import '../../../../shared/widgets/security_feature_toggle.dart';
import '../bloc/auth_bloc.dart';

/// Login Page - Clean version with email/password authentication only
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  
  // Security education service
  final SecurityEducationService _securityService = SecurityEducationService();
  
  // Security feature states - start with defaults, don't wait for backend
  bool _mfaEnabled = true;
  bool _rateLimitingEnabled = true;
  bool _jwtAuthEnabled = true;
  bool _sessionManagementEnabled = true;
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
          _mfaEnabled = SecurityEducationService.isFeatureEnabled('mfa_totp');
          _rateLimitingEnabled = SecurityEducationService.isFeatureEnabled('rate_limiting');
          _jwtAuthEnabled = SecurityEducationService.isFeatureEnabled('jwt_authentication');
          _sessionManagementEnabled = SecurityEducationService.isFeatureEnabled('session_management');
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
        case 'mfa_totp':
          _mfaEnabled = enabled;
          break;
        case 'rate_limiting':
          _rateLimitingEnabled = enabled;
          break;
        case 'jwt_authentication':
          _jwtAuthEnabled = enabled;
          break;
        case 'session_management':
          _sessionManagementEnabled = enabled;
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
              : '⚠️ $featureId disabled (INSECURE!) - Backend feature, requires deployment'),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Navigate to dashboard on successful login
            GoRouter.of(context).go('/dashboard');
          } else if (state is AuthMfaRequired) {
            _showMfaDialog(context, state.tempToken);
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
                    : 400.w,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Title
                    _buildHeader(),
                    SizedBox(height: 48.h),

                    // Email Field
                    _buildEmailField(),
                    SizedBox(height: 16.h),

                    // Password Field
                    _buildPasswordField(),
                    SizedBox(height: 8.h),

                    // Security Education Section
                    _buildSecurityEducationSection(),
                    SizedBox(height: 8.h),

                    // Forgot Password Link
                    _buildForgotPasswordLink(),
                    SizedBox(height: 16.h),

                    // Login Button
                    _buildLoginButton(),
                    SizedBox(height: 16.h),

                    // Register Link
                    _buildRegisterLink(),
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
          'Medical Data Fusion and Analysis System',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
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
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
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
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < AppConstants.passwordMinLength) {
          return 'Password must be at least ${AppConstants.passwordMinLength} characters';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final hasDisabledFeatures = !_mfaEnabled || !_rateLimitingEnabled;
        
        return Column(
          children: [
            // Warning banner when features disabled
            if (hasDisabledFeatures && _showSecurityPanel) ...[  
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
                    if (!_mfaEnabled)
                      Text(
                        '• MFA disabled: Password-only authentication',
                        style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade700),
                      ),
                    if (!_rateLimitingEnabled)
                      Text(
                        '• Rate limiting disabled: Unlimited login attempts',
                        style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade700),
                      ),
                  ],
                ),
              ),
            ],
            
            // Login button
            ElevatedButton(
              onPressed: isLoading ? null : _handleLogin,
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
                      hasDisabledFeatures ? 'Login (INSECURE!)' : 'Login',
                      style: FontUtils.body(
                        context: context,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          GoRouter.of(context).go('/forgot-password');
        },
        child: const Text(
          'Forgot Password?',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () {
        GoRouter.of(context).go('/register');
      },
      child: const Text('Don\'t have an account? Register here'),
    );
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Educational logging for disabled features
    if (!_mfaEnabled) {
      SecurityEducationService.logEducational(
        'MFA DISABLED',
        'Login without MFA! If credentials are stolen, attacker gains full access.',
      );
    }
    if (!_rateLimitingEnabled) {
      SecurityEducationService.logEducational(
        'RATE LIMITING DISABLED',
        'No brute-force protection! Attacker could try unlimited passwords.',
      );
    }

    // Dispatch login event to AuthBloc
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(
      LoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _showMfaDialog(BuildContext context, String tempToken) {
    final codeController = TextEditingController();
    // Capture the AuthBloc from the page context BEFORE opening the dialog,
    // so we don't rely on the dialog's context after it's dismissed.
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('MFA Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the verification code from your authenticator app.'),
            SizedBox(height: 16.h),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeController.text.isNotEmpty) {
                Navigator.pop(dialogContext); // Close dialog
                authBloc.add(
                  MfaLoginRequested(
                    tempToken: tempToken,
                    code: codeController.text.trim(),
                  ),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  /// Build the security education section with toggleable features
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
            // MFA Toggle
            SecurityFeatureToggleCompact(
              featureName: 'Two-Factor Auth (MFA)',
              isEnabled: _mfaEnabled,
              tip: _mfaEnabled 
                  ? 'TOTP code required after password' 
                  : '⚠️ Password only - vulnerable to credential theft!',
              onToggle: (enabled) => _toggleFeature('mfa_totp', enabled),
            ),
            
            // Rate Limiting Toggle
            SecurityFeatureToggleCompact(
              featureName: 'Brute-Force Protection',
              isEnabled: _rateLimitingEnabled,
              tip: _rateLimitingEnabled 
                  ? '5 attempts max, then 60s lockout' 
                  : '⚠️ Unlimited attempts - vulnerable to password guessing!',
              onToggle: (enabled) => _toggleFeature('rate_limiting', enabled),
            ),
            
            // JWT Auth indicator (read-only)
            SecurityFeatureToggleCompact(
              featureName: 'JWT Authentication',
              isEnabled: _jwtAuthEnabled,
              tip: 'Secure token-based session management',
              isReadOnly: true,
            ),
            
            // Session Management (read-only - JWT expiry is always enforced)
            SecurityFeatureToggleCompact(
              featureName: 'Session Management',
              isEnabled: _sessionManagementEnabled,
              tip: 'Token expiry + secure refresh (always active, core security)',
              isReadOnly: true,
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
                      'Try 6 wrong passwords to trigger lockout!',
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
