import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/role_service.dart';
import '../../domain/entities/user.dart';

// Events
abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String? role;

  LoginRequested({
    required this.email, 
    required this.password,
    this.role,
  });
}

class LogoutRequested extends AuthEvent {}

class AuthStatusChanged extends AuthEvent {
  final bool isAuthenticated;

  AuthStatusChanged({required this.isAuthenticated});
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  AuthAuthenticated({required this.user});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final RoleService _roleService = RoleService();

  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthStatusChanged>(_onAuthStatusChanged);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Simulate authentication delay
      await Future.delayed(const Duration(seconds: 1));

      // Simple validation - accept any email/password for demo
      if (event.email.isNotEmpty && event.password.isNotEmpty) {
        // Create demo user with role based on email or provided role
        String userRole = event.role ?? _determineRoleFromEmail(event.email);
        
        final user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          email: event.email,
          name: _getNameFromEmail(event.email),
          role: userRole,
          lastLogin: DateTime.now(),
          isActive: true,
        );

        // Initialize role service with user
        _roleService.initialize(user);
        
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthError(message: 'Please enter email and password'));
      }
    } catch (e) {
      emit(AuthError(message: 'Login failed: ${e.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Clear role service
      _roleService.clear();
      
      // Simulate logout delay
      await Future.delayed(const Duration(milliseconds: 500));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Logout failed: ${e.toString()}'));
    }
  }

  void _onAuthStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.isAuthenticated) {
      // Create default demo user
      final user = User(
        id: 'demo_user',
        email: 'user@medusa.com',
        name: 'Demo User',
        role: 'patient',
        lastLogin: DateTime.now(),
        isActive: true,
      );
      _roleService.initialize(user);
      emit(AuthAuthenticated(user: user));
    } else {
      _roleService.clear();
      emit(AuthUnauthenticated());
    }
  }

  /// Determine user role from email for demo purposes
  String _determineRoleFromEmail(String email) {
    if (email.toLowerCase().contains('admin')) {
      return 'admin';
    } else if (email.toLowerCase().contains('doctor') || 
               email.toLowerCase().contains('dr.') ||
               email.toLowerCase().contains('physician')) {
      return 'doctor';
    } else {
      return 'patient'; // Default role
    }
  }

  /// Extract name from email for demo purposes
  String _getNameFromEmail(String email) {
    final username = email.split('@').first;
    final parts = username.split('.');
    if (parts.length >= 2) {
      return '${_capitalize(parts[0])} ${_capitalize(parts[1])}';
    } else {
      return _capitalize(username);
    }
  }

  /// Capitalize first letter of string
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
