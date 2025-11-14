import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../features/admin/presentation/pages/audit_logs_page.dart';
import '../../features/admin/presentation/pages/device_management_page.dart';
import '../../features/admin/presentation/pages/system_settings_page.dart';
import '../../features/admin/presentation/pages/user_management_page.dart';
import '../../features/devices/presentation/pages/device_connection_page.dart';
import '../../features/devices/presentation/pages/device_scan_page.dart';
import '../../features/devices/presentation/pages/wifi_provision_page.dart';
import '../../features/devices/presentation/pages/winble_test_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/role_test_page.dart';
import '../../features/auth/presentation/pages/two_factor_setup_page.dart';
import '../../features/auth/presentation/pages/two_factor_verify_page.dart';
import '../../features/dashboard/presentation/pages/smart_dashboard_page.dart';
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/patients/presentation/pages/patient_detail_page.dart';
import '../../features/patients/presentation/pages/patients_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/symptoms/presentation/pages/symptoms_page.dart';
import '../../shared/widgets/layouts/auth_layout.dart';
import '../../shared/widgets/layouts/main_layout.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: '/dashboard',
    redirect: _redirect,
    routes: [
      // Auth Routes (without shell)
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthLayout(child: LoginPage()),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthLayout(child: RegisterPage()),
          transitionsBuilder: _slideTransition,
        ),
      ),
      
      // 2FA Routes
      GoRoute(
        path: '/2fa-setup',
        name: '2fa-setup',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: TwoFactorSetupPage(
              userEmail: email,
              onSetupComplete: () {
                GoRouter.of(context).go('/dashboard');
              },
              onCancel: () {
                GoRouter.of(context).go('/login');
              },
            ),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: '/2fa-verify',
        name: '2fa-verify',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: TwoFactorVerifyPage(
              userEmail: email,
              onVerificationComplete: (success) {
                if (success) {
                  GoRouter.of(context).go('/dashboard');
                } else {
                  GoRouter.of(context).go('/login');
                }
              },
              onCancel: () {
                GoRouter.of(context).go('/login');
              },
            ),
            transitionsBuilder: _slideTransition,
          );
        },
      ),

      // Main App Routes (with shell navigation)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          // Dashboard Route (Smart routing based on role)
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SmartDashboardPage(),
            ),
          ),

          // Patients Routes
          GoRoute(
            path: '/patients',
            name: 'patients',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PatientsPage(),
            ),
            routes: [
              GoRoute(
                path: ':patientId',
                name: 'patient-detail',
                pageBuilder: (context, state) {
                  final patientId = state.pathParameters['patientId']!;
                  return CustomTransitionPage(
                    key: state.pageKey,
                    child: PatientDetailPage(patientId: patientId),
                    transitionsBuilder: _slideTransition,
                  );
                },
              ),
            ],
          ),

          // Settings Route
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),

          // Messages Route
          GoRoute(
            path: '/messages',
            name: 'messages',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MessagesPage(),
            ),
          ),

          // Symptoms Route (for patients)
          GoRoute(
            path: '/symptoms',
            name: 'symptoms',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SymptomsPage(),
            ),
          ),

          // Reports Route
          GoRoute(
            path: '/reports',
            name: 'reports',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ReportsPage(),
            ),
          ),

          // Admin Routes
          GoRoute(
            path: '/user-management',
            name: 'user-management',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const UserManagementPage(),
            ),
          ),

          GoRoute(
            path: '/device-management',
            name: 'device-management',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DeviceManagementPage(),
            ),
          ),

          GoRoute(
            path: '/system-settings',
            name: 'system-settings',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SystemSettingsPage(),
            ),
          ),

          GoRoute(
            path: '/audit-logs',
            name: 'audit-logs',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AuditLogsPage(),
            ),
          ),

          // Device Connection Routes (for patients)
          GoRoute(
            path: '/device-scan',
            name: 'device-scan',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DeviceScanPage(),
            ),
          ),

          // WinBle Test Page (Windows BLE + WinRT Pairing)
          GoRoute(
            path: '/winble-test',
            name: 'winble-test',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const WinBleTestPage(),
            ),
          ),

          GoRoute(
            path: '/device-connection',
            name: 'device-connection',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DeviceConnectionPage(),
            ),
          ),

          // WiFi Provisioning Route (for setting up device WiFi credentials)
          GoRoute(
            path: '/wifi-provision',
            name: 'wifi-provision',
            pageBuilder: (context, state) {
              // Get the device from extra parameter (passed from device scan page)
              final device = state.extra as BluetoothDevice?;
              
              if (device == null) {
                // If no device provided, redirect to device scan
                return NoTransitionPage(
                  key: state.pageKey,
                  child: const DeviceScanPage(),
                );
              }
              
              return CustomTransitionPage(
                key: state.pageKey,
                child: WiFiProvisionPage(device: device),
                transitionsBuilder: _slideTransition,
              );
            },
          ),

          // Profile Route
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfilePage(),
            ),
          ),

          // Role Test Route (for development/testing)
          GoRoute(
            path: '/role-test',
            name: 'role-test',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const RoleTestPage(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorPage(error: state.error),
  );

  // Authentication state check using BLoC
  static String? _redirect(BuildContext context, GoRouterState state) {
    try {
      final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
      final authState = authBloc.state;
      
      final isAuthenticated = authState is AuthAuthenticated;
      final isAuthPage = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register' ||
                         state.matchedLocation.startsWith('/2fa');

      // Allow access to 2FA pages without full authentication
      if (state.matchedLocation.startsWith('/2fa')) {
        return null;
      }

      // If not authenticated and not on auth page, redirect to login
      if (!isAuthenticated && !isAuthPage) {
        debugPrint('[Router] User not authenticated, redirecting to login');
        return '/login';
      }

      // If authenticated and on auth page, redirect to dashboard
      if (isAuthenticated && isAuthPage) {
        debugPrint('[Router] User authenticated, redirecting from auth page to dashboard');
        return '/dashboard';
      }

      // No redirect needed
      return null;
    } catch (e) {
      debugPrint('[Router] Error in redirect: $e');
      // If BLoC is not available (app initializing), allow auth pages
      final isAuthPage = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register' ||
                         state.matchedLocation.startsWith('/2fa');
      return isAuthPage ? null : '/login';
    }
  }

  // Custom transition animations
  static Widget _slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
      ),
      child: child,
    );
  }

  // Navigation helper methods
  static void goToLogin(BuildContext context) {
    GoRouter.of(context).goNamed('login');
  }

  static void goToRegister(BuildContext context) {
    GoRouter.of(context).goNamed('register');
  }

  static void goToDashboard(BuildContext context) {
    GoRouter.of(context).goNamed('dashboard');
  }

  static void goToPatients(BuildContext context) {
    GoRouter.of(context).goNamed('patients');
  }

  static void goToPatientDetail(BuildContext context, String patientId) {
    GoRouter.of(context).goNamed('patient-detail', pathParameters: {'patientId': patientId});
  }

  static void goToSettings(BuildContext context) {
    GoRouter.of(context).goNamed('settings');
  }

  static void goToReports(BuildContext context) {
    GoRouter.of(context).goNamed('reports');
  }

  static void goToProfile(BuildContext context) {
    GoRouter.of(context).goNamed('profile');
  }

  static void logout(BuildContext context) {
    final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
    authBloc.add(LogoutRequested());
    GoRouter.of(context).goNamed('login');
  }
}

// Error page for handling navigation errors
class ErrorPage extends StatelessWidget {
  final Exception? error;

  const ErrorPage({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => AppRouter.goToDashboard(context),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}