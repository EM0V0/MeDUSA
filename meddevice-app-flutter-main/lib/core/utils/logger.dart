import 'dart:developer' as developer;

/// Simple logger utility to replace print statements
class Logger {
  static const String _appName = 'MedDevice';
  
  /// Log info message
  static void info(String message, {String? tag}) {
    developer.log(
      message,
      name: _appName,
      level: 800, // Info level
      time: DateTime.now(),
    );
  }
  
  /// Log warning message
  static void warning(String message, {String? tag}) {
    developer.log(
      message,
      name: _appName,
      level: 900, // Warning level
      time: DateTime.now(),
    );
  }
  
  /// Log error message
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _appName,
      level: 1000, // Error level
      time: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Log debug message (only in debug mode)
  static void debug(String message, {String? tag}) {
    assert(() {
      developer.log(
        message,
        name: _appName,
        level: 700, // Debug level
        time: DateTime.now(),
      );
      return true;
    }());
  }
}

