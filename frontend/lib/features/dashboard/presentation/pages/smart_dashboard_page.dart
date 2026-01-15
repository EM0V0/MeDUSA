import 'package:flutter/material.dart';

import '../../../../core/constants/role_constants.dart';
import '../../../../shared/services/role_service.dart';
import 'admin_dashboard_page.dart';
import 'dashboard_page.dart';
import 'doctor_dashboard_page.dart';

/// Smart dashboard that routes to appropriate dashboard based on user role
/// Provides role-specific dashboard experience without duplicating routing logic
class SmartDashboardPage extends StatelessWidget {
  const SmartDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roleService = RoleService();

    // Route to appropriate dashboard based on user role
    switch (roleService.currentRole) {
      case UserRole.doctor:
        return const DoctorDashboardPage();
      case UserRole.admin:
        return const AdminDashboardPage();
      case UserRole.patient:
      default:
        return const DashboardPage(); // Default patient dashboard
    }
  }
}
