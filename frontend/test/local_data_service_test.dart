import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:medusa_app/shared/services/local_data_service.dart';
import 'dart:io';

/// Test suite for LocalDataService
/// 
/// Tests offline data caching, sync queue, and validation functionality
void main() {
  late LocalDataService localDataService;
  late String testPath;

  setUpAll(() async {
    // Initialize Hive with a temporary directory for tests
    testPath = '${Directory.systemTemp.path}/medusa_test_hive';
    Hive.init(testPath);
  });

  setUp(() async {
    // Create a fresh service for each test
    localDataService = LocalDataService();
    await localDataService.initialize();
  });

  tearDown(() async {
    // Clean up after each test
    await localDataService.dispose();
    
    // Clear test boxes
    try {
      await Hive.deleteBoxFromDisk('tremor_data_cache');
      await Hive.deleteBoxFromDisk('sync_queue');
      await Hive.deleteBoxFromDisk('validation_log');
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  tearDownAll(() async {
    // Clean up test directory
    try {
      final dir = Directory(testPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  group('ValidationResult', () {
    test('should create valid result', () {
      const result = ValidationResult(
        isValid: true,
        errors: [],
        warnings: [],
        validatedData: {'test': 'data'},
      );
      
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.validatedData, isNotNull);
    });

    test('should create invalid result', () {
      const result = ValidationResult(
        isValid: false,
        errors: ['Error 1', 'Error 2'],
        warnings: ['Warning 1'],
      );
      
      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.warnings.length, 1);
      expect(result.validatedData, isNull);
    });

    test('toString should show counts', () {
      const result = ValidationResult(
        isValid: false,
        errors: ['Error'],
        warnings: ['Warning 1', 'Warning 2'],
      );
      
      expect(result.toString(), contains('isValid: false'));
      expect(result.toString(), contains('errors: 1'));
      expect(result.toString(), contains('warnings: 2'));
    });
  });

  group('Data Validation', () {
    test('should validate valid tremor data', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().toIso8601String(),
        'tremor_score': 5.5,
        'dominant_freq': 5.0,
        'rms': 0.25,
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('should fail validation for missing required fields', () {
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        // Missing patient_id and tremor_score
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.errors, contains('Missing required field: patient_id'));
      expect(result.errors, contains('Missing required field: tremor_score'));
    });

    test('should fail validation for out-of-range tremor score', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().toIso8601String(),
        'tremor_score': 15.0, // Out of range (0-10)
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, false);
      expect(result.errors, contains(contains('out of valid range')));
    });

    test('should fail validation for invalid tremor score type', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().toIso8601String(),
        'tremor_score': 'not a number',
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, false);
      expect(result.errors, contains('Tremor score must be a number'));
    });

    test('should warn for unusual frequency', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().toIso8601String(),
        'tremor_score': 5.0,
        'dominant_freq': 25.0, // Outside typical range
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, true); // Still valid, just a warning
      expect(result.warnings, isNotEmpty);
      expect(result.warnings, contains(contains('outside typical range')));
    });

    test('should fail validation for negative RMS', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().toIso8601String(),
        'tremor_score': 5.0,
        'rms': -0.5,
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, false);
      expect(result.errors, contains('RMS value cannot be negative'));
    });

    test('should flag Parkinsonian tremor frequency', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().toIso8601String(),
        'tremor_score': 5.0,
        'dominant_freq': 5.0, // Typical Parkinsonian range (4-6 Hz)
      };
      
      localDataService.validateTremorData(data);
      
      // Data should be flagged
      expect(data['is_parkinsonian'], true);
    });

    test('should accept timestamp as string', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': '2026-02-03T12:00:00Z',
        'tremor_score': 5.0,
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, true);
    });

    test('should accept timestamp as milliseconds', () {
      final data = {
        'patient_id': 'PAT-001',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'tremor_score': 5.0,
      };
      
      final result = localDataService.validateTremorData(data);
      
      expect(result.isValid, true);
    });
  });

  group('Cache Operations', () {
    test('should cache and retrieve tremor data', () async {
      final testData = [
        {'patient_id': 'PAT-001', 'tremor_score': 5.0},
        {'patient_id': 'PAT-001', 'tremor_score': 6.0},
      ];
      
      await localDataService.cacheTremorData(
        patientId: 'PAT-001',
        data: testData,
      );
      
      final retrieved = await localDataService.getCachedTremorData(
        patientId: 'PAT-001',
      );
      
      expect(retrieved, isNotNull);
      expect(retrieved!.length, 2);
      expect(retrieved[0]['tremor_score'], 5.0);
    });

    test('should return null for non-existent cache', () async {
      final retrieved = await localDataService.getCachedTremorData(
        patientId: 'NON_EXISTENT',
      );
      
      expect(retrieved, isNull);
    });

    test('should clear cache', () async {
      final testData = [
        {'patient_id': 'PAT-001', 'tremor_score': 5.0},
      ];
      
      await localDataService.cacheTremorData(
        patientId: 'PAT-001',
        data: testData,
      );
      
      await localDataService.clearTremorCache('PAT-001');
      
      final retrieved = await localDataService.getCachedTremorData(
        patientId: 'PAT-001',
      );
      
      expect(retrieved, isNull);
    });
  });

  group('Sync Queue Operations', () {
    test('should add item to sync queue', () async {
      final queueId = await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'patient_id': 'PAT-001', 'tremor_score': 5.0},
        patientId: 'PAT-001',
      );
      
      expect(queueId, isNotEmpty);
      expect(queueId, startsWith('tremor_data_'));
    });

    test('should retrieve pending sync items', () async {
      await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'test': 1},
      );
      await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'test': 2},
      );
      
      final pending = await localDataService.getPendingSyncItems();
      
      expect(pending.length, 2);
      expect(pending[0]['status'], 'pending');
    });

    test('should mark item as completed', () async {
      final queueId = await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'test': 1},
      );
      
      await localDataService.markSyncItemCompleted(queueId);
      
      final pending = await localDataService.getPendingSyncItems();
      
      expect(pending, isEmpty);
    });

    test('should mark item as failed with error', () async {
      final queueId = await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'test': 1},
      );
      
      await localDataService.markSyncItemFailed(queueId, 'Network error');
      
      final pending = await localDataService.getPendingSyncItems();
      
      // Failed items are not in pending
      expect(pending, isEmpty);
    });

    test('should clear completed items', () async {
      final queueId1 = await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'test': 1},
      );
      await localDataService.addToSyncQueue(
        type: 'tremor_data',
        data: {'test': 2},
      );
      
      await localDataService.markSyncItemCompleted(queueId1);
      
      final clearedCount = await localDataService.clearCompletedSyncItems();
      
      expect(clearedCount, 1);
    });
  });

  group('Storage Statistics', () {
    test('should return storage statistics', () async {
      await localDataService.cacheTremorData(
        patientId: 'PAT-001',
        data: [{'test': 1}],
      );
      
      await localDataService.addToSyncQueue(
        type: 'test',
        data: {'test': 1},
      );
      
      final stats = await localDataService.getStorageStatistics();
      
      expect(stats['tremor_cache_entries'], 1);
      expect(stats['sync_queue_pending'], 1);
      expect(stats['sync_queue_total'], 1);
      expect(stats['last_checked'], isNotNull);
    });
  });
}
