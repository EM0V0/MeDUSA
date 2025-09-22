import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/two_factor_auth_service.dart';

class TwoFactorSetupPage extends StatefulWidget {
  final String userEmail;
  final VoidCallback? onSetupComplete;
  final VoidCallback? onCancel;

  const TwoFactorSetupPage({
    super.key,
    required this.userEmail,
    this.onSetupComplete,
    this.onCancel,
  });

  @override
  State<TwoFactorSetupPage> createState() => _TwoFactorSetupPageState();
}

class _TwoFactorSetupPageState extends State<TwoFactorSetupPage> with TickerProviderStateMixin {
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  final TextEditingController _codeController = TextEditingController();
  final PageController _pageController = PageController();
  
  late TabController _tabController;
  Timer? _codeTimer;
  
  String? _secret;
  String? _qrCodeUrl;
  List<String> _backupCodes = [];
  bool _isVerifying = false;
  String? _errorMessage;
  int _currentStep = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeSetup();
    _startCodeTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pageController.dispose();
    _tabController.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeSetup() async {
    try {
      await _twoFactorService.initialize();
      _secret = await _twoFactorService.generateSecret();
      _qrCodeUrl = _twoFactorService.getQRCodeUrl(widget.userEmail);
      _backupCodes = _twoFactorService.backupCodes;
      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize 2FA setup: $e';
      });
    }
  }

  void _startCodeTimer() {
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Two-Factor Authentication Setup',
          style: FontUtils.headline(
            context: context,
            color: AppColors.lightOnSurface,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
          onPressed: widget.onCancel,
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildInstructionsStep(),
                _buildQRCodeStep(),
                _buildVerificationStep(),
                _buildBackupCodesStep(),
                _buildCompletionStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(20.w),
      color: AppColors.lightBackground,
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index <= _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isActive 
                            ? AppColors.primary 
                            : AppColors.lightDivider,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  if (index < 4) SizedBox(width: 8.w),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInstructionsStep() {
    final instructions = _twoFactorService.getSetupInstructions();
    
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Step 1: Get Ready',
            'Before we begin, make sure you have an authenticator app installed',
            Icons.info_outline_rounded,
            AppColors.primary,
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: ListView.builder(
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.lightDivider,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    instructions[index],
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24.h),
          _buildNavigationButtons(
            onNext: () => _nextStep(),
            nextText: 'Get Started',
            showPrevious: false,
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeStep() {
    if (_qrCodeUrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          _buildStepHeader(
            'Step 2: Scan QR Code',
            'Use your authenticator app to scan this QR code',
            Icons.qr_code_rounded,
            AppColors.success,
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _qrCodeUrl!,
                          version: QrVersions.auto,
                          size: 200.w,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Can\'t scan? Enter this code manually:',
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _secret ?? '',
                                  style: FontUtils.caption(
                                    context: context,
                                    color: AppColors.lightOnSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copySecret(),
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  _buildCurrentCodeDisplay(),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildNavigationButtons(
            onPrevious: () => _previousStep(),
            onNext: () => _nextStep(),
            nextText: 'I\'ve Scanned It',
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          _buildStepHeader(
            'Step 3: Verify Setup',
            'Enter the 6-digit code from your authenticator app',
            Icons.verified_user_rounded,
            AppColors.warning,
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
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
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: FontUtils.display(
                          context: context,
                          color: AppColors.lightOnSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.length == 6) {
                            _verifyCode();
                          }
                        },
                      ),
                      if (_errorMessage != null) ...[
                        SizedBox(height: 16.h),
                        Container(
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
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                _buildCurrentCodeDisplay(),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          _buildNavigationButtons(
            onPrevious: () => _previousStep(),
            onNext: _isVerifying ? null : () => _verifyCode(),
            nextText: _isVerifying ? 'Verifying...' : 'Verify Code',
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCodesStep() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          _buildStepHeader(
            'Step 4: Save Backup Codes',
            'Store these codes safely. You can use them if you lose access to your authenticator app',
            Icons.backup_rounded,
            AppColors.error,
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20.w),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Backup Codes',
                        style: FontUtils.headline(
                          context: context,
                          color: AppColors.lightOnSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: _copyBackupCodes,
                        icon: Icon(
                          Icons.copy_rounded,
                          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ResponsiveRowColumn(
                      layout: ResponsiveBreakpoints.of(context).smallerThan(TABLET) 
                          ? ResponsiveRowColumnType.COLUMN 
                          : ResponsiveRowColumnType.ROW,
                      rowSpacing: 16.w,
                      columnSpacing: 8.h,
                      children: [
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          child: _buildBackupCodesColumn(_backupCodes.take(5).toList()),
                        ),
                        ResponsiveRowColumnItem(
                          rowFlex: 1,
                          child: _buildBackupCodesColumn(_backupCodes.skip(5).toList()),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: AppColors.warning,
                          size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Each backup code can only be used once. Store them in a secure location.',
                            style: FontUtils.caption(
                              context: context,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildNavigationButtons(
            onPrevious: () => _previousStep(),
            onNext: () => _nextStep(),
            nextText: 'I\'ve Saved Them',
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCodesColumn(List<String> codes) {
    return Column(
      children: codes.map((code) => Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          code,
          style: FontUtils.body(
            context: context,
            color: AppColors.lightOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCompletionStep() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: IconUtils.getProtectedSize(
                context,
                targetSize: 64.0,
                minSize: 48.0,
              ),
              color: AppColors.success,
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            'Two-Factor Authentication Enabled!',
            style: FontUtils.display(
              context: context,
              color: AppColors.lightOnSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            'Your account is now protected with 2FA. You\'ll need to enter a code from your authenticator app each time you log in.',
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 48.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSetupComplete?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Complete Setup',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            icon,
            color: color,
            size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FontUtils.title(
                  context: context,
                  color: AppColors.lightOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentCodeDisplay() {
    if (_twoFactorService.isSetup) {
      final currentCode = _twoFactorService.getCurrentCode();
      final timeRemaining = _twoFactorService.getTimeRemaining();
      
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(
              'Current Code (for testing)',
              style: FontUtils.caption(
                context: context,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              currentCode,
              style: FontUtils.title(
                context: context,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Refreshes in ${timeRemaining}s',
              style: FontUtils.caption(
                context: context,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNavigationButtons({
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    String nextText = 'Next',
    bool showPrevious = true,
  }) {
    return Row(
      children: [
        if (showPrevious) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onPrevious,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Previous',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
        ],
        Expanded(
          flex: showPrevious ? 1 : 2,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              nextText,
              style: FontUtils.body(
                context: context,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await _twoFactorService.verifyCode(code);
      
      if (isValid) {
        await _twoFactorService.enable();
        _nextStep(); // Go to backup codes step
      } else {
        setState(() {
          _errorMessage = 'Invalid code. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _copySecret() {
    if (_secret != null) {
      Clipboard.setData(ClipboardData(text: _secret!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Secret copied to clipboard',
            style: FontUtils.body(
              context: context,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _copyBackupCodes() {
    final codesText = _backupCodes.join('\n');
    Clipboard.setData(ClipboardData(text: codesText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Backup codes copied to clipboard',
          style: FontUtils.body(
            context: context,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
