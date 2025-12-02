import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'secure_network_service.dart';

/// Network service abstract class
abstract class NetworkService {
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  });

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  });

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  });

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  });

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  });

  void setAuthToken(String token);
  void clearAuthToken();
}

/// Network service implementation with TLS 1.3 security
class NetworkServiceImpl implements NetworkService {
  final Dio _dio;
  final SecureNetworkService _secureService;

  NetworkServiceImpl(this._dio) : _secureService = SecureNetworkService() {
    _setupInterceptors();
  }

  /// Factory constructor for medical-grade secure networking
  factory NetworkServiceImpl.secure() {
    final secureService = SecureNetworkService();
    return NetworkServiceImpl(secureService.dio);
  }

  void _setupInterceptors() {
    // Request interceptor for adding auth token and API version prefix
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Automatically prepend /api/v1 to all paths if not already present
          if (!options.path.startsWith('/api/v1') && !options.path.startsWith('http')) {
            options.path = '/api/v1${options.path}';
          }
          
          // Add any default headers or processing here
          options.headers['Accept'] = 'application/json';
          options.headers['Content-Type'] = 'application/json';
          
          debugPrint('[NetworkService] Request: ${options.method} ${options.path}');
          
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Handle successful responses
          debugPrint('[NetworkService] Response: ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          // Handle errors globally
          _handleError(error);
          handler.next(error);
        },
      ),
    );
  }

  void _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        debugPrint('Network timeout: ${error.message}');
        break;
      case DioExceptionType.badResponse:
        debugPrint('Bad response: ${error.response?.statusCode} - ${error.response?.data}');
        break;
      case DioExceptionType.cancel:
        debugPrint('Request cancelled: ${error.message}');
        break;
      case DioExceptionType.connectionError:
        debugPrint('Connection error: ${error.message}');
        break;
      case DioExceptionType.unknown:
        debugPrint('Unknown error: ${error.message}');
        break;
      case DioExceptionType.badCertificate:
        debugPrint('Bad certificate: ${error.message}');
        break;
    }
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  @override
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
} 