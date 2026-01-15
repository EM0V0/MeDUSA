import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Widget that conditionally displays content based on user role permissions
/// 
/// Usage:
/// ```dart
/// PermissionWidget(
///   allowedRoles: ['doctor', 'admin'],
///   child: ElevatedButton(
///     onPressed: () => navigateToPatients(),
///     child: Text('View Patients'),
///   ),
///   fallback: Text('No permission'),
/// )
/// ```
class PermissionWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Not authenticated - hide content
        if (authState is! AuthAuthenticated) {
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
      },
    );
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
                  'Your current role: ${_getRoleDisplayName(userRole)}',
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
        .map((role) => _getRoleDisplayName(role))
        .join(' or ');
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return 'Doctor';
      case 'patient':
        return 'Patient';
      case 'admin':
        return 'Administrator';
      case 'nurse':
        return 'Nurse';
      default:
        return role;
    }
  }
}

/// Widget that displays different content based on user role
/// 
/// Usage:
/// ```dart
/// RoleBasedWidget(
///   roleWidgets: {
///     'patient': PatientDashboard(),
///     'doctor': DoctorDashboard(),
///     'admin': AdminDashboard(),
///   },
///   defaultWidget: Text('No dashboard available'),
/// )
/// ```
class RoleBasedWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
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
      },
    );
  }
}

/// Mixin for pages that require role-based access control
mixin RoleCheckMixin {
  /// Check if current user has required role
  bool hasRequiredRole(BuildContext context, List<String> requiredRoles) {
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    final authState = authBloc.state;
    
    if (authState is! AuthAuthenticated) {
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
    return roles.map((role) {
      switch (role.toLowerCase()) {
        case 'doctor':
          return 'Doctor';
        case 'patient':
          return 'Patient';
        case 'admin':
          return 'Administrator';
        case 'nurse':
          return 'Nurse';
        default:
          return role;
      }
    }).join(' or ');
  }
}

/// Helper function to check if user has permission for a specific action
bool checkPermission(BuildContext context, List<String> allowedRoles) {
  final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
  final authState = authBloc.state;
  
  if (authState is! AuthAuthenticated) {
    return false;
  }
  
  final userRole = authState.user.role.toLowerCase();
  return allowedRoles.map((r) => r.toLowerCase()).contains(userRole);
}

