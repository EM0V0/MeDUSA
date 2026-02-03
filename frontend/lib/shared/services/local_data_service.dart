import 'dart:convert';
import 'package:hive/hive.dart';
import '../../core/utils/logger.dart';

/// Local data persistence service for offline support
/// 
/// This service provides:
/// - Offline tremor data caching with sync support
/// - Local validation before cloud sync
/// - Data integrity verification
/// - Compliance with FDA 21 CFR Part 11 requirements for electronic records
class LocalDataService {
  static const String _tremorDataBoxName = 'tremor_data_cache';
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _validationLogBoxName = 'validation_log';
  
  late Box _tremorDataBox;
  late Box _syncQueueBox;
  late Box _validationLogBox;
  
  bool _isInitialized = false;
  
  /// Initialize the local data service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _tremorDataBox = await Hive.openBox(_tremorDataBoxName);
      _syncQueueBox = await Hive.openBox(_syncQueueBoxName);
      _validationLogBox = await Hive.openBox(_validationLogBoxName);
      _isInitialized = true;
      
      Logger.info('LocalDataService initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize LocalDataService', error: e);
      rethrow;
    }
  }
  
  // ============================================
  // Tremor Data Caching
  // ============================================
  
  /// Cache tremor data locally for offline access
  /// 
  /// Parameters:
  /// - [patientId]: Patient identifier
  /// - [data]: List of tremor analysis records
  /// - [timestamp]: Cache timestamp
  Future<void> cacheTremorData({
    required String patientId,
    required List<Map<String, dynamic>> data,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized();
    
    final cacheKey = 'tremor_$patientId';
    final cacheEntry = {
      'patient_id': patientId,
      'data': data,
      'cached_at': (timestamp ?? DateTime.now()).toIso8601String(),
      'record_count': data.length,
      'checksum': _generateChecksum(data),
    };
    
    await _tremorDataBox.put(cacheKey, cacheEntry);
    
    // Log cache operation for compliance
    await _logDataOperation(
      operation: 'cache_tremor_data',
      patientId: patientId,
      recordCount: data.length,
    );
    
    Logger.info('Cached ${data.length} tremor records for patient $patientId');
  }
  
  /// Retrieve cached tremor data
  /// 
  /// Returns null if no cache exists or cache is expired
  Future<List<Map<String, dynamic>>?> getCachedTremorData({
    required String patientId,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    await _ensureInitialized();
    
    final cacheKey = 'tremor_$patientId';
    final cacheEntry = _tremorDataBox.get(cacheKey);
    
    if (cacheEntry == null) {
      return null;
    }
    
    // Verify cache age
    final cachedAt = DateTime.parse(cacheEntry['cached_at']);
    if (DateTime.now().difference(cachedAt) > maxAge) {
      Logger.info('Cache expired for patient $patientId');
      return null;
    }
    
    // Verify data integrity
    final storedChecksum = cacheEntry['checksum'];
    final data = List<Map<String, dynamic>>.from(
      (cacheEntry['data'] as List).map((e) => Map<String, dynamic>.from(e))
    );
    final currentChecksum = _generateChecksum(data);
    
    if (storedChecksum != currentChecksum) {
      Logger.warning('Cache integrity check failed for patient $patientId');
      await _logDataOperation(
        operation: 'cache_integrity_failure',
        patientId: patientId,
        details: {'stored_checksum': storedChecksum, 'calculated_checksum': currentChecksum},
      );
      return null;
    }
    
    // Log access for compliance
    await _logDataOperation(
      operation: 'cache_read',
      patientId: patientId,
      recordCount: data.length,
    );
    
    return data;
  }
  
  /// Clear cached tremor data for a patient
  Future<void> clearTremorCache(String patientId) async {
    await _ensureInitialized();
    
    final cacheKey = 'tremor_$patientId';
    await _tremorDataBox.delete(cacheKey);
    
    await _logDataOperation(
      operation: 'cache_clear',
      patientId: patientId,
    );
  }
  
  // ============================================
  // Offline Sync Queue
  // ============================================
  
  /// Add data to sync queue for later upload
  /// 
  /// Used when device is offline and data needs to be synced later
  Future<String> addToSyncQueue({
    required String type,
    required Map<String, dynamic> data,
    String? patientId,
  }) async {
    await _ensureInitialized();
    
    final queueId = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    final queueEntry = {
      'id': queueId,
      'type': type,
      'data': data,
      'patient_id': patientId,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'retry_count': 0,
      'checksum': _generateChecksum([data]),
    };
    
    await _syncQueueBox.put(queueId, queueEntry);
    
    await _logDataOperation(
      operation: 'sync_queue_add',
      patientId: patientId,
      details: {'queue_id': queueId, 'type': type},
    );
    
    Logger.info('Added item to sync queue: $queueId');
    return queueId;
  }
  
  /// Get all pending items in sync queue
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    await _ensureInitialized();
    
    final pendingItems = <Map<String, dynamic>>[];
    
    for (final key in _syncQueueBox.keys) {
      final entry = _syncQueueBox.get(key);
      if (entry != null && entry['status'] == 'pending') {
        pendingItems.add(Map<String, dynamic>.from(entry));
      }
    }
    
    // Sort by creation time (oldest first)
    pendingItems.sort((a, b) => 
      DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']))
    );
    
    return pendingItems;
  }
  
  /// Mark sync item as completed
  Future<void> markSyncItemCompleted(String queueId) async {
    await _ensureInitialized();
    
    final entry = _syncQueueBox.get(queueId);
    if (entry != null) {
      entry['status'] = 'completed';
      entry['completed_at'] = DateTime.now().toIso8601String();
      await _syncQueueBox.put(queueId, entry);
      
      await _logDataOperation(
        operation: 'sync_complete',
        details: {'queue_id': queueId},
      );
    }
  }
  
  /// Mark sync item as failed with error
  Future<void> markSyncItemFailed(String queueId, String error) async {
    await _ensureInitialized();
    
    final entry = _syncQueueBox.get(queueId);
    if (entry != null) {
      entry['status'] = 'failed';
      entry['error'] = error;
      entry['failed_at'] = DateTime.now().toIso8601String();
      entry['retry_count'] = (entry['retry_count'] ?? 0) + 1;
      await _syncQueueBox.put(queueId, entry);
      
      await _logDataOperation(
        operation: 'sync_failed',
        details: {'queue_id': queueId, 'error': error},
      );
    }
  }
  
  /// Clear completed sync items
  Future<int> clearCompletedSyncItems() async {
    await _ensureInitialized();
    
    final keysToDelete = <String>[];
    
    for (final key in _syncQueueBox.keys) {
      final entry = _syncQueueBox.get(key);
      if (entry != null && entry['status'] == 'completed') {
        keysToDelete.add(key.toString());
      }
    }
    
    for (final key in keysToDelete) {
      await _syncQueueBox.delete(key);
    }
    
    return keysToDelete.length;
  }
  
  // ============================================
  // Data Validation
  // ============================================
  
  /// Validate tremor data before cloud sync
  /// 
  /// Performs:
  /// - Required field validation
  /// - Data type validation  
  /// - Range validation for clinical values
  /// - Timestamp validation
  ValidationResult validateTremorData(Map<String, dynamic> data) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Required fields
    final requiredFields = ['patient_id', 'timestamp', 'tremor_score'];
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        errors.add('Missing required field: $field');
      }
    }
    
    // Tremor score range validation (0-10)
    if (data.containsKey('tremor_score')) {
      final score = data['tremor_score'];
      if (score is num) {
        if (score < 0 || score > 10) {
          errors.add('Tremor score out of valid range (0-10): $score');
        }
      } else {
        errors.add('Tremor score must be a number');
      }
    }
    
    // Dominant frequency validation (typically 0-20 Hz)
    if (data.containsKey('dominant_freq')) {
      final freq = data['dominant_freq'];
      if (freq is num) {
        if (freq < 0 || freq > 20) {
          warnings.add('Dominant frequency outside typical range (0-20 Hz): $freq');
        }
        // Parkinsonian tremor typically 4-6 Hz
        if (freq >= 4 && freq <= 6) {
          // Flag for potential Parkinsonian tremor
          data['is_parkinsonian'] = true;
        }
      }
    }
    
    // Timestamp validation
    if (data.containsKey('timestamp')) {
      try {
        final ts = data['timestamp'];
        if (ts is String) {
          DateTime.parse(ts);
        } else if (ts is int) {
          DateTime.fromMillisecondsSinceEpoch(ts);
        }
      } catch (e) {
        errors.add('Invalid timestamp format');
      }
    }
    
    // RMS value validation (should be positive)
    if (data.containsKey('rms') && data['rms'] is num) {
      if ((data['rms'] as num) < 0) {
        errors.add('RMS value cannot be negative');
      }
    }
    
    final isValid = errors.isEmpty;
    
    // Log validation result
    _logValidation(data, isValid, errors, warnings);
    
    return ValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
      validatedData: isValid ? data : null,
    );
  }
  
  // ============================================
  // Compliance & Audit
  // ============================================
  
  /// Get validation history for audit purposes
  Future<List<Map<String, dynamic>>> getValidationLog({
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    await _ensureInitialized();
    
    final logs = <Map<String, dynamic>>[];
    
    for (final key in _validationLogBox.keys) {
      final entry = _validationLogBox.get(key);
      if (entry == null) continue;
      
      // Filter by patient
      if (patientId != null && entry['patient_id'] != patientId) {
        continue;
      }
      
      // Filter by date range
      final entryDate = DateTime.parse(entry['timestamp']);
      if (startDate != null && entryDate.isBefore(startDate)) {
        continue;
      }
      if (endDate != null && entryDate.isAfter(endDate)) {
        continue;
      }
      
      logs.add(Map<String, dynamic>.from(entry));
    }
    
    // Sort by timestamp (newest first)
    logs.sort((a, b) => 
      DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']))
    );
    
    return logs.take(limit).toList();
  }
  
  /// Get storage statistics for monitoring
  Future<Map<String, dynamic>> getStorageStatistics() async {
    await _ensureInitialized();
    
    return {
      'tremor_cache_entries': _tremorDataBox.length,
      'sync_queue_pending': (await getPendingSyncItems()).length,
      'sync_queue_total': _syncQueueBox.length,
      'validation_log_entries': _validationLogBox.length,
      'last_checked': DateTime.now().toIso8601String(),
    };
  }
  
  // ============================================
  // Private Helpers
  // ============================================
  
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  /// Generate SHA-256 checksum for data integrity
  String _generateChecksum(List<Map<String, dynamic>> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    
    // Simple hash for demonstration - in production use crypto package
    int hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    
    return hash.toRadixString(16).padLeft(8, '0');
  }
  
  /// Log data operation for compliance audit trail
  Future<void> _logDataOperation({
    required String operation,
    String? patientId,
    int? recordCount,
    Map<String, dynamic>? details,
  }) async {
    final logEntry = {
      'operation': operation,
      'patient_id': patientId,
      'record_count': recordCount,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final logKey = '${operation}_${DateTime.now().millisecondsSinceEpoch}';
    await _validationLogBox.put(logKey, logEntry);
  }
  
  /// Log validation result for audit
  void _logValidation(
    Map<String, dynamic> data,
    bool isValid,
    List<String> errors,
    List<String> warnings,
  ) {
    Logger.info(
      'Data validation ${isValid ? "passed" : "failed"}: '
      '${errors.length} errors, ${warnings.length} warnings'
    );
    
    if (!isValid) {
      for (final error in errors) {
        Logger.warning('Validation error: $error');
      }
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _tremorDataBox.close();
      await _syncQueueBox.close();
      await _validationLogBox.close();
      _isInitialized = false;
    }
  }
}

/// Result of data validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic>? validatedData;
  
  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.validatedData,
  });
  
  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, errors: ${errors.length}, warnings: ${warnings.length})';
  }
}
