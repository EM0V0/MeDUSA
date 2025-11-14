
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source_mock.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../shared/services/encryption_service.dart';
import '../../shared/services/network_service.dart';

/// Dependency injection container for the app
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  /// Set to true to use mock authentication (no backend required)
  /// Set to false to use real backend authentication
  static const bool useMockAuth = false; // Using real backend API

  final Map<Type, dynamic> _services = {};

  T get<T>() {
    if (!_services.containsKey(T)) {
      throw Exception('Service of type $T is not registered');
    }
    return _services[T] as T;
  }

  void register<T>(T service) {
    _services[T] = service;
  }

  void registerLazySingleton<T>(T Function() factory) {
    _services[T] = factory;
  }

  /// Initialize all services
  Future<void> init() async {
    // Register core services
    await _registerCoreServices();
    
    // Register auth services
    await _registerAuthServices();
  }

  Future<void> _registerCoreServices() async {
    // Network service
    register<NetworkService>(NetworkServiceImpl.secure());
    
    // Encryption service
    register<EncryptionService>(EncryptionServiceImpl());
  }

  Future<void> _registerAuthServices() async {
    // Auth data sources - use mock or real based on configuration
    if (useMockAuth) {
      // Use mock authentication (no backend required)
      register<AuthRemoteDataSource>(
        AuthRemoteDataSourceMock(),
      );
      print('🧪 Using MOCK authentication (no backend required)');
      print('   Available test accounts:');
      print('   - demo@medusa.com (Patient)');
      print('   - doctor@medusa.com (Doctor)');
      print('   - patient@medusa.com (Patient)');
      print('   - admin@medusa.com (Admin)');
      print('   - nurse@medusa.com (Nurse)');
      print('   Any password will work for testing!');
    } else {
      // Use real backend authentication
      register<AuthRemoteDataSource>(
        AuthRemoteDataSourceImpl(
          networkService: get<NetworkService>(),
          encryptionService: get<EncryptionService>(),
        ),
      );
      print('🌐 Using REAL backend authentication');
    }
    
    // For now, create a simple local data source without storage service dependency
    register<AuthLocalDataSource>(
      AuthLocalDataSourceImpl(storageService: null),
    );
    
    // Auth repository
    register<AuthRepository>(
      AuthRepositoryImpl(
        remoteDataSource: get<AuthRemoteDataSource>(),
        localDataSource: get<AuthLocalDataSource>(),
      ),
    );
    
    // Auth BLoC
    register<AuthBloc>(
      AuthBloc(authRepository: get<AuthRepository>()),
    );
  }

  /// Clear all services (for testing)
  void clear() {
    _services.clear();
  }
}

/// Global instance for easy access
final serviceLocator = ServiceLocator();