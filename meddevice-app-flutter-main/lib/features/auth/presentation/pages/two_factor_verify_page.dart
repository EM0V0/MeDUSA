import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/two_factor_auth_service.dart';

class TwoFactorVerifyPage extends StatefulWidget {
  final String userEmail;
  final Function(bool success) onVerificationComplete;
  final VoidCallback? onCancel;

  const TwoFactorVerifyPage({
    super.key,
    required this.userEmail,
    required this.onVerificationComplete,
    this.onCancel,
  });

  @override
  State<TwoFactorVerifyPage> createState() => _TwoFactorVerifyPageState();
}

class _TwoFactorVerifyPageState extends State<TwoFactorVerifyPage> with TickerProviderStateMixin {
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  Timer? _codeTimer;
  Timer? _resendTimer;
  
  bool _isVerifying = false;
  bool _showBackupCodeInput = false;
  String? _errorMessage;
  int _timeRemaining = 30;
  int _resendCooldown = 0;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
    _startCodeTimer();
    _codeFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    _shakeController.dispose();
    _codeTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
  }

  Future<void> _initializeService() async {
    await _twoFactorService.initialize();
    setState(() {});
  }

  void _startCodeTimer() {
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_twoFactorService.isSetup && mounted) {
        setState(() {
          _timeRemaining = _twoFactorService.getTimeRemaining();
        });
      }
    });
  }

  void _startResendCooldown() {
    _resendCooldown = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) {
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Two-Factor Authentication',
          style: FontUtils.headline(
            context: context,
            color: AppColors.lightOnSurface,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
          onPressed: widget.onCancel,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 48.h),
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: _buildCodeInput(),
                        );
                      },
                    ),
                    SizedBox(height: 24.h),
                    if (_showBackupCodeInput) ...[
                      _buildBackupCodeInfo(),
                      SizedBox(height: 24.h),
                    ],
                    _buildTimeRemaining(),
                    if (_errorMessage != null) ...[
                      SizedBox(height: 16.h),
                      _buildErrorMessage(),
                    ],
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.security_rounded,
            size: IconUtils.getProtectedSize(
              context,
              targetSize: 48.0,
              minSize: 36.0,
            ),
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'Verify Your Identity',
          style: FontUtils.display(
            context: context,
            color: AppColors.lightOnSurface,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          _showBackupCodeInput 
              ? 'Enter one of your backup codes'
              : 'Enter the 6-digit code from your authenticator app',
          style: FontUtils.body(
            context: context,
            color: AppColors.lightOnSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4.h),
        Text(
          widget.userEmail,
          style: FontUtils.body(
            context: context,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _codeController,
            focusNode: _codeFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: _showBackupCodeInput ? 8 : 6,
            style: FontUtils.display(
              context: context,
              color: AppColors.lightOnSurface,
            ),
            decoration: InputDecoration(
              hintText: _showBackupCodeInput ? '00000000' : '000000',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.lightBackground,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) {
              setState(() {
                _errorMessage = null;
              });
              
              final expectedLength = _showBackupCodeInput ? 8 : 6;
              if (value.length == expectedLength) {
                _verifyCode();
              }
            },
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _showBackupCodeInput ? _switchToTOTP : _switchToBackupCode,
                child: Text(
                  _showBackupCodeInput ? 'Use authenticator app' : 'Use backup code',
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_resendCooldown > 0)
                Text(
                  'Resend in ${_resendCooldown}s',
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                )
              else
                TextButton(
                  onPressed: _resendCode,
                  child: Text(
                    'Resend code',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCodeInfo() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Each backup code can only be used once. Make sure to keep your remaining codes safe.',
              style: FontUtils.caption(
                context: context,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRemaining() {
    if (_showBackupCodeInput) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_rounded,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
            color: AppColors.primary,
          ),
          SizedBox(width: 8.w),
          Text(
            'Code refreshes in ${_timeRemaining}s',
            style: FontUtils.caption(
              context: context,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: FontUtils.caption(
                context: context,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isVerifying 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Verifying...',
                        style: FontUtils.body(
                          context: context,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Verify Code',
                    style: FontUtils.body(
                      context: context,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Cancel',
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_attemptCount > 0) ...[
          SizedBox(height: 12.h),
          Text(
            'Attempts remaining: ${_maxAttempts - _attemptCount}',
            style: FontUtils.caption(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    
    if (_showBackupCodeInput && code.length != 8) {
      _setError('Please enter an 8-digit backup code');
      return;
    } else if (!_showBackupCodeInput && code.length != 6) {
      _setError('Please enter a 6-digit code');
      return;
    }

    if (_attemptCount >= _maxAttempts) {
      _setError('Too many failed attempts. Please try again later.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await _twoFactorService.verifyCode(
        code,
        isBackupCode: _showBackupCodeInput,
      );
      
      if (isValid) {
        widget.onVerificationComplete(true);
      } else {
        _attemptCount++;
        _shakeController.forward().then((_) {
          _shakeController.reverse();
        });
        
        if (_attemptCount >= _maxAttempts) {
          _setError('Too many failed attempts. Account temporarily locked.');
          // In a real app, you might want to implement account lockout
          Future.delayed(const Duration(seconds: 2), () {
            widget.onVerificationComplete(false);
          });
        } else {
          _setError(
            _showBackupCodeInput 
                ? 'Invalid backup code. Please try again.'
                : 'Invalid code. Please try again.'
          );
        }
        
        _codeController.clear();
        _codeFocusNode.requestFocus();
      }
    } catch (e) {
      _setError('Verification failed: $e');
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _switchToBackupCode() {
    setState(() {
      _showBackupCodeInput = true;
      _errorMessage = null;
    });
    _codeController.clear();
    _codeFocusNode.requestFocus();
  }

  void _switchToTOTP() {
    setState(() {
      _showBackupCodeInput = false;
      _errorMessage = null;
    });
    _codeController.clear();
    _codeFocusNode.requestFocus();
  }

  void _resendCode() {
    // In a real implementation, this might trigger sending a new code
    // For TOTP, this is mainly for user feedback
    _startResendCooldown();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Check your authenticator app for the latest code',
          style: FontUtils.body(
            context: context,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }
}
