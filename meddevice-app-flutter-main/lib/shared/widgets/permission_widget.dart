import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../core/auth/role_permissions.dart';

/// Widget that conditionally displays content based on user role permissions
/// 
/// Usage:
/// ```dart
/// PermissionWidget(
///   allowedRoles: [RolePermissions.doctor, RolePermissions.admin],
///   child: ElevatedButton(
///     onPressed: () => navigateToPatients(),
///     child: Text('View Patients'),
///   ),
///   fallback: Text('No permission'),
/// )
/// ```
class PermissionWidget extends ConsumerWidget {
  /// List of roles that are allowed to see the child widget
  final List<String> allowedRoles;
  
  /// The widget to display if user has permission
  final Widget child;
  
  /// Optional widget to display if user doesn't have permission
  /// If null, nothing will be displayed
  final Widget? fallback;
  
  /// If true, shows a message explaining why access is denied
  final bool showDeniedMessage;

  const PermissionWidget({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.showDeniedMessage = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authBlocProvider);

    // Not authenticated - hide content
    if (authState is! AuthenticatedState) {
      return fallback ?? const SizedBox.shrink();
    }

    final userRole = authState.user.role.toLowerCase();
    final hasPermission = allowedRoles.map((r) => r.toLowerCase()).contains(userRole);

    if (hasPermission) {
      return child;
    }

    // User doesn't have permission
    if (showDeniedMessage) {
      return _buildDeniedMessage(context, userRole);
    }

    return fallback ?? const SizedBox.shrink();
  }

  Widget _buildDeniedMessage(BuildContext context, String userRole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This feature requires ${_getRoleNames()} permissions. '
                  'Your current role: ${RolePermissions.getRoleDisplayName(userRole)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleNames() {
    return allowedRoles
        .map((role) => RolePermissions.getRoleDisplayName(role))
        .join(' or ');
  }
}

/// Widget that displays different content based on user role
/// 
/// Usage:
/// ```dart
/// RoleBasedWidget(
///   roleWidgets: {
///     RolePermissions.patient: PatientDashboard(),
///     RolePermissions.doctor: DoctorDashboard(),
///     RolePermissions.admin: AdminDashboard(),
///   },
///   defaultWidget: Text('No dashboard available'),
/// )
/// ```
class RoleBasedWidget extends ConsumerWidget {
  /// Map of role to widget
  final Map<String, Widget> roleWidgets;
  
  /// Default widget if role not found in map
  final Widget? defaultWidget;

  const RoleBasedWidget({
    super.key,
    required this.roleWidgets,
    this.defaultWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authBlocProvider);

    if (authState is! AuthenticatedState) {
      return defaultWidget ?? const SizedBox.shrink();
    }

    final userRole = authState.user.role.toLowerCase();
    
    // Try to find exact match
    if (roleWidgets.containsKey(userRole)) {
      return roleWidgets[userRole]!;
    }
    
    // Try case-insensitive match
    final matchedEntry = roleWidgets.entries.firstWhere(
      (entry) => entry.key.toLowerCase() == userRole,
      orElse: () => MapEntry('', defaultWidget ?? const SizedBox.shrink()),
    );
    
    return matchedEntry.value;
  }
}

/// Mixin for pages that require role-based access control
mixin RoleCheckMixin {
  /// Check if current user has required role
  bool hasRequiredRole(BuildContext context, WidgetRef ref, List<String> requiredRoles) {
    final authState = ref.read(authBlocProvider);
    
    if (authState is! AuthenticatedState) {
      return false;
    }
    
    final userRole = authState.user.role.toLowerCase();
    return requiredRoles.map((r) => r.toLowerCase()).contains(userRole);
  }
  
  /// Show permission denied dialog
  void showPermissionDenied(BuildContext context, List<String> requiredRoles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Access Denied'),
          ],
        ),
        content: Text(
          'This feature requires ${_formatRoles(requiredRoles)} permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  String _formatRoles(List<String> roles) {
    return roles
        .map((role) => RolePermissions.getRoleDisplayName(role))
        .join(' or ');
  }
}

/// Helper function to check if user has permission for a specific action
bool checkPermission(WidgetRef ref, List<String> allowedRoles) {
  final authState = ref.read(authBlocProvider);
  
  if (authState is! AuthenticatedState) {
    return false;
  }
  
  final userRole = authState.user.role.toLowerCase();
  return allowedRoles.map((r) => r.toLowerCase()).contains(userRole);
}

