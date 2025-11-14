import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/constants/app_constants.dart';
// Removed AppRouter import to avoid circular dependency and undefined symbol
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/oauth_service.dart';
import '../bloc/auth_bloc.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final OAuthService _oauthService = OAuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeOAuth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeOAuth() async {
    await _oauthService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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

                  SizedBox(height: 48.h),

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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < AppConstants.passwordMinLength) {
                        return 'Password must be at least ${AppConstants.passwordMinLength} characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 24.h),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),

                  SizedBox(height: 16.h),

                  // Register Link
                  TextButton(
                    onPressed: () {
                      GoRouter.of(context).go('/register');
                    },
                    child: const Text('Don\'t have an account? Register here'),
                  ),

                  SizedBox(height: 24.h),

                  // OAuth Login Options
                  _buildOAuthSection(),

                  SizedBox(height: 24.h),

                  // Demo Login Button (for testing)
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('Demo login clicked!');
                      // Update AuthBloc state first, then navigate
                      final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
                      authBloc.add(LoginRequested(email: 'demo@medusa.com', password: 'demo123'));
                      // Navigate to dashboard
                      GoRouter.of(context).go('/dashboard');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: const Text('Demo Login (For Testing)'),
                  ),

                  SizedBox(height: 16.h),

                  // Quick Role Test Section
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.lightDivider),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Quick Role Testing',
                          style: FontUtils.body(
                            context: context,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            _buildRoleTestButton('Doctor', 'doctor@medusa.com'),
                            _buildRoleTestButton('Patient', 'patient@medusa.com'),
                            _buildRoleTestButton('Admin', 'admin@medusa.com'),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        TextButton(
                          onPressed: () {
                            GoRouter.of(context).go('/role-test');
                          },
                          child: const Text('View Role Test Page'),
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
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual login logic
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // For now, just navigate to dashboard
      if (mounted) {
        GoRouter.of(context).go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRoleTestButton(String roleName, String email) {
    Color buttonColor;
    switch (roleName.toLowerCase()) {
      case 'doctor':
        buttonColor = AppColors.primary;
        break;
      case 'patient':
        buttonColor = AppColors.success;
        break;
      case 'admin':
        buttonColor = AppColors.error;
        break;
      default:
        buttonColor = AppColors.lightOnSurfaceVariant;
    }

    return ElevatedButton(
      onPressed: () {
        final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
        authBloc.add(LoginRequested(email: email, password: 'demo123'));
        GoRouter.of(context).go('/dashboard');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
      child: Text(
        roleName,
        style: FontUtils.caption(
          context: context,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOAuthSection() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.lightDivider)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'Or continue with',
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.lightDivider)),
          ],
        ),
        SizedBox(height: 20.h),
        // Use Wrap to prevent overflow on narrow screens
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            _buildProperOAuthButton(
              Buttons.Google,
              'Google',
              () => _handleGoogleSignIn(),
            ),
            _buildProperOAuthButton(
              Buttons.Apple,
              'Apple',
              () => _handleAppleSignIn(),
            ),
            _buildProperOAuthButton(
              Buttons.Microsoft,
              'Microsoft',
              () => _handleMicrosoftSignIn(),
            ),
          ],
        ),
      ],
    );
  }

  // Build proper OAuth button using flutter_signin_button package
  Widget _buildProperOAuthButton(Buttons buttonType, String provider, VoidCallback onPressed) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: ResponsiveBreakpoints.of(context).smallerThan(TABLET) ? 280.w : 160.w,
        maxWidth: ResponsiveBreakpoints.of(context).smallerThan(TABLET) ? double.infinity : 200.w,
      ),
      child: SignInButton(
        buttonType,
        onPressed: _isLoading ? null : onPressed,
        mini: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      ),
    );
  }


  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _oauthService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        _showSuccessMessage('Successfully signed in with Google');
        
        // Update AuthBloc with OAuth user data
        final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
        authBloc.add(LoginRequested(
          email: result.user!['email'] ?? 'google_user@medusa.com',
          password: 'oauth_login',
        ));
        
        // Navigate to dashboard
        GoRouter.of(context).go('/dashboard');
      } else if (result.cancelled) {
        _showErrorMessage('Google sign-in was cancelled');
      } else {
        _showErrorMessage(result.error ?? 'Google sign-in failed');
      }
    } catch (e) {
      _showErrorMessage('Google sign-in error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _oauthService.signInWithApple();
      
      if (result.success && result.user != null) {
        _showSuccessMessage('Successfully signed in with Apple');
        
        // Update AuthBloc with OAuth user data
        final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
        authBloc.add(LoginRequested(
          email: result.user!['email'] ?? 'apple_user@medusa.com',
          password: 'oauth_login',
        ));
        
        // Navigate to dashboard
        GoRouter.of(context).go('/dashboard');
      } else if (result.cancelled) {
        _showErrorMessage('Apple sign-in was cancelled');
      } else {
        _showErrorMessage(result.error ?? 'Apple sign-in failed');
      }
    } catch (e) {
      _showErrorMessage('Apple sign-in error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMicrosoftSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _oauthService.signInWithMicrosoft();
      
      if (result.success && result.user != null) {
        _showSuccessMessage('Successfully signed in with Microsoft');
        
        // Update AuthBloc with OAuth user data
        final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
        authBloc.add(LoginRequested(
          email: result.user!['email'] ?? 'microsoft_user@medusa.com',
          password: 'oauth_login',
        ));
        
        // Navigate to dashboard
        GoRouter.of(context).go('/dashboard');
      } else if (result.cancelled) {
        _showErrorMessage('Microsoft sign-in was cancelled');
      } else {
        _showErrorMessage(result.error ?? 'Microsoft sign-in failed');
      }
    } catch (e) {
      _showErrorMessage('Microsoft sign-in error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.body(
            context: context,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.body(
            context: context,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
