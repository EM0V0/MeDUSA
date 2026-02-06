/// Role-based access control constants and permissions
library role_constants;

/// User roles enumeration
enum UserRole {
  doctor('doctor', 'Doctor', 'Medical practitioner with patient management access'),
  patient('patient', 'Patient', 'Individual patient with personal data access'),
  admin('admin', 'Administrator', 'System administrator with full access');

  const UserRole(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  /// Get UserRole from string value
  static UserRole fromString(String value) {
    for (UserRole role in UserRole.values) {
      if (role.value == value) {
        return role;
      }
    }
    return UserRole.patient; // Default fallback
  }

  /// Check if role is medical professional
  bool get isMedicalProfessional => this == UserRole.doctor;

  /// Check if role is system administrator
  bool get isAdmin => this == UserRole.admin;

  /// Check if role is patient
  bool get isPatientRole => this == UserRole.patient;
}

/// Application permissions enumeration
enum AppPermission {
  // Dashboard permissions
  viewDashboard('view_dashboard', 'View dashboard'),
  viewSystemOverview('view_system_overview', 'View system-wide overview'),
  
  // Patient data permissions
  viewOwnPatientData('view_own_patient_data', 'View own patient data'),
  viewAllPatientData('view_all_patient_data', 'View all patient data'),
  editPatientData('edit_patient_data', 'Edit patient information'),
  deletePatientData('delete_patient_data', 'Delete patient data'),
  
  // Medical data permissions
  viewOwnMedicalData('view_own_medical_data', 'View own medical readings'),
  viewAllMedicalData('view_all_medical_data', 'View all medical readings'),
  exportMedicalData('export_medical_data', 'Export medical data'),
  
  // Report permissions
  viewOwnReports('view_own_reports', 'View own reports'),
  viewAllReports('view_all_reports', 'View all reports'),
  createReports('create_reports', 'Create medical reports'),
  deleteReports('delete_reports', 'Delete reports'),
  
  // User management permissions
  viewUsers('view_users', 'View user accounts'),
  createUsers('create_users', 'Create user accounts'),
  editUsers('edit_users', 'Edit user accounts'),
  deleteUsers('delete_users', 'Delete user accounts'),
  
  // System administration permissions
  viewSystemSettings('view_system_settings', 'View system settings'),
  editSystemSettings('edit_system_settings', 'Edit system settings'),
  viewAuditLogs('view_audit_logs', 'View audit logs'),
  manageDevices('manage_devices', 'Manage medical devices'),
  viewSecurityEducation('view_security_education', 'View security education center'),
  
  // Communication permissions
  sendMessages('send_messages', 'Send messages to patients/doctors'),
  viewMessages('view_messages', 'View messages'),
  
  // Profile permissions
  editOwnProfile('edit_own_profile', 'Edit own profile'),
  viewOwnProfile('view_own_profile', 'View own profile');

  const AppPermission(this.value, this.description);

  final String value;
  final String description;
}

/// Role-based permission mapping
class RolePermissions {
  static const Map<UserRole, Set<AppPermission>> _rolePermissions = {
    UserRole.doctor: {
      // Dashboard and overview
      AppPermission.viewDashboard,
      
      // Patient management
      AppPermission.viewAllPatientData,
      AppPermission.editPatientData,
      AppPermission.viewAllMedicalData,
      AppPermission.exportMedicalData,
      
      // Reports
      AppPermission.viewAllReports,
      AppPermission.createReports,
      
      // Communication
      AppPermission.sendMessages,
      AppPermission.viewMessages,
      
      // Profile
      AppPermission.viewOwnProfile,
      AppPermission.editOwnProfile,
    },
    
    UserRole.patient: {
      // Dashboard
      AppPermission.viewDashboard,
      
      // Own data only
      AppPermission.viewOwnPatientData,
      AppPermission.viewOwnMedicalData,
      AppPermission.viewOwnReports,
      
      // Communication
      AppPermission.viewMessages,
      AppPermission.sendMessages,
      
      // Profile
      AppPermission.viewOwnProfile,
      AppPermission.editOwnProfile,
    },
    
    
    UserRole.admin: {
      // Full system access
      AppPermission.viewSystemOverview,
      AppPermission.viewDashboard,
      
      // All patient data
      AppPermission.viewAllPatientData,
      AppPermission.editPatientData,
      AppPermission.deletePatientData,
      AppPermission.viewAllMedicalData,
      AppPermission.exportMedicalData,
      
      // All reports
      AppPermission.viewAllReports,
      AppPermission.createReports,
      AppPermission.deleteReports,
      
      // User management
      AppPermission.viewUsers,
      AppPermission.createUsers,
      AppPermission.editUsers,
      AppPermission.deleteUsers,
      
      // System administration
      AppPermission.viewSystemSettings,
      AppPermission.editSystemSettings,
      AppPermission.viewAuditLogs,
      AppPermission.manageDevices,
      AppPermission.viewSecurityEducation,
      
      // Communication
      AppPermission.sendMessages,
      AppPermission.viewMessages,
      
      // Profile
      AppPermission.viewOwnProfile,
      AppPermission.editOwnProfile,
    },
  };

  /// Get permissions for a specific role
  static Set<AppPermission> getPermissions(UserRole role) {
    return _rolePermissions[role] ?? <AppPermission>{};
  }

  /// Check if a role has a specific permission
  static bool hasPermission(UserRole role, AppPermission permission) {
    final permissions = getPermissions(role);
    return permissions.contains(permission);
  }

  /// Get all permissions for multiple roles
  static Set<AppPermission> getCombinedPermissions(List<UserRole> roles) {
    final Set<AppPermission> combinedPermissions = <AppPermission>{};
    for (final role in roles) {
      combinedPermissions.addAll(getPermissions(role));
    }
    return combinedPermissions;
  }
}

/// Navigation items for different roles
/// Optimized for better communication and shared functionality between roles
class RoleNavigationConfig {
  static const Map<UserRole, List<NavigationItemConfig>> _navigationConfig = {
    UserRole.doctor: [
      NavigationItemConfig(
        route: '/dashboard',
        label: 'Dashboard',
        icon: 'dashboard_outlined',
        selectedIcon: 'dashboard',
        requiredPermission: AppPermission.viewDashboard,
      ),
      NavigationItemConfig(
        route: '/patients',
        label: 'Patients',
        icon: 'people_outlined',
        selectedIcon: 'people',
        requiredPermission: AppPermission.viewAllPatientData,
      ),
      NavigationItemConfig(
        route: '/messages',
        label: 'Messages',
        icon: 'message_outlined',
        selectedIcon: 'message',
        requiredPermission: AppPermission.viewMessages,
      ),
      NavigationItemConfig(
        route: '/reports',
        label: 'Reports',
        icon: 'description_outlined',
        selectedIcon: 'description',
        requiredPermission: AppPermission.viewAllReports,
      ),
      NavigationItemConfig(
        route: '/settings',
        label: 'Settings',
        icon: 'settings_outlined',
        selectedIcon: 'settings',
        requiredPermission: AppPermission.editOwnProfile,
      ),
    ],
    
    UserRole.patient: [
      NavigationItemConfig(
        route: '/dashboard',
        label: 'My Health',
        icon: 'dashboard_outlined',
        selectedIcon: 'dashboard',
        requiredPermission: AppPermission.viewDashboard,
      ),
      NavigationItemConfig(
        route: '/device-scan',
        label: 'My Device',
        icon: 'bluetooth_searching_outlined',
        selectedIcon: 'bluetooth_connected',
        requiredPermission: AppPermission.viewOwnMedicalData,
      ),
      NavigationItemConfig(
        route: '/symptoms',
        label: 'Symptoms',
        icon: 'health_and_safety_outlined',
        selectedIcon: 'health_and_safety',
        requiredPermission: AppPermission.viewOwnMedicalData,
      ),
      NavigationItemConfig(
        route: '/messages',
        label: 'Messages',
        icon: 'message_outlined',
        selectedIcon: 'message',
        requiredPermission: AppPermission.viewMessages,
      ),
      NavigationItemConfig(
        route: '/reports',
        label: 'My Reports',
        icon: 'description_outlined',
        selectedIcon: 'description',
        requiredPermission: AppPermission.viewOwnReports,
      ),
      NavigationItemConfig(
        route: '/settings',
        label: 'Settings',
        icon: 'settings_outlined',
        selectedIcon: 'settings',
        requiredPermission: AppPermission.editOwnProfile,
      ),
    ],
    
    UserRole.admin: [
      NavigationItemConfig(
        route: '/dashboard',
        label: 'System Overview',
        icon: 'admin_panel_settings_outlined',
        selectedIcon: 'admin_panel_settings',
        requiredPermission: AppPermission.viewSystemOverview,
      ),
      NavigationItemConfig(
        route: '/user-management',
        label: 'User Management',
        icon: 'people_outlined',
        selectedIcon: 'people',
        requiredPermission: AppPermission.viewUsers,
      ),
      NavigationItemConfig(
        route: '/device-management',
        label: 'Device Management',
        icon: 'devices_outlined',
        selectedIcon: 'devices',
        requiredPermission: AppPermission.manageDevices,
      ),
      NavigationItemConfig(
        route: '/system-settings',
        label: 'System Settings',
        icon: 'settings_outlined',
        selectedIcon: 'settings',
        requiredPermission: AppPermission.editSystemSettings,
      ),
      NavigationItemConfig(
        route: '/audit-logs',
        label: 'Audit Logs',
        icon: 'history_outlined',
        selectedIcon: 'history',
        requiredPermission: AppPermission.viewAuditLogs,
      ),
      NavigationItemConfig(
        route: '/security-education',
        label: 'Security Lab',
        icon: 'school_outlined',
        selectedIcon: 'school',
        requiredPermission: AppPermission.viewSecurityEducation,
      ),
    ],
    
  };

  /// Get navigation configuration for a specific role
  static List<NavigationItemConfig> getNavigationItems(UserRole role) {
    return _navigationConfig[role] ?? [];
  }
}

/// Navigation item configuration class
class NavigationItemConfig {
  final String route;
  final String label;
  final String icon;
  final String selectedIcon;
  final AppPermission requiredPermission;

  const NavigationItemConfig({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.requiredPermission,
  });
}
