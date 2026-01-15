import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/role_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/exceptions/auth_exceptions.dart';

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

class MfaLoginRequested extends AuthEvent {
  final String tempToken;
  final String code;

  MfaLoginRequested({
    required this.tempToken,
    required this.code,
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

class SendVerificationCodeRequested extends AuthEvent {
  final String email;

  SendVerificationCodeRequested({required this.email});
}

class VerifyEmailRequested extends AuthEvent {
  final String email;
  final String code;

  VerifyEmailRequested({required this.email, required this.code});
}

class RequestPasswordResetRequested extends AuthEvent {
  final String email;

  RequestPasswordResetRequested({required this.email});
}

class VerifyResetCodeRequested extends AuthEvent {
  final String email;
  final String code;

  VerifyResetCodeRequested({required this.email, required this.code});
}

class ResetPasswordRequested extends AuthEvent {
  final String email;
  final String newPassword;
  final String code;

  ResetPasswordRequested({
    required this.email,
    required this.newPassword,
    required this.code,
  });
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  AuthAuthenticated({required this.user});
}

class AuthMfaRequired extends AuthState {
  final String tempToken;

  AuthMfaRequired({required this.tempToken});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}

class VerificationCodeSent extends AuthState {
  final String email;

  VerificationCodeSent({required this.email});
}

class EmailVerified extends AuthState {
  final String email;

  EmailVerified({required this.email});
}

class PasswordResetCodeSent extends AuthState {
  final String email;

  PasswordResetCodeSent({required this.email});
}

class ResetCodeVerified extends AuthState {
  final String email;

  ResetCodeVerified({required this.email});
}

class PasswordResetSuccess extends AuthState {}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final RoleService _roleService = RoleService();

  AuthBloc({required AuthRepository authRepository}) 
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<MfaLoginRequested>(_onMfaLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SendVerificationCodeRequested>(_onSendVerificationCodeRequested);
    on<VerifyEmailRequested>(_onVerifyEmailRequested);
    on<RequestPasswordResetRequested>(_onRequestPasswordResetRequested);
    on<VerifyResetCodeRequested>(_onVerifyResetCodeRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
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
    } on MfaRequiredException catch (e) {
      emit(AuthMfaRequired(tempToken: e.tempToken));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onMfaLoginRequested(
    MfaLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final user = await _authRepository.mfaLogin(event.tempToken, event.code);
      
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
  
  Future<void> _onSendVerificationCodeRequested(
    SendVerificationCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.sendVerificationCode(event.email);
      emit(VerificationCodeSent(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  Future<void> _onVerifyEmailRequested(
    VerifyEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.verifyEmail(event.email, event.code);
      emit(EmailVerified(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  Future<void> _onRequestPasswordResetRequested(
    RequestPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.requestPasswordReset(event.email);
      emit(PasswordResetCodeSent(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  Future<void> _onVerifyResetCodeRequested(
    VerifyResetCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.verifyResetCode(event.email, event.code);
      emit(ResetCodeVerified(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authRepository.resetPassword(event.email, event.newPassword, event.code);
      emit(PasswordResetSuccess());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
