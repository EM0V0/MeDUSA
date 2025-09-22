import '../../../../shared/services/encryption_service.dart';
import '../../../../shared/services/network_service.dart';
import '../../domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String name, String email, String password, String role);
  Future<void> logout();
  Future<void> refreshToken();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final NetworkService networkService;
  final EncryptionService encryptionService;

  AuthRemoteDataSourceImpl({
    required this.networkService,
    required this.encryptionService,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      final data = {
        'email': email,
        'password': password,
      };

      final response = await networkService.post(
        '/auth/login',
        data: data,
      );

      // Extract and store tokens from backend response
      final responseData = response.data;
      if (responseData['data'] != null) {
        final loginData = responseData['data'];
        
        // Store access token in network service for future requests
        if (loginData['access_token'] != null) {
          networkService.setAuthToken(loginData['access_token']);
        }
        
        // TODO: Store refresh token in secure storage
        // final refreshToken = loginData['refresh_token'];
        
        return User.fromJson(loginData['user']);
      } else {
        throw Exception('Invalid response format from server');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> register(String name, String email, String password, String role) async {
    try {
      // Split name into first_name and last_name
      final nameParts = name.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : name;
      final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';
      
      // Convert role to proper format for backend enum
      String backendRole;
      switch (role.toLowerCase()) {
        case 'doctor':
          backendRole = 'Doctor';
          break;
        case 'nurse':
          backendRole = 'Nurse';
          break;
        case 'technician':
          backendRole = 'Technician';
          break;
        case 'admin':
          backendRole = 'Admin';
          break;
        case 'patient':
          backendRole = 'Patient';
          break;
        default:
          backendRole = 'Patient'; // Default to Patient if unknown
      }
      
      final data = {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': backendRole, // Use proper enum format
      };

      final response = await networkService.post(
        '/auth/register',
        data: data,
      );

      // Handle registration response similar to login
      final responseData = response.data;
      if (responseData['data'] != null) {
        final registrationData = responseData['data'];
        
        // Store access token if provided
        if (registrationData['access_token'] != null) {
          networkService.setAuthToken(registrationData['access_token']);
        }
        
        return User.fromJson(registrationData['user']);
      } else {
        throw Exception('Invalid response format from server');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await networkService.post('/auth/logout');
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      await networkService.post('/auth/refresh');
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }
}
