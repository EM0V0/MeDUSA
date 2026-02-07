import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../services/security_education_service.dart';
import 'security_feature_toggle.dart';
import 'security_log_panel.dart';

/// Security Lab Page - Comprehensive security testing and education interface
/// 
/// This page provides:
/// - All security feature toggles in one place
/// - Live demonstrations of each feature
/// - Attack simulators to test security controls
/// - Real-time security event logging
class SecurityLabPage extends StatefulWidget {
  const SecurityLabPage({super.key});

  @override
  State<SecurityLabPage> createState() => _SecurityLabPageState();
}

class _SecurityLabPageState extends State<SecurityLabPage>
    with SingleTickerProviderStateMixin {
  final SecurityEducationService _service = SecurityEducationService();
  late TabController _tabController;
  
  SecurityConfig? _config;
  bool _isLoading = true;
  String? _error;
  
  // Demo results
  PasswordHashingDemo? _passwordDemo;
  JwtTokenDemo? _jwtDemo;
  ReplayProtectionDemo? _replayDemo;
  
  // Current mode
  String _currentMode = 'secure';
  
  // Security log entries
  final List<SecurityLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = await _service.getSecurityConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _currentMode = config?.mode ?? 'secure';
          _isLoading = false;
        });
        _addLog('SYSTEM', 'Security Lab loaded - Mode: $_currentMode', SecurityLogLevel.info);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _addLog(String eventType, String message, SecurityLogLevel level) {
    setState(() {
      _logs.insert(0, SecurityLogEntry(
        timestamp: DateTime.now(),
        eventType: eventType,
        message: message,
        level: level,
      ));
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _switchMode(String mode) async {
    _addLog('MODE', 'Switching to $mode mode...', SecurityLogLevel.info);
    
    final result = await _service.setSecurityMode(mode);
    if (result != null) {
      setState(() => _currentMode = mode);
      _addLog('MODE', 'Mode changed to: $mode', SecurityLogLevel.success);
      await _loadConfig(); // Reload to get updated feature states
    } else {
      _addLog('MODE', 'Failed to switch mode', SecurityLogLevel.error);
    }
  }

  Future<void> _toggleFeature(String featureId, bool enabled) async {
    final featureName = _config?.features
        .firstWhere((f) => f.id == featureId, orElse: () => SecurityFeature(
          id: featureId, name: featureId, description: '', enabled: true,
          category: '', riskIfDisabled: '', fdaRequirement: '',
          educationalExplanation: '', codeLocation: '',
        ))
        .name ?? featureId;
    
    _addLog('TOGGLE', 'Toggling $featureName to ${enabled ? "ON" : "OFF"}...', SecurityLogLevel.info);
    
    final result = await _service.toggleSecurityFeature(featureId, enabled);
    if (result != null) {
      await _loadConfig();
      _addLog(
        'TOGGLE', 
        '$featureName is now ${enabled ? "ENABLED ✅" : "DISABLED ⚠️"}',
        enabled ? SecurityLogLevel.success : SecurityLogLevel.warning,
      );
    } else {
      _addLog('TOGGLE', 'Failed to toggle $featureName', SecurityLogLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('🔬 Security Lab'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Mode indicator
          Container(
            margin: EdgeInsets.only(right: 8.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _getModeColor(_currentMode).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getModeIcon(_currentMode),
                  color: _getModeColor(_currentMode),
                  size: 16.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  _currentMode.toUpperCase(),
                  style: TextStyle(
                    color: _getModeColor(_currentMode),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.toggle_on), text: 'Features'),
            Tab(icon: Icon(Icons.science), text: 'Demos'),
            Tab(icon: Icon(Icons.bug_report), text: 'Attacks'),
            Tab(icon: Icon(Icons.terminal), text: 'Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    // Mode switcher bar
                    _buildModeSwitcherBar(),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeaturesTab(),
                          _buildDemosTab(),
                          _buildAttacksTab(),
                          _buildLogsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildModeSwitcherBar() {
    return Container(
      padding: EdgeInsets.all(12.w),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Text(
            'Security Mode:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'secure',
                  label: Text('🔒 Secure', style: TextStyle(fontSize: 12.sp)),
                ),
                ButtonSegment(
                  value: 'educational',
                  label: Text('📚 Educational', style: TextStyle(fontSize: 12.sp)),
                ),
                ButtonSegment(
                  value: 'insecure',
                  label: Text('⚠️ Insecure', style: TextStyle(fontSize: 12.sp)),
                ),
              ],
              selected: {_currentMode},
              onSelectionChanged: (selected) => _switchMode(selected.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text('Error loading security config', style: TextStyle(fontSize: 18.sp)),
          SizedBox(height: 8.h),
          Text(_error ?? 'Unknown error', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadConfig,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    if (_config == null) return const Center(child: Text('No config'));
    
    final categories = _config!.categories;
    
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final features = _config!.getFeaturesByCategory(category);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${features.where((f) => f.enabled).length}/${features.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            
            // Features in category
            ...features.map((feature) => SecurityFeatureToggle(
              featureId: feature.id,
              featureName: feature.name,
              description: feature.description,
              secureDescription: feature.educationalExplanation.split('\n').take(3).join('\n'),
              insecureRisk: feature.riskIfDisabled,
              isEnabled: feature.enabled,
              isReadOnly: _currentMode == 'secure',
              onToggle: (enabled) => _toggleFeature(feature.id, enabled),
              codeLocation: feature.codeLocation,
              fdaRequirement: feature.fdaRequirement,
              icon: _getFeatureIcon(feature.id),
            )),
            
            SizedBox(height: 16.h),
          ],
        );
      },
    );
  }

  Widget _buildDemosTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Password Hashing Demo
          _buildDemoCard(
            title: '🔐 Password Hashing Demo',
            description: 'See how Argon2id hashes your password',
            onRun: _runPasswordHashingDemo,
            result: _passwordDemo != null ? _buildPasswordDemoResult() : null,
          ),
          
          SizedBox(height: 16.h),
          
          // JWT Token Demo
          _buildDemoCard(
            title: '🎟️ JWT Token Demo',
            description: 'Inspect the structure of your authentication token',
            onRun: _runJwtDemo,
            result: _jwtDemo != null ? _buildJwtDemoResult() : null,
          ),
          
          SizedBox(height: 16.h),
          
          // Replay Protection Demo
          _buildDemoCard(
            title: '🔄 Replay Protection Demo',
            description: 'See how nonces prevent replay attacks',
            onRun: _runReplayDemo,
            result: _replayDemo != null ? _buildReplayDemoResult() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAttacksTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          Container(
            padding: EdgeInsets.all(12.w),
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'These attack simulations are for educational purposes only. '
                    'They demonstrate vulnerabilities when security features are disabled.',
                    style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
          
          // Brute Force Attack Simulator
          _buildAttackCard(
            title: '🔨 Brute Force Attack',
            description: 'Simulate rapid login attempts to test rate limiting',
            attackType: 'brute_force',
            relatedFeature: 'rate_limiting',
          ),
          
          SizedBox(height: 12.h),
          
          // Weak Password Attack
          _buildAttackCard(
            title: '🔑 Weak Password Test',
            description: 'Try to register with a weak password like "123"',
            attackType: 'weak_password',
            relatedFeature: 'password_complexity',
          ),
          
          SizedBox(height: 12.h),
          
          // Replay Attack Simulator
          _buildAttackCard(
            title: '🔄 Replay Attack',
            description: 'Attempt to replay a captured request',
            attackType: 'replay',
            relatedFeature: 'replay_protection',
          ),
          
          SizedBox(height: 12.h),
          
          // MFA Bypass
          _buildAttackCard(
            title: '📱 MFA Bypass Test',
            description: 'Try to login without MFA code',
            attackType: 'mfa_bypass',
            relatedFeature: 'mfa_totp',
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        // Controls
        Container(
          padding: EdgeInsets.all(12.w),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Text(
                'Security Events (${_logs.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _logs.clear()),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        
        // Log entries
        Expanded(
          child: _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 48.sp, color: Colors.grey),
                      SizedBox(height: 8.h),
                      Text(
                        'No security events yet',
                        style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Toggle features or run demos to see events',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(8.w),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => _buildLogEntry(_logs[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(SecurityLogEntry log) {
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: log.level.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: log.level.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11.sp,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(width: 8.w),
          Icon(log.level.icon, color: log.level.color, size: 14.sp),
          SizedBox(width: 4.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: log.level.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              log.eventType,
              style: TextStyle(
                color: log.level.color,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String description,
    required VoidCallback onRun,
    Widget? result,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
            SizedBox(height: 4.h),
            Text(description, style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: onRun,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Demo'),
            ),
            if (result != null) ...[
              SizedBox(height: 12.h),
              result,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttackCard({
    required String title,
    required String description,
    required String attackType,
    required String relatedFeature,
  }) {
    final feature = _config?.features.firstWhere(
      (f) => f.id == relatedFeature,
      orElse: () => SecurityFeature(
        id: relatedFeature, name: relatedFeature, description: '', enabled: true,
        category: '', riskIfDisabled: '', fdaRequirement: '',
        educationalExplanation: '', codeLocation: '',
      ),
    );
    final isProtected = feature?.enabled ?? true;

    return Card(
      color: isProtected ? null : Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isProtected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    isProtected ? 'PROTECTED' : 'VULNERABLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(description, style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
            SizedBox(height: 8.h),
            Text(
              'Related Feature: ${feature?.name ?? relatedFeature}',
              style: TextStyle(fontSize: 11.sp, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () => _simulateAttack(attackType, isProtected),
              style: ElevatedButton.styleFrom(
                backgroundColor: isProtected ? Colors.blue : Colors.orange,
              ),
              icon: const Icon(Icons.bug_report),
              label: Text(isProtected ? 'Test Attack' : 'Exploit Vulnerability'),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateAttack(String attackType, bool isProtected) {
    _addLog('ATTACK', 'Simulating $attackType attack...', SecurityLogLevel.warning);
    
    if (isProtected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addLog('ATTACK', '❌ Attack BLOCKED - security feature active', SecurityLogLevel.success);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Attack blocked! Security feature is active.'),
            backgroundColor: Colors.green,
          ),
        );
      });
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addLog('ATTACK', '⚠️ Attack SUCCEEDED - vulnerability exploited!', SecurityLogLevel.error);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Attack succeeded! Enable the security feature to protect.'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  Widget _buildPasswordDemoResult() {
    if (_passwordDemo == null) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Input: ${_passwordDemo!.inputPassword}', style: const TextStyle(fontFamily: 'monospace')),
          SizedBox(height: 4.h),
          Text('Algorithm: ${_passwordDemo!.algorithm}', style: const TextStyle(fontFamily: 'monospace')),
          SizedBox(height: 4.h),
          Text(
            'Hash: ${_passwordDemo!.hashedOutput.substring(0, 40)}...',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          SizedBox(height: 4.h),
          Text('Hash Length: ${_passwordDemo!.hashLength} chars', style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildJwtDemoResult() {
    if (_jwtDemo == null) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Token Parts:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
          SizedBox(height: 4.h),
          ..._jwtDemo!.tokenParts.entries.map((e) => Text(
            '${e.key}: ${e.value}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          )),
        ],
      ),
    );
  }

  Widget _buildReplayDemoResult() {
    if (_replayDemo == null) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nonce: ${_replayDemo!.generatedNonce.substring(0, 30)}...',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          SizedBox(height: 4.h),
          Text('Format:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
          ..._replayDemo!.nonceFormat.entries.map((e) => Text(
            '  ${e.key}: ${e.value}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          )),
        ],
      ),
    );
  }

  Future<void> _runPasswordHashingDemo() async {
    _addLog('DEMO', 'Running password hashing demo...', SecurityLogLevel.info);
    final result = await _service.demoPasswordHashing();
    if (result != null && mounted) {
      setState(() => _passwordDemo = result);
      _addLog('DEMO', 'Password hashed with ${result.algorithm}', SecurityLogLevel.success);
    }
  }

  Future<void> _runJwtDemo() async {
    _addLog('DEMO', 'Running JWT token demo...', SecurityLogLevel.info);
    final result = await _service.demoJwtToken();
    if (result != null && mounted) {
      setState(() => _jwtDemo = result);
      _addLog('DEMO', 'JWT token structure analyzed', SecurityLogLevel.success);
    }
  }

  Future<void> _runReplayDemo() async {
    _addLog('DEMO', 'Running replay protection demo...', SecurityLogLevel.info);
    final result = await _service.demoReplayProtection();
    if (result != null && mounted) {
      setState(() => _replayDemo = result);
      _addLog('DEMO', 'Nonce generated: ${result.generatedNonce.substring(0, 20)}...', SecurityLogLevel.success);
    }
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'secure':
        return Colors.green;
      case 'educational':
        return Colors.blue;
      case 'insecure':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'secure':
        return Icons.lock;
      case 'educational':
        return Icons.school;
      case 'insecure':
        return Icons.lock_open;
      default:
        return Icons.help;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'authentication':
        return Icons.key;
      case 'authorization':
        return Icons.admin_panel_settings;
      case 'transport security':
        return Icons.security;
      case 'replay protection':
        return Icons.replay;
      case 'audit & logging':
        return Icons.history;
      case 'input validation':
        return Icons.check_circle;
      case 'secure storage':
        return Icons.storage;
      case 'rate limiting':
        return Icons.speed;
      default:
        return Icons.shield;
    }
  }

  IconData _getFeatureIcon(String featureId) {
    switch (featureId) {
      case 'password_hashing':
        return Icons.lock;
      case 'password_complexity':
        return Icons.password;
      case 'jwt_authentication':
        return Icons.token;
      case 'mfa_totp':
        return Icons.phone_android;
      case 'rbac':
        return Icons.groups;
      case 'resource_ownership':
        return Icons.verified_user;
      case 'tls_enforcement':
        return Icons.https;
      case 'replay_protection':
        return Icons.replay;
      case 'audit_logging':
        return Icons.receipt_long;
      case 'input_validation':
        return Icons.check_box;
      case 'secure_storage':
        return Icons.storage;
      case 'rate_limiting':
        return Icons.timer;
      default:
        return Icons.security;
    }
  }
}
