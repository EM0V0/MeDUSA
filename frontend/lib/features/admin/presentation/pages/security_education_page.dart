import 'package:flutter/material.dart';
import '../../../../shared/widgets/security_education_panel.dart';

/// Security Education Page
/// 
/// This page provides an educational interface for learning about
/// medical device security features implemented in MeDUSA.
/// 
/// Educational Purpose:
/// - Demonstrates security concepts in practice
/// - Allows toggling between secure/insecure configurations
/// - Provides interactive demos of security mechanisms
/// - Links to FDA, OWASP, and CWE regulatory requirements
class SecurityEducationPage extends StatelessWidget {
  const SecurityEducationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Education Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About Security Education',
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: const SecurityEducationPanel(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.blue),
            SizedBox(width: 8),
            Text('Security Education'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MeDUSA Security Education Center',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'This platform demonstrates security best practices for medical device software development. '
                'It is designed as an educational tool to help developers and students understand:',
              ),
              SizedBox(height: 12),
              _BulletPoint('Password hashing with Argon2id'),
              _BulletPoint('JWT-based authentication'),
              _BulletPoint('Multi-factor authentication (TOTP)'),
              _BulletPoint('Role-based access control'),
              _BulletPoint('Replay attack protection'),
              _BulletPoint('Audit logging'),
              _BulletPoint('Input validation'),
              _BulletPoint('TLS enforcement'),
              SizedBox(height: 16),
              Text(
                'Compliance References:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _BulletPoint('FDA Premarket Cybersecurity Guidance'),
              _BulletPoint('IEC 62443 Industrial Security'),
              _BulletPoint('OWASP Security Guidelines'),
              _BulletPoint('NIST Cybersecurity Framework'),
              SizedBox(height: 16),
              Text(
                '⚠️ Warning: The "Insecure Mode" is for educational purposes only. '
                'Never use it in production environments.',
                style: TextStyle(
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
