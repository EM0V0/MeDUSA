import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<User> login(String email, String password) async {
    try {
      // Attempt remote login
      final user = await remoteDataSource.login(email, password);
      
      // Cache user data locally
      await localDataSource.cacheUser(user);
      
      return user;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> register(String name, String email, String password, String role) async {
    try {
      // Attempt remote registration
      final user = await remoteDataSource.register(name, email, password, role);
      
      // Cache user data locally
      await localDataSource.cacheUser(user);
      
      return user;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Attempt remote logout
      await remoteDataSource.logout();
    } catch (e) {
      // Continue with local logout even if remote fails
      print('Remote logout failed: $e');
    } finally {
      // Always clear local data
      await localDataSource.clearUser();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      // Get cached user from local storage
      return await localDataSource.getLastUser();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      await remoteDataSource.refreshToken();
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }
}