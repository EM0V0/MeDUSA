import 'package:flutter/material.dart';
import '../../../../shared/widgets/security_lab_page.dart';

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
    // Simply return the SecurityLabPage which has its own AppBar
    return const SecurityLabPage();
  }
}

