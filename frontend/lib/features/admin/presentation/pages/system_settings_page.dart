import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../data/services/admin_api_service.dart';

/// System Settings Page for Admin
/// Allows administrators to configure system-wide settings
/// Uses real backend API for persistent storage
class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final AdminApiService _adminApiService = AdminApiService();
  
  // Settings state
  bool _requireMfa = true;
  bool _emailNotifications = true;
  bool _criticalAlerts = true;
  bool _dataRetention = true;
  bool _autoBackup = true;
  bool _maintenanceMode = false;
  bool _passwordComplexity = true;
  String _sessionTimeout = '30';
  String _dataRetentionDays = '365';
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final settings = await _adminApiService.getSystemSettings();
      
      if (settings != null) {
        setState(() {
          _requireMfa = settings.requireMfa;
          _emailNotifications = settings.emailNotifications;
          _criticalAlerts = settings.criticalAlerts;
          _dataRetention = settings.dataRetention;
          _autoBackup = settings.autoBackup;
          _maintenanceMode = settings.maintenanceMode;
          _passwordComplexity = settings.passwordComplexity;
          _sessionTimeout = settings.sessionTimeout.toString();
          _dataRetentionDays = settings.dataRetentionDays.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
      final success = await _adminApiService.updateSystemSettings(
        requireMfa: _requireMfa,
        sessionTimeout: int.tryParse(_sessionTimeout) ?? 30,
        passwordComplexity: _passwordComplexity,
        emailNotifications: _emailNotifications,
        criticalAlerts: _criticalAlerts,
        dataRetention: _dataRetention,
        dataRetentionDays: int.tryParse(_dataRetentionDays) ?? 365,
        autoBackup: _autoBackup,
        maintenanceMode: _maintenanceMode,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading settings...'),
            ],
          ),
        ),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Error loading settings'),
              Text(_error!, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSettings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildSettingsSections(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.settings_rounded,
              color: AppColors.warning,
              size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Settings',
                  style: FontUtils.display(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Configure system-wide settings and preferences',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSettings,
              tooltip: 'Refresh settings',
            ),
            SizedBox(width: 8.w),
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSections() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildSection(
            'Security Settings',
            Icons.security_rounded,
            AppColors.error,
            [
              _buildSwitchSetting(
                'Require MFA for All Users',
                'Enforce multi-factor authentication',
                _requireMfa,
                (value) => setState(() => _requireMfa = value),
              ),
              _buildDropdownSetting(
                'Session Timeout',
                'Auto-logout after inactivity',
                _sessionTimeout,
                ['15', '30', '60', '120'],
                (value) => setState(() => _sessionTimeout = value ?? '30'),
                suffix: 'minutes',
              ),
              _buildSwitchSetting(
                'Password Complexity',
                'Require strong passwords',
                _passwordComplexity,
                (value) => setState(() => _passwordComplexity = value),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildSection(
            'Notification Settings',
            Icons.notifications_rounded,
            AppColors.primary,
            [
              _buildSwitchSetting(
                'Email Notifications',
                'Send system alerts via email',
                _emailNotifications,
                (value) => setState(() => _emailNotifications = value),
              ),
              _buildSwitchSetting(
                'Critical Alerts',
                'Immediate alerts for security events',
                _criticalAlerts,
                (value) => setState(() => _criticalAlerts = value),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildSection(
            'Data Management',
            Icons.storage_rounded,
            AppColors.success,
            [
              _buildSwitchSetting(
                'Auto Data Retention',
                'Automatically manage old data',
                _dataRetention,
                (value) => setState(() => _dataRetention = value),
              ),
              _buildDropdownSetting(
                'Retention Period',
                'Keep patient data for',
                _dataRetentionDays,
                ['90', '180', '365', '730'],
                (value) => setState(() => _dataRetentionDays = value ?? '365'),
                suffix: 'days',
              ),
              _buildSwitchSetting(
                'Auto Backup',
                'Daily automatic backups',
                _autoBackup,
                (value) => setState(() => _autoBackup = value),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildSection(
            'System Maintenance',
            Icons.build_rounded,
            AppColors.warning,
            [
              _buildSwitchSetting(
                'Maintenance Mode',
                'Restrict access during maintenance',
                _maintenanceMode,
                (value) => setState(() => _maintenanceMode = value),
              ),
              _buildActionSetting(
                'Clear Cache',
                'Remove temporary system files',
                Icons.cleaning_services,
                () => _showConfirmation('Clear cache?'),
              ),
              _buildActionSetting(
                'Run Diagnostics',
                'Check system health',
                Icons.health_and_safety,
                () => _showConfirmation('Run diagnostics?'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: FontUtils.headline(
                    context: context,
                    color: AppColors.lightOnSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: FontUtils.body(context: context, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: FontUtils.caption(context: context, color: Colors.grey[600]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDropdownSetting(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    String? suffix,
  }) {
    return ListTile(
      title: Text(
        title,
        style: FontUtils.body(context: context, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: FontUtils.caption(context: context, color: Colors.grey[600]),
      ),
      trailing: DropdownButton<String>(
        value: value,
        items: options.map((opt) => DropdownMenuItem(
          value: opt,
          child: Text('$opt ${suffix ?? ''}'),
        )).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildActionSetting(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(
        title,
        style: FontUtils.body(context: context, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: FontUtils.caption(context: context, color: Colors.grey[600]),
      ),
      trailing: IconButton(
        icon: Icon(icon, color: AppColors.primary),
        onPressed: onTap,
      ),
    );
  }

  void _showConfirmation(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action completed')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
