/// Role-Based Access Control (RBAC) Configuration
/// Defines roles and their permissions for the MeDUSA application
class RolePermissions {
  // ==================== Role Constants ====================
  
  /// Patient role - basic user with limited access
  static const String patient = 'patient';
  
  /// Doctor role - medical professional with patient access
  static const String doctor = 'doctor';
  
  /// Admin role - full system access
  static const String admin = 'admin';

  // ==================== Route Permissions ====================
  
  /// Map of routes to allowed roles
  /// Routes not listed here are accessible to all authenticated users
  static final Map<String, List<String>> routePermissions = {
    // Public routes (all authenticated users)
    '/dashboard': [patient, doctor, admin],
    '/profile': [patient, doctor, admin],
    '/settings': [patient, doctor, admin],
    
    // Patient-specific routes
    '/symptoms': [patient],
    '/devices/scan': [patient],
    '/devices/connection': [patient],
    
    // Doctor and Admin routes
    '/patients': [doctor, admin],
    '/patients/:id': [doctor, admin],
    '/reports': [doctor, admin],
    '/messages': [doctor, admin],
    
    // Admin-only routes
    '/admin': [admin],
    '/admin/users': [admin],
    '/admin/dashboard': [admin],
  };

  // ==================== Permission Checks ====================
  
  /// Check if a user role has permission to access a route
  static bool hasPermission(String route, String userRole) {
    // Normalize role to lowercase
    final role = userRole.toLowerCase();
    
    // Check exact match first
    final allowedRoles = routePermissions[route];
    if (allowedRoles != null) {
      return allowedRoles.contains(role);
    }
    
    // Check pattern match for dynamic routes (e.g., /patients/:id)
    for (final entry in routePermissions.entries) {
      if (_matchRoute(route, entry.key)) {
        return entry.value.contains(role);
      }
    }
    
    // Default: allow access if route not in permissions map
    return true;
  }
  
  /// Match route patterns (e.g., /patients/123 matches /patients/:id)
  static bool _matchRoute(String route, String pattern) {
    final routeParts = route.split('/');
    final patternParts = pattern.split('/');
    
    if (routeParts.length != patternParts.length) return false;
    
    for (int i = 0; i < routeParts.length; i++) {
      if (patternParts[i].startsWith(':')) continue; // Dynamic segment
      if (routeParts[i] != patternParts[i]) return false;
    }
    
    return true;
  }

  // ==================== Feature-Level Permissions ====================
  
  /// Check if user can view all patients
  static bool canViewPatients(String role) {
    return role == doctor || role == admin;
  }
  
  /// Check if user can manage users (create, update, delete)
  static bool canManageUsers(String role) {
    return role == admin;
  }
  
  /// Check if user can edit a specific patient's data
  static bool canEditPatient(String role, String patientId, String currentUserId) {
    // Admin and doctor can edit any patient
    if (role == admin || role == doctor) return true;
    
    // Patient can only edit their own data
    if (role == patient) return patientId == currentUserId;
    
    return false;
  }
  
  /// Check if user can view a specific patient's data
  static bool canViewPatient(String role, String patientId, String currentUserId) {
    // Admin and doctor can view any patient
    if (role == admin || role == doctor) return true;
    
    // Patient can only view their own data
    if (role == patient) return patientId == currentUserId;
    
    return false;
  }
  
  /// Check if user can delete patient data
  static bool canDeletePatient(String role) {
    return role == admin;
  }
  
  /// Check if user can access admin features
  static bool canAccessAdmin(String role) {
    return role == admin;
  }
  
  /// Check if user can connect to Bluetooth devices
  static bool canConnectDevices(String role) {
    return role == patient; // Only patients connect their own devices
  }
  
  /// Check if user can create medical reports
  static bool canCreateReports(String role) {
    return role == doctor || role == admin;
  }
  
  /// Check if user can send messages
  static bool canSendMessages(String role) {
    return role == doctor || role == admin;
  }

  // ==================== Role Validation ====================
  
  /// Check if a role string is valid
  static bool isValidRole(String role) {
    final normalizedRole = role.toLowerCase();
    return normalizedRole == patient || 
           normalizedRole == doctor || 
           normalizedRole == admin;
  }
  
  /// Get display name for a role
  static String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case patient:
        return 'Patient';
      case doctor:
        return 'Doctor';
      case admin:
        return 'Administrator';
      default:
        return 'Unknown';
    }
  }
  
  /// Get all available roles
  static List<String> getAllRoles() {
    return [patient, doctor, admin];
  }
  
  /// Get role description
  static String getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case patient:
        return 'Basic user with access to personal health data and device connection';
      case doctor:
        return 'Medical professional with access to patient data and reports';
      case admin:
        return 'Full system administrator with all permissions';
      default:
        return 'Unknown role';
    }
  }
}

