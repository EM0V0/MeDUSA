import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/role_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

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

class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String role;

  RegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });
}

class LogoutRequested extends AuthEvent {}

class AuthStatusChanged extends AuthEvent {
  final bool isAuthenticated;

  AuthStatusChanged({required this.isAuthenticated});
}

class CheckAuthStatus extends AuthEvent {}

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
  final AuthRepository _authRepository;
  final RoleService _roleService = RoleService();

  AuthBloc({required AuthRepository authRepository}) 
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final user = await _authRepository.login(event.email, event.password);
      
      // Initialize role service with user
      _roleService.initialize(user);
      
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final user = await _authRepository.register(
        event.name,
        event.email,
        event.password,
        event.role,
      );
      
      // Initialize role service with user
      _roleService.initialize(user);
      
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.logout();
      
      // Clear role service
      _roleService.clear();
      
      emit(AuthUnauthenticated());
    } catch (e) {
      // Even if logout fails, clear local state
      _roleService.clear();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        _roleService.initialize(user);
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  void _onAuthStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.isAuthenticated) {
      // Check for existing user in storage
      add(CheckAuthStatus());
    } else {
      _roleService.clear();
      emit(AuthUnauthenticated());
    }
  }
}
