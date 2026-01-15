import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Security error boundary component
/// Catches and handles security-related errors in the application, provides secure error recovery mechanism
class SecurityErrorBoundary extends StatefulWidget {
  /// Child component
  final Widget child;
  
  /// Error callback
  final void Function(FlutterErrorDetails)? onError;
  
  /// Whether to show detailed error information in debug mode
  final bool showErrorDetails;

  const SecurityErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.showErrorDetails = false,
  });

  @override
  State<SecurityErrorBoundary> createState() => _SecurityErrorBoundaryState();
}

class _SecurityErrorBoundaryState extends State<SecurityErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    
    // Set global error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error but don't expose sensitive information
      _handleError(details);
      
      // Call user-provided error handler
      widget.onError?.call(details);
    };
  }

  /// Handle error
  void _handleError(FlutterErrorDetails details) {
    if (mounted) {
      setState(() {
        _errorDetails = details;
        _hasError = true;
      });
    }

    // Print error in debug mode
    if (kDebugMode) {
      FlutterError.presentError(details);
    }

    // Log error to secure log (without sensitive information)
    _logSecureError(details);
  }

  /// Securely log error (remove sensitive information)
  void _logSecureError(FlutterErrorDetails details) {
    try {
      // Only log basic error information, no user data
      final sanitizedError = _sanitizeErrorMessage(details.exception.toString());
      
      if (kDebugMode) {
        debugPrint('Security Error Boundary: $sanitizedError');
      }
    } catch (e) {
      // Ignore log recording errors to avoid infinite recursion
      if (kDebugMode) {
        debugPrint('Failed to log security error: $e');
      }
    }
  }

  /// Clean sensitive information from error message
  String _sanitizeErrorMessage(String errorMessage) {
    // Remove parts that may contain sensitive information
    return errorMessage
        .replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '[EMAIL]')
        .replaceAll(RegExp(r'\b\d{3}-\d{3}-\d{4}\b'), '[PHONE]')
        .replaceAll(RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'), '[CARD]')
        .replaceAll(RegExp(r'password|token|secret|key', caseSensitive: false), '[SENSITIVE]');
  }

  /// Reset error state
  void _resetError() {
    if (mounted) {
      setState(() {
        _hasError = false;
        _errorDetails = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(context);
    }

    return widget.child;
  }

  /// Build error display component
  Widget _buildErrorWidget(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Error'),
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade800,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Application encountered an error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We have logged this issue and are working to fix it. Please try restarting the application.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (widget.showErrorDetails && kDebugMode && _errorDetails != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error Details (Debug Mode Only):',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sanitizeErrorMessage(_errorDetails!.exception.toString()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _resetError,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Security error boundary wrapper
/// Provides secure error boundary protection for the entire application
class SecurityErrorBoundaryWrapper extends StatelessWidget {
  final Widget child;
  final bool showErrorDetails;

  const SecurityErrorBoundaryWrapper({
    super.key,
    required this.child,
    this.showErrorDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return SecurityErrorBoundary(
      showErrorDetails: showErrorDetails,
      onError: (FlutterErrorDetails details) {
        // Additional error handling logic can be added here
        // For example: send error report to server (without sensitive information)
        _reportErrorSafely(details);
      },
      child: child,
    );
  }

  /// Safely report error (without user sensitive information)
  void _reportErrorSafely(FlutterErrorDetails details) {
    try {
      // A secure error reporting mechanism can be implemented here
      // Ensure no user sensitive information is included
      if (kDebugMode) {
        debugPrint('Error reported safely: ${details.exception.runtimeType}');
      }
    } catch (e) {
      // Ignore reporting errors to avoid infinite recursion
      if (kDebugMode) {
        debugPrint('Failed to report error safely: $e');
      }
    }
  }
}

/// Global error handler configuration
class SecurityErrorHandler {
  /// Initialize global error handling
  static void initialize() {
    // Set Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error but protect sensitive information
      _handleFlutterError(details);
    };

    // Set platform dispatcher error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      // Handle uncaught asynchronous errors
      _handlePlatformError(error, stack);
      return true;
    };
  }

  /// Handle Flutter error
  static void _handleFlutterError(FlutterErrorDetails details) {
    try {
      if (kDebugMode) {
        // Show complete error in debug mode
        FlutterError.presentError(details);
      } else {
        // In production mode, only log cleaned error information
        final sanitizedMessage = _sanitizeErrorMessage(details.exception.toString());
        debugPrint('Production Error: $sanitizedMessage');
      }
    } catch (e) {
      // Ensure error handler itself doesn't cause errors
      debugPrint('Error in error handler: $e');
    }
  }

  /// Handle platform error
  static void _handlePlatformError(Object error, StackTrace stack) {
    try {
      if (kDebugMode) {
        debugPrint('Platform Error: $error');
        debugPrint('Stack Trace: $stack');
      } else {
        final sanitizedMessage = _sanitizeErrorMessage(error.toString());
        debugPrint('Production Platform Error: $sanitizedMessage');
      }
    } catch (e) {
      debugPrint('Error in platform error handler: $e');
    }
  }

  /// Clean error message
  static String _sanitizeErrorMessage(String message) {
    return message
        .replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '[EMAIL]')
        .replaceAll(RegExp(r'\b\d{3}-\d{3}-\d{4}\b'), '[PHONE]')
        .replaceAll(RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'), '[CARD]')
        .replaceAll(RegExp(r'password|token|secret|key|api[_-]?key', caseSensitive: false), '[SENSITIVE]');
  }
}
