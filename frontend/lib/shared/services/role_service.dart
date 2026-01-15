import 'package:flutter/foundation.dart';

import '../../core/constants/role_constants.dart';
import '../../features/auth/domain/entities/user.dart';

/// Service for managing user roles and permissions
/// Provides centralized role-based access control functionality
class RoleService extends ChangeNotifier {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  User? _currentUser;
  UserRole? _currentRole;

  /// Get current user
  User? get currentUser => _currentUser;

  /// Get current user role
  UserRole? get currentRole => _currentRole;

  /// Get current user role as string
  String? get currentRoleString => _currentRole?.value;

  /// Initialize role service with current user
  void initialize(User user) {
    _currentUser = user;
    _currentRole = UserRole.fromString(user.role);
    notifyListeners();
  }

  /// Clear current user session
  void clear() {
    _currentUser = null;
    _currentRole = null;
    notifyListeners();
  }

  /// Check if current user has specific permission
  bool hasPermission(AppPermission permission) {
    if (_currentRole == null) return false;
    return RolePermissions.hasPermission(_currentRole!, permission);
  }

  /// Check if current user has any of the specified permissions
  bool hasAnyPermission(List<AppPermission> permissions) {
    if (_currentRole == null) return false;
    for (final permission in permissions) {
      if (hasPermission(permission)) {
        return true;
      }
    }
    return false;
  }

  /// Check if current user has all specified permissions
  bool hasAllPermissions(List<AppPermission> permissions) {
    if (_currentRole == null) return false;
    for (final permission in permissions) {
      if (!hasPermission(permission)) {
        return false;
      }
    }
    return true;
  }

  /// Get all permissions for current user role
  Set<AppPermission> getCurrentUserPermissions() {
    if (_currentRole == null) return <AppPermission>{};
    return RolePermissions.getPermissions(_currentRole!);
  }

  /// Get navigation items for current user role
  List<NavigationItemConfig> getNavigationItems() {
    if (_currentRole == null) return [];
    return RoleNavigationConfig.getNavigationItems(_currentRole!);
  }

  /// Get filtered navigation items based on user permissions
  List<NavigationItemConfig> getFilteredNavigationItems() {
    final allItems = getNavigationItems();
    return allItems.where((item) => hasPermission(item.requiredPermission)).toList();
  }

  /// Check if current user is a medical professional
  bool get isMedicalProfessional => _currentRole?.isMedicalProfessional ?? false;

  /// Check if current user is an administrator
  bool get isAdmin => _currentRole?.isAdmin ?? false;

  /// Check if current user is a patient
  bool get isPatientRole => _currentRole?.isPatientRole ?? false;

  /// Check if current user is a doctor
  bool get isDoctor => _currentRole == UserRole.doctor;

  /// Check if current user is a patient
  bool get isPatient => _currentRole == UserRole.patient;


  /// Get role-specific dashboard route
  String getDashboardRoute() {
    switch (_currentRole) {
      case UserRole.admin:
        return '/admin-dashboard';
      case UserRole.doctor:
        return '/dashboard';
      case UserRole.patient:
        return '/dashboard';
      default:
        return '/dashboard';
    }
  }

  /// Get role-specific home page title
  String getHomePageTitle() {
    switch (_currentRole) {
      case UserRole.admin:
        return 'MedDevice Admin';
      case UserRole.doctor:
        return 'MedDevice Doctor';
      case UserRole.patient:
        return 'MedDevice Patient';
      default:
        return 'MedDevice';
    }
  }

  /// Get page-specific title based on current route
  String getPageTitle(String route) {
    switch (route) {
      case '/dashboard':
        switch (_currentRole) {
          case UserRole.admin:
            return 'System Overview';
          case UserRole.doctor:
            return 'Medical Dashboard';
          case UserRole.patient:
            return 'My Health Dashboard';
          default:
            return 'Dashboard';
        }
      case '/patients':
        return _currentRole == UserRole.doctor ? 'Patient Management' : 'Patients';
      case '/messages':
        switch (_currentRole) {
          case UserRole.doctor:
            return 'Patient Messages';
          case UserRole.patient:
            return 'Doctor Messages';
          default:
            return 'Messages';
        }
      case '/reports':
        switch (_currentRole) {
          case UserRole.doctor:
            return 'Medical Reports';
          case UserRole.patient:
            return 'My Reports';
          case UserRole.admin:
            return 'System Reports';
          default:
            return 'Reports';
        }
      case '/symptoms':
        return 'Symptom Tracking';
      case '/settings':
        return 'Settings';
      case '/profile':
        return 'My Profile';
      case '/admin-dashboard':
        return 'Admin Dashboard';
      case '/user-management':
        return 'User Management';
      case '/device-management':
        return 'Device Management';
      case '/system-settings':
        return 'System Settings';
      case '/audit-logs':
        return 'Audit Logs';
      default:
        return getHomePageTitle();
    }
  }

  /// Check if user can access specific route
  bool canAccessRoute(String route) {
    final navigationItems = getFilteredNavigationItems();
    return navigationItems.any((item) => route.startsWith(item.route));
  }

  /// Get appropriate redirect route for unauthorized access
  String getUnauthorizedRedirectRoute() {
    return getDashboardRoute();
  }

  /// Validate user permissions for specific action
  bool validatePermissionForAction(String action) {
    switch (action.toLowerCase()) {
      case 'view_patients':
        return hasPermission(AppPermission.viewAllPatientData);
      case 'edit_patient':
        return hasPermission(AppPermission.editPatientData);
      case 'delete_patient':
        return hasPermission(AppPermission.deletePatientData);
      case 'create_report':
        return hasPermission(AppPermission.createReports);
      case 'view_system_settings':
        return hasPermission(AppPermission.viewSystemSettings);
      case 'manage_users':
        return hasPermission(AppPermission.viewUsers);
      default:
        return false;
    }
  }

  /// Get user-friendly role display name
  String getRoleDisplayName() {
    return _currentRole?.displayName ?? 'Unknown';
  }

  /// Get role description
  String getRoleDescription() {
    return _currentRole?.description ?? 'No description available';
  }

  /// Debug method to log current permissions (development only)
  void logCurrentPermissions() {
    if (kDebugMode) {
      final permissions = getCurrentUserPermissions();
      print('=== Current User Permissions ===');
      print('User: ${_currentUser?.name ?? 'Unknown'}');
      print('Role: ${getRoleDisplayName()}');
      print('Permissions:');
      for (final permission in permissions) {
        print('  - ${permission.description}');
      }
      print('================================');
    }
  }

  /// Update user role (for admin operations)
  void updateUserRole(UserRole newRole) {
    if (hasPermission(AppPermission.editUsers)) {
      _currentRole = newRole;
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(role: newRole.value);
      }
      notifyListeners();
    }
  }
}

/// Extension methods for easier role checking
extension UserRoleExtensions on User {
  UserRole get userRole => UserRole.fromString(role);
  
  bool hasRole(UserRole targetRole) => userRole == targetRole;
  
  bool hasPermission(AppPermission permission) {
    return RolePermissions.hasPermission(userRole, permission);
  }
  
  bool get isDoctor => userRole == UserRole.doctor;
  bool get isPatient => userRole == UserRole.patient;
  bool get isAdmin => userRole == UserRole.admin;
}
