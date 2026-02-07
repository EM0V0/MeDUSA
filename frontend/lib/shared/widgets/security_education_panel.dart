import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../services/security_education_service.dart';

/// Security Education Panel
/// 
/// An interactive panel that displays all security features of MeDUSA
/// with educational explanations, demonstrations, and toggle controls.
/// 
/// This is designed for educational purposes to help users understand
/// medical device cybersecurity concepts.
class SecurityEducationPanel extends StatefulWidget {
  const SecurityEducationPanel({super.key});

  @override
  State<SecurityEducationPanel> createState() => _SecurityEducationPanelState();
}

class _SecurityEducationPanelState extends State<SecurityEducationPanel>
    with SingleTickerProviderStateMixin {
  final SecurityEducationService _service = SecurityEducationService();
  late TabController _tabController;
  
  SecurityConfig? _config;
  bool _isLoading = true;
  String? _error;
  
  // Demo results
  PasswordHashingDemo? _passwordDemo;
  JwtTokenDemo? _jwtDemo;
  RbacDemo? _rbacDemo;
  ReplayProtectionDemo? _replayDemo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('🔐 Security Education Center'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.security), text: 'Features'),
            Tab(icon: Icon(Icons.science), text: 'Demos'),
            Tab(icon: Icon(Icons.school), text: 'Learn'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFeaturesTab(),
                    _buildDemosTab(),
                    _buildLearnTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConfig,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    if (_config == null) {
      return const Center(child: Text('No security configuration available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeCard(),
          SizedBox(height: 16.h),
          _buildSecurityScore(),
          SizedBox(height: 24.h),
          ..._config!.categories.map((category) => _buildCategorySection(category)),
        ],
      ),
    );
  }

  Widget _buildModeCard() {
    final mode = _config?.mode ?? 'unknown';
    final isSecure = mode == 'secure';
    final isEducational = mode == 'educational';
    
    Color cardColor;
    IconData modeIcon;
    String modeDescription;
    
    if (isSecure) {
      cardColor = Colors.green;
      modeIcon = Icons.verified_user;
      modeDescription = 'All security features are enabled. Suitable for production.';
    } else if (isEducational) {
      cardColor = Colors.blue;
      modeIcon = Icons.school;
      modeDescription = 'Security enabled with verbose logging for learning.';
    } else {
      cardColor = Colors.orange;
      modeIcon = Icons.warning;
      modeDescription = '⚠️ Some security features may be disabled for demonstration.';
    }

    return Card(
      color: cardColor.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(modeIcon, size: 48, color: cardColor),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Mode: ${mode.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(modeDescription),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildModeSwitcher(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    final currentMode = _config?.mode ?? 'secure';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔄 Switch Mode (No Restart Needed!)',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _buildModeButton('secure', 'SECURE', Icons.shield, Colors.green, currentMode),
            _buildModeButton('educational', 'EDUCATIONAL', Icons.school, Colors.blue, currentMode),
            _buildModeButton('insecure', 'INSECURE', Icons.warning, Colors.orange, currentMode),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          '💡 Educational mode is recommended for learning. Insecure mode demonstrates vulnerabilities.',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon, Color color, String currentMode) {
    final isSelected = mode == currentMode;
    
    return ElevatedButton.icon(
      onPressed: isSelected ? null : () => _switchMode(mode),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.grey.shade700,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
    );
  }

  Future<void> _switchMode(String newMode) async {
    setState(() => _isLoading = true);
    
    final result = await _service.setSecurityMode(newMode);
    
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Mode switched to ${newMode.toUpperCase()} - No restart needed!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadConfig(); // Refresh the config
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to switch mode'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSecurityScore() {
    final enabled = _config?.enabledCount ?? 0;
    final total = _config?.totalCount ?? 1;
    final percentage = (enabled / total * 100).round();
    
    Color scoreColor;
    if (percentage >= 90) {
      scoreColor = Colors.green;
    } else if (percentage >= 70) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              'Security Score',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12.h),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: enabled / total,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      '$enabled/$total',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              percentage >= 90 
                  ? '✅ Excellent security posture'
                  : percentage >= 70
                      ? '⚠️ Some features disabled'
                      : '❌ Critical features missing',
              style: TextStyle(color: scoreColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category) {
    final features = _config?.getFeaturesByCategory(category) ?? [];
    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        ...features.map((f) => _buildFeatureCard(f)),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildFeatureCard(SecurityFeature feature) {
    final canToggle = _config?.mode != 'secure';
    
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ExpansionTile(
        leading: Icon(
          feature.enabled ? Icons.check_circle : Icons.cancel,
          color: feature.enabled ? Colors.green : Colors.red,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                feature.name,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
            ),
            if (canToggle)
              Switch(
                value: feature.enabled,
                onChanged: (value) => _toggleFeature(feature.id, value),
                activeColor: Colors.green,
              ),
          ],
        ),
        subtitle: Text(
          feature.description,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canToggle && !feature.enabled) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.orange),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            '💡 This feature is DISABLED for educational demonstration. '
                            'Toggle it back ON to see the security difference.',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildInfoSection('📍 Code Location', feature.codeLocation),
                if (feature.cweReference != null)
                  _buildInfoSection('🔗 CWE Reference', feature.cweReference!),
                if (feature.owaspReference != null)
                  _buildInfoSection('🔗 OWASP Reference', feature.owaspReference!),
                _buildInfoSection('📋 FDA Requirement', feature.fdaRequirement),
                if (!feature.enabled)
                  _buildWarningSection('⚠️ Risk if Disabled', feature.riskIfDisabled),
                SizedBox(height: 12.h),
                ExpansionTile(
                  title: const Text('📚 Learn More'),
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        feature.educationalExplanation,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFeature(String featureId, bool enabled) async {
    final result = await _service.toggleSecurityFeature(featureId, enabled);
    
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled 
            ? '✅ $featureId ENABLED - Security restored!'
            : '⚠️ $featureId DISABLED - Vulnerability exposed for learning'),
          backgroundColor: enabled ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadConfig(); // Refresh to show updated state
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to toggle feature. Make sure you are in Educational or Insecure mode.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoSection(String label, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            content,
            style: TextStyle(fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningSection(String label, String content) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            content,
            style: TextStyle(fontSize: 12.sp, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildDemosTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🧪 Interactive Security Demonstrations',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            'Explore how each security feature works in practice.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(height: 24.h),
          _buildDemoCard(
            title: '🔐 Password Hashing (Argon2id)',
            description: 'See how passwords are securely hashed using memory-hard algorithms.',
            onRun: _runPasswordDemo,
            result: _passwordDemo != null ? _buildPasswordDemoResult() : null,
          ),
          _buildDemoCard(
            title: '🎟️ JWT Token Structure',
            description: 'Examine the anatomy of a JSON Web Token.',
            onRun: _runJwtDemo,
            result: _jwtDemo != null ? _buildJwtDemoResult() : null,
          ),
          _buildDemoCard(
            title: '👥 Role-Based Access Control',
            description: 'View the permission matrix for different user roles.',
            onRun: _runRbacDemo,
            result: _rbacDemo != null ? _buildRbacDemoResult() : null,
          ),
          _buildDemoCard(
            title: '🔄 Replay Attack Protection',
            description: 'Understand how nonces prevent request replay attacks.',
            onRun: _runReplayDemo,
            result: _replayDemo != null ? _buildReplayDemoResult() : null,
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
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13.sp),
                ),
                SizedBox(height: 12.h),
                ElevatedButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Demo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (result != null) result,
        ],
      ),
    );
  }

  Future<void> _runPasswordDemo() async {
    final demo = await _service.demoPasswordHashing();
    if (mounted) {
      setState(() => _passwordDemo = demo);
    }
  }

  Future<void> _runJwtDemo() async {
    final demo = await _service.demoJwtToken();
    if (mounted) {
      setState(() => _jwtDemo = demo);
    }
  }

  Future<void> _runRbacDemo() async {
    final demo = await _service.demoRbac();
    if (mounted) {
      setState(() => _rbacDemo = demo);
    }
  }

  Future<void> _runReplayDemo() async {
    final demo = await _service.demoReplayProtection();
    if (mounted) {
      setState(() => _replayDemo = demo);
    }
  }

  Widget _buildPasswordDemoResult() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultRow('Input Password', _passwordDemo!.inputPassword),
          _buildResultRow('Algorithm', _passwordDemo!.algorithm),
          _buildResultRow('Hash Length', '${_passwordDemo!.hashLength} characters'),
          _buildResultRow('Hash Time', '${_passwordDemo!.timing['hashTimeMs']}ms'),
          SizedBox(height: 8.h),
          const Text('Hashed Output:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _passwordDemo!.hashedOutput,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10.sp),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _passwordDemo!.hashedOutput));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hash copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '💡 Note: The same password produces a different hash each time due to random salt!',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.blue.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJwtDemoResult() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Token Structure:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          _buildTokenPart('Header (Red)', _jwtDemo!.tokenParts['header'], Colors.red),
          _buildTokenPart('Payload (Purple)', _jwtDemo!.tokenParts['payload'], Colors.purple),
          _buildTokenPart('Signature (Blue)', _jwtDemo!.tokenParts['signature'], Colors.blue),
          SizedBox(height: 12.h),
          Text(
            '⚠️ This is a demo token with a fake secret. Real tokens use a secure server-side secret.',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.orange.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenPart(String name, Map<String, dynamic>? part, Color color) {
    if (part == null) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          if (part['decoded'] != null)
            SelectableText(
              part['decoded'].toString(),
              style: TextStyle(fontFamily: 'monospace', fontSize: 10.sp),
            ),
          if (part['explanation'] != null)
            Text(
              part['explanation'].toString(),
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildRbacDemoResult() {
    final currentUser = _rbacDemo!.currentUser;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultRow('Your User ID', currentUser['userId']?.toString() ?? 'N/A'),
          _buildResultRow('Your Role', currentUser['role']?.toString() ?? 'anonymous'),
          SizedBox(height: 12.h),
          const Text('Your Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          ...(currentUser['permissions'] as Map<String, dynamic>? ?? {}).entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                children: [
                  Icon(
                    e.value == true ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: e.value == true ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 8.w),
                  Text(e.key.replaceAll('_', ' ').toUpperCase()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplayDemoResult() {
    final firstTest = _replayDemo!.validationTest['firstValidation'] as Map<String, dynamic>?;
    final replayTest = _replayDemo!.validationTest['replayAttempt'] as Map<String, dynamic>?;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generated Nonce:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4.h),
          SelectableText(
            _replayDemo!.generatedNonce,
            style: TextStyle(fontFamily: 'monospace', fontSize: 10.sp),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                firstTest?['passed'] == true ? Icons.check_circle : Icons.cancel,
                color: firstTest?['passed'] == true ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8.w),
              const Text('First Use: '),
              Text(
                firstTest?['passed'] == true ? 'VALID ✓' : 'INVALID ✗',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: firstTest?['passed'] == true ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                replayTest?['passed'] == true ? Icons.check_circle : Icons.cancel,
                color: replayTest?['passed'] == true ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8.w),
              const Text('Replay Attempt: '),
              Text(
                replayTest?['passed'] == true ? 'VALID ✓' : 'REJECTED ✗',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: replayTest?['passed'] == true ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '💡 The same nonce cannot be used twice! This prevents replay attacks.',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.blue.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📚 Medical Device Cybersecurity Learning',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            'Understanding security is critical for medical device development.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(height: 24.h),
          _buildLearningModule(
            icon: '🏥',
            title: 'FDA Cybersecurity Requirements',
            items: [
              'Pre-market submission requirements (2025 guidance)',
              'Post-market surveillance and updates',
              'Software Bill of Materials (SBOM)',
              'Threat modeling documentation',
            ],
          ),
          _buildLearningModule(
            icon: '🛡️',
            title: 'STRIDE Threat Model',
            items: [
              'Spoofing: Identity impersonation',
              'Tampering: Data modification',
              'Repudiation: Denying actions',
              'Information Disclosure: Data leaks',
              'Denial of Service: Availability attacks',
              'Elevation of Privilege: Unauthorized access',
            ],
          ),
          _buildLearningModule(
            icon: '🔐',
            title: 'Authentication Best Practices',
            items: [
              'Strong password policies (NIST SP 800-63B)',
              'Multi-factor authentication (MFA/2FA)',
              'Secure token management (JWT)',
              'Session timeout and refresh',
            ],
          ),
          _buildLearningModule(
            icon: '🔑',
            title: 'Cryptographic Controls',
            items: [
              'TLS 1.3 for transport encryption',
              'Argon2id for password hashing',
              'AES-256 for data at rest',
              'HMAC for message authentication',
            ],
          ),
          _buildLearningModule(
            icon: '📋',
            title: 'Compliance Standards',
            items: [
              'IEC 62443 (Industrial Security)',
              'ISO 14971 (Risk Management)',
              'HIPAA (Health Information Protection)',
              'OWASP Top 10 (Web Security)',
            ],
          ),
          SizedBox(height: 24.h),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      SizedBox(width: 8.w),
                      Text(
                        'About MeDUSA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'MeDUSA (Medical Device Universal Security Alignment) is an open-source '
                    'educational platform designed to teach medical device cybersecurity '
                    'through hands-on experience. It demonstrates real-world security '
                    'implementations while providing interactive learning tools.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningModule({
    required String icon,
    required String title,
    required List<String> items,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ExpansionTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp),
        ),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Column(
              children: items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(item)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
