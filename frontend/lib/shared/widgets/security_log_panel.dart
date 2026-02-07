import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A log entry representing a security event
class SecurityLogEntry {
  final DateTime timestamp;
  final String eventType;
  final String message;
  final SecurityLogLevel level;
  final Map<String, dynamic>? details;

  SecurityLogEntry({
    required this.timestamp,
    required this.eventType,
    required this.message,
    required this.level,
    this.details,
  });

  factory SecurityLogEntry.fromJson(Map<String, dynamic> json) {
    return SecurityLogEntry(
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      eventType: json['eventType'] ?? 'UNKNOWN',
      message: json['message'] ?? '',
      level: SecurityLogLevel.fromString(json['level'] ?? 'info'),
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

enum SecurityLogLevel {
  info,
  success,
  warning,
  error,
  security;

  static SecurityLogLevel fromString(String value) {
    return SecurityLogLevel.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SecurityLogLevel.info,
    );
  }

  Color get color {
    switch (this) {
      case SecurityLogLevel.info:
        return Colors.blue;
      case SecurityLogLevel.success:
        return Colors.green;
      case SecurityLogLevel.warning:
        return Colors.orange;
      case SecurityLogLevel.error:
        return Colors.red;
      case SecurityLogLevel.security:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case SecurityLogLevel.info:
        return Icons.info_outline;
      case SecurityLogLevel.success:
        return Icons.check_circle_outline;
      case SecurityLogLevel.warning:
        return Icons.warning_amber_outlined;
      case SecurityLogLevel.error:
        return Icons.error_outline;
      case SecurityLogLevel.security:
        return Icons.security;
    }
  }
}

/// A panel that displays real-time security logs
/// 
/// This widget shows a collapsible panel at the bottom of the screen
/// that displays security events as they happen. Useful for educational
/// purposes to understand what security checks are being performed.
class SecurityLogPanel extends StatefulWidget {
  final Stream<SecurityLogEntry>? logStream;
  final int maxLogs;
  final bool initiallyExpanded;

  const SecurityLogPanel({
    super.key,
    this.logStream,
    this.maxLogs = 50,
    this.initiallyExpanded = false,
  });

  @override
  State<SecurityLogPanel> createState() => _SecurityLogPanelState();
}

class _SecurityLogPanelState extends State<SecurityLogPanel>
    with SingleTickerProviderStateMixin {
  final List<SecurityLogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _subscription;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  bool _isExpanded = false;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 0, end: 200).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }

    // Subscribe to log stream if provided
    _subscription = widget.logStream?.listen(_addLog);
    
    // Add initial demo logs
    _addDemoLogs();
  }

  void _addDemoLogs() {
    // These are local demonstration logs
    _addLog(SecurityLogEntry(
      timestamp: DateTime.now(),
      eventType: 'SYSTEM',
      message: 'Security Education Mode Active',
      level: SecurityLogLevel.info,
    ));
  }

  void _addLog(SecurityLogEntry log) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, log);
      if (_logs.length > widget.maxLogs) {
        _logs.removeLast();
      }
    });
    
    // Auto scroll to top
    if (_autoScroll && _scrollController.hasClients && _isExpanded) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  /// Add a log entry from external code
  void addSecurityLog({
    required String eventType,
    required String message,
    SecurityLogLevel level = SecurityLogLevel.info,
    Map<String, dynamic>? details,
  }) {
    _addLog(SecurityLogEntry(
      timestamp: DateTime.now(),
      eventType: eventType,
      message: message,
      level: level,
      details: details,
    ));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addDemoLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar (always visible)
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal,
                    color: Colors.green.shade400,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '📋 Security Log',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '${_logs.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_isExpanded) ...[
                    IconButton(
                      icon: Icon(
                        _autoScroll ? Icons.pause : Icons.play_arrow,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                      onPressed: () => setState(() => _autoScroll = !_autoScroll),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: _autoScroll ? 'Pause auto-scroll' : 'Resume auto-scroll',
                    ),
                    SizedBox(width: 12.w),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                      onPressed: _clearLogs,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Clear logs',
                    ),
                    SizedBox(width: 12.w),
                  ],
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.white70,
                    size: 20.sp,
                  ),
                ],
              ),
            ),
          ),
          
          // Log content (expandable)
          AnimatedBuilder(
            animation: _heightAnimation,
            builder: (context, child) {
              return SizedBox(
                height: _heightAnimation.value,
                child: child,
              );
            },
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'No security events yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12.sp,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return _buildLogEntry(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(SecurityLogEntry log) {
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11.sp,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(width: 8.w),
          
          // Level icon
          Icon(
            log.level.icon,
            color: log.level.color,
            size: 14.sp,
          ),
          SizedBox(width: 4.w),
          
          // Event type badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: log.level.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              log.eventType,
              style: TextStyle(
                color: log.level.color,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(width: 8.w),
          
          // Message
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.sp,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Global key for accessing the log panel from anywhere
final GlobalKey<_SecurityLogPanelState> securityLogPanelKey = GlobalKey<_SecurityLogPanelState>();

/// Helper function to add a log entry from anywhere in the app
void logSecurityEvent({
  required String eventType,
  required String message,
  SecurityLogLevel level = SecurityLogLevel.info,
  Map<String, dynamic>? details,
}) {
  securityLogPanelKey.currentState?.addSecurityLog(
    eventType: eventType,
    message: message,
    level: level,
    details: details,
  );
}
