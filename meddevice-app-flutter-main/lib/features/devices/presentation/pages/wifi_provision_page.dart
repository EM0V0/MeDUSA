import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/winble_wifi_helper_service.dart';

/// WiFi Provisioning Page
/// 
/// Provisions WiFi credentials to a pre-scanned MeDUSA Raspberry Pi device
/// via Bluetooth Low Energy (BLE) with LESC pairing using WinRT native APIs.
/// 
/// This page:
/// 1. Accepts a pre-scanned BluetoothDevice (NO redundant scanning)
/// 2. Uses Windows native pairing dialog for PIN input (ProvidePin mode)
/// 3. Provisions WiFi credentials after successful pairing
class WiFiProvisionPage extends StatefulWidget {
  final BluetoothDevice device;

  const WiFiProvisionPage({
    super.key,
    required this.device,
  });

  @override
  State<WiFiProvisionPage> createState() => _WiFiProvisionPageState();
}

class _WiFiProvisionPageState extends State<WiFiProvisionPage> {
  final WinBleWiFiHelperService _wifiService = WinBleWiFiHelperService();
  
  // Get device address from FlutterBluePlus device
  String get _deviceAddress => widget.device.remoteId.str;
  
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  
  StreamSubscription? _statusSubscription;
  
  String _statusMessage = 'Ready to connect';
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isPaired = false;
  bool _isProvisioning = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _setupPairingCallback();
    _setupStatusListener();
  }

  /// Setup the PIN request callback
  /// This will be called when C++ plugin requests PIN input
  void _setupPairingCallback() {
    debugPrint('[WiFiProvision] Setting up PIN request callback');
    _wifiService.setOnPinRequested((context) {
      debugPrint('[WiFiProvision] PIN requested by C++ - showing dialog');
      _showPinInputDialog();
    });
  }

  /// Setup listener for WiFi service status updates
  void _setupStatusListener() {
    _statusSubscription = _wifiService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    _statusSubscription?.cancel();
    _wifiService.dispose();
    super.dispose();
  }

  /// Show PIN input dialog to user
  /// This is called by PairingManager when pairing is required
  /// Returns the PIN entered by user, or null if cancelled
  Future<String?> _showPinInputDialog() async {
    debugPrint('[WiFiProvision] Showing PIN input dialog');
    
    final pinController = TextEditingController();
    String? result;

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.security_rounded,
              color: AppColors.primary,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Bluetooth Pairing Required',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Device: ${widget.device.platformName}',
                        style: FontUtils.body(
                          context: context,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Step 1: Check your Raspberry Pi',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Your Raspberry Pi should display a 6-digit PIN code on its screen or terminal. Look for a message like "PIN: 123456".',
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Step 2: Enter the PIN below',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: pinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8.0,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'PIN Code',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    letterSpacing: 8.0,
                    color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  prefixIcon: const Icon(Icons.pin_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.primary.withValues(alpha: 0.05),
                ),
                onSubmitted: (value) {
                  if (value.length == 6) {
                    result = value;
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Note: If Windows shows a Bluetooth pairing dialog, enter the same PIN code there as well to complete pairing.',
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              result = null;
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Cancel',
              style: FontUtils.body(
                context: context,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (pinController.text.length == 6) {
                result = pinController.text;
                
                // Submit PIN to C++ plugin BEFORE closing dialog
                debugPrint('[WiFiProvision] Submitting PIN to C++ plugin: $result');
                try {
                  await _wifiService.submitPinToPlugin(result!);
                  debugPrint('[WiFiProvision] ✅ PIN submitted successfully');
                  
                  // Only close dialog AFTER PIN is submitted
                  Navigator.of(dialogContext).pop(result);
                } catch (e) {
                  debugPrint('[WiFiProvision] ❌ Error submitting PIN: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error submitting PIN: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  // Don't close dialog on error - let user try again
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a complete 6-digit PIN'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            ),
            label: Text(
              'Continue Pairing',
              style: FontUtils.body(
                context: context,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    debugPrint('[WiFiProvision] PIN dialog closed, PIN: ${result != null ? "provided (${result!.length} digits)" : "cancelled"}');
    return result;
  }

  /// Connect and pair with the device using WinBle + WinRT APIs
  Future<void> _connectAndPair() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Preparing to pair...';
    });

    try {
      debugPrint('[WiFiProvision] Starting connection and pairing...');
      debugPrint('[WiFiProvision] Device address: $_deviceAddress');
      
      // Show PIN dialog FIRST - it will wait for user input
      // and submit the PIN to C++ when ready
      debugPrint('[WiFiProvision] Showing PIN input dialog preemptively');
      setState(() {
        _statusMessage = 'Please enter PIN from Raspberry Pi OLED screen...';
      });
      
      // Show the dialog and start pairing in parallel
      final pinFuture = _showPinInputDialog();
      
      setState(() {
        _statusMessage = 'Initiating pairing (waiting for PIN)...';
      });
      
      // Start the pairing process - it will wait for PIN input
      final pairingFuture = _wifiService.connectAndPair(_deviceAddress);
      
      // Wait for PIN dialog to complete (user enters PIN and submits)
      final pin = await pinFuture;
      
      if (pin == null) {
        debugPrint('[WiFiProvision] ❌ PIN dialog cancelled by user');
        setState(() {
          _statusMessage = 'Pairing cancelled';
          _isConnecting = false;
        });
        return;
      }
      
      debugPrint('[WiFiProvision] ✅ User entered PIN, waiting for pairing to complete...');
      setState(() {
        _statusMessage = 'Pairing with device...';
      });
      
      // Wait for pairing to complete
      final success = await pairingFuture;

      if (success) {
        setState(() {
          _isConnected = true;
          _isPaired = true;
          _statusMessage = 'Connected and paired successfully!';
        });
        debugPrint('[WiFiProvision] ✓ Connection and pairing successful');
      } else {
        setState(() {
          _statusMessage = _wifiService.lastError ?? 'Connection failed';
        });
        debugPrint('[WiFiProvision] ✗ Connection or pairing failed');
        
        // Show error dialog
        _showErrorDialog(_wifiService.lastError ?? 'Failed to connect or pair with device');
      }
    } catch (e) {
      debugPrint('[WiFiProvision] Error during connect/pair: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// Unpair the device to allow fresh pairing with new PIN
  Future<void> _unpairDevice() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device?'),
        content: const Text(
          'This will remove the current pairing. You\'ll need to enter the PIN again from the Raspberry Pi OLED display when reconnecting.\n\nThis is useful if:\n• You want to re-enter the PIN\n• Pi is not generating a new PIN code',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _statusMessage = 'Unpairing device...';
    });

    try {
      debugPrint('[WiFiProvision] Requesting unpair for $_deviceAddress');
      final success = await _wifiService.unpairDevice(_deviceAddress);

      if (success) {
        setState(() {
          _isConnected = false;
          _isPaired = false;
          _statusMessage = 'Device unpaired successfully. You can now connect again with a fresh PIN.';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Device unpaired. Connect again to enter new PIN.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
        }
        
        debugPrint('[WiFiProvision] ✓ Unpair successful');
      } else {
        setState(() {
          _statusMessage = 'Failed to unpair device';
        });
        _showErrorDialog('Could not unpair device. Try removing it manually from Windows Bluetooth settings.');
        debugPrint('[WiFiProvision] ✗ Unpair failed');
      }
    } catch (e) {
      debugPrint('[WiFiProvision] Error during unpair: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
      _showErrorDialog('Error unpairing: $e');
    }
  }

  /// Provision WiFi credentials to the device
  Future<void> _provisionWiFi() async {
    // Validate inputs
    if (_ssidController.text.trim().isEmpty) {
      _showErrorDialog('Please enter WiFi SSID');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showErrorDialog('Please enter WiFi password');
      return;
    }

    if (!_isConnected || !_isPaired) {
      _showErrorDialog('Please connect and pair with device first');
      return;
    }

    setState(() {
      _isProvisioning = true;
      _statusMessage = 'Provisioning WiFi credentials...';
    });

    try {
      debugPrint('[WiFiProvision] Starting WiFi provisioning...');
      debugPrint('[WiFiProvision] SSID: ${_ssidController.text}');
      
      // Provision WiFi credentials (write SSID, PSK, send CONNECT command)
      // No PIN needed here - pairing was already done in _connectAndPair()
      final success = await _wifiService.provisionWiFiCredentials(
        _ssidController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        setState(() {
          _statusMessage = 'WiFi provisioning successful!';
        });
        debugPrint('[WiFiProvision] ✓ WiFi provisioning completed');
        
        // Show success dialog
        _showSuccessDialog();
      } else {
        setState(() {
          _statusMessage = _wifiService.lastError ?? 'Provisioning failed';
        });
        debugPrint('[WiFiProvision] ✗ WiFi provisioning failed');
        
        _showErrorDialog(_wifiService.lastError ?? 'Failed to provision WiFi credentials');
      }
    } catch (e) {
      debugPrint('[WiFiProvision] Error during provisioning: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isProvisioning = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            SizedBox(width: 12.w),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            SizedBox(width: 12.w),
            const Text('Success'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WiFi credentials have been successfully provisioned to your Raspberry Pi device!',
              style: FontUtils.body(context: context),
            ),
            SizedBox(height: 16.h),
            Text(
              'The device will now connect to your WiFi network.',
              style: FontUtils.caption(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/device-scan'); // Return to device scan
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        border: const Border(
          bottom: BorderSide(
            color: AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/device-scan'),
                color: AppColors.lightOnSurface,
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.wifi_rounded,
                  color: AppColors.primary,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WiFi Provisioning',
                      style: FontUtils.display(
                        context: context,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.device.platformName,
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    IconData statusIcon;
    
    if (_isConnecting || _isProvisioning) {
      statusColor = AppColors.warning;
      statusIcon = Icons.sync_rounded;
    } else if (_isPaired && _isConnected) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (_isConnected) {
      statusColor = AppColors.primary;
      statusIcon = Icons.bluetooth_connected_rounded;
    } else {
      statusColor = AppColors.lightOnSurfaceVariant;
      statusIcon = Icons.bluetooth_rounded;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (_isConnecting || _isProvisioning)
            SizedBox(
              width: 20.w,
              height: 20.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
          else
            Icon(
              statusIcon,
              color: statusColor,
              size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
            ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _statusMessage,
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.all(16.w),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionCard(),
            SizedBox(height: 16.h),
            _buildWiFiCredentialsCard(),
            SizedBox(height: 16.h),
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bluetooth_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Step 1: Connect & Pair',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'Connect to the device and complete secure pairing with PIN code.',
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isConnecting || _isConnected) ? null : _connectAndPair,
              icon: Icon(
                _isConnected ? Icons.check_circle_rounded : Icons.bluetooth_searching_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              label: Text(
                _isConnected ? 'Connected & Paired' : 'Connect & Pair',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? AppColors.success : AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                disabledBackgroundColor: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ),
          // Add Unpair button if device shows as already paired
          if (_isConnected || _isPaired) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProvisioning ? null : _unpairDevice,
                icon: Icon(
                  Icons.link_off_rounded,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
                  color: AppColors.warning,
                ),
                label: Text(
                  'Unpair Device (to re-enter PIN)',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning, width: 1.5),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWiFiCredentialsCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Step 2: WiFi Credentials',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _ssidController,
            enabled: _isConnected && !_isProvisioning,
            decoration: InputDecoration(
              labelText: 'WiFi Network Name (SSID)',
              hintText: 'Enter your WiFi network name',
              prefixIcon: const Icon(Icons.wifi_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _passwordController,
            enabled: _isConnected && !_isProvisioning,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'WiFi Password',
              hintText: 'Enter your WiFi password',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isConnected && !_isProvisioning) ? _provisionWiFi : null,
              icon: Icon(
                Icons.send_rounded,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              label: Text(
                'Provision WiFi',
                style: FontUtils.body(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                disabledBackgroundColor: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
              ),
              SizedBox(width: 12.w),
              Text(
                'Instructions',
                style: FontUtils.headline(
                  context: context,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInstructionItem('1', 'Click "Connect & Pair" button'),
          _buildInstructionItem('2', 'Enter the 6-digit PIN shown on your Raspberry Pi'),
          _buildInstructionItem('3', 'Enter your WiFi network credentials'),
          _buildInstructionItem('4', 'Click "Provision WiFi" to complete setup'),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'The PIN code will be displayed on your Raspberry Pi device. Make sure your device is powered on and ready.',
                    style: FontUtils.caption(
                      context: context,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: FontUtils.caption(
                  context: context,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                text,
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

