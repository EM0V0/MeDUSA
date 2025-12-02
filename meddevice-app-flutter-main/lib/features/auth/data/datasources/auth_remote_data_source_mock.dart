import '../../domain/entities/user.dart';
import 'auth_remote_data_source.dart';

/// Mock implementation of AuthRemoteDataSource for development and testing
/// This allows the app to run without a backend server
class AuthRemoteDataSourceMock implements AuthRemoteDataSource {
  // Predefined mock users for testing different roles
  static final Map<String, User> _mockUsers = {
    'demo@medusa.com': const User(
      id: 'demo-user-001',
      email: 'demo@medusa.com',
      name: 'Demo User',
      role: 'patient',
      isActive: true,
    ),
    'doctor@medusa.com': const User(
      id: 'doctor-user-001',
      email: 'doctor@medusa.com',
      name: 'Dr. John Smith',
      role: 'doctor',
      isActive: true,
    ),
    'patient@medusa.com': const User(
      id: 'patient-user-001',
      email: 'patient@medusa.com',
      name: 'Patient Jane Doe',
      role: 'patient',
      isActive: true,
    ),
    'admin@medusa.com': const User(
      id: 'admin-user-001',
      email: 'admin@medusa.com',
      name: 'Admin User',
      role: 'admin',
      isActive: true,
    ),
    'nurse@medusa.com': const User(
      id: 'nurse-user-001',
      email: 'nurse@medusa.com',
      name: 'Nurse Sarah Johnson',
      role: 'nurse',
      isActive: true,
    ),
    'google_user@medusa.com': const User(
      id: 'google-user-001',
      email: 'google_user@medusa.com',
      name: 'Google OAuth User',
      role: 'patient',
      isActive: true,
    ),
    'apple_user@medusa.com': const User(
      id: 'apple-user-001',
      email: 'apple_user@medusa.com',
      name: 'Apple OAuth User',
      role: 'patient',
      isActive: true,
    ),
    'microsoft_user@medusa.com': const User(
      id: 'microsoft-user-001',
      email: 'microsoft_user@medusa.com',
      name: 'Microsoft OAuth User',
      role: 'patient',
      isActive: true,
    ),
  };

  @override
  Future<User> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if user exists in mock data
    if (_mockUsers.containsKey(email)) {
      // For mock login, any password is accepted
      // In real implementation, password would be validated
      return _mockUsers[email]!;
    }

    // If email not found, throw error
    throw Exception('Invalid email or password');
  }

  @override
  Future<User> mfaLogin(String tempToken, String code) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // For mock purposes, accept any code "123456"
    if (code == "123456") {
      // Return a default mock user
      return _mockUsers['demo@medusa.com']!;
    }
    
    throw Exception('Invalid MFA code');
  }

  @override
  Future<User> register(String name, String email, String password, String role) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Check if user already exists
    if (_mockUsers.containsKey(email)) {
      throw Exception('User with this email already exists');
    }

    // Create new mock user
    final newUser = User(
      id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      role: role.toLowerCase(),
      isActive: true,
      lastLogin: DateTime.now(),
    );

    // Add to mock users
    _mockUsers[email] = newUser;

    return newUser;
  }

  @override
  Future<void> logout() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Mock logout is always successful
    return;
  }

  @override
  Future<void> refreshToken() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Mock token refresh is always successful
    return;
  }

  @override
  Future<void> resetPassword(String email, String newPassword) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if user exists
    if (!_mockUsers.containsKey(email)) {
      throw Exception('Account not found.');
    }
    
    // In mock mode, password reset is always successful
    // In real implementation, this would update the password in the database
    print('[Mock] Password reset successful for: $email');
    return;
  }
}

