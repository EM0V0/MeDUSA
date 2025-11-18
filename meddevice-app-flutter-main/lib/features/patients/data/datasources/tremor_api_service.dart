import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/secure_network_service.dart';
import '../models/tremor_analysis.dart';

/// API service for fetching tremor analysis data from AWS
class TremorApiService {
  static const String _tag = 'TremorApiService';
  final SecureNetworkService _networkService;

  TremorApiService({SecureNetworkService? networkService})
      : _networkService = networkService ?? SecureNetworkService(baseUrl: AppConstants.tremorApiUrl);

  /// Get tremor analysis data for a specific patient
  /// 
  /// [patientId] - Patient ID to fetch data for
  /// [deviceId] - Optional device ID filter
  /// [startTime] - Start of time range (default: 24 hours ago)
  /// [endTime] - End of time range (default: now)
  /// [limit] - Maximum number of results (default: 100)
  Future<List<TremorAnalysis>> getPatientTremorData({
    required String patientId,
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'patient_id': patientId,
        'limit': limit,
      };

      if (deviceId != null) {
        queryParams['device_id'] = deviceId;
      }

      if (startTime != null) {
        queryParams['start_time'] = startTime.millisecondsSinceEpoch ~/ 1000;
      }

      if (endTime != null) {
        queryParams['end_time'] = endTime.millisecondsSinceEpoch ~/ 1000;
      }

      final response = await _networkService.get(
        '/api/v1/tremor/analysis',
        queryParameters: queryParams,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> dataList = response['data'] as List<dynamic>;
        return dataList
            .map((json) => TremorAnalysis.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('$_tag: Error fetching tremor data: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get tremor analysis data for a specific device
  /// 
  /// [deviceId] - Device ID to fetch data for
  /// [startTime] - Start of time range
  /// [endTime] - End of time range
  /// [limit] - Maximum number of results
  Future<List<TremorAnalysis>> getDeviceTremorData({
    required String deviceId,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'device_id': deviceId,
        'limit': limit,
      };

      if (startTime != null) {
        queryParams['start_time'] = startTime.millisecondsSinceEpoch ~/ 1000;
      }

      if (endTime != null) {
        queryParams['end_time'] = endTime.millisecondsSinceEpoch ~/ 1000;
      }

      final response = await _networkService.get(
        '/api/v1/tremor/analysis',
        queryParameters: queryParams,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> dataList = response['data'] as List<dynamic>;
        return dataList
            .map((json) => TremorAnalysis.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('$_tag: Error fetching device tremor data: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get latest tremor analysis for a patient
  Future<TremorAnalysis?> getLatestTremorAnalysis(String patientId) async {
    try {
      final results = await getPatientTremorData(
        patientId: patientId,
        limit: 1,
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('$_tag: Error fetching latest tremor analysis: $e');
      return null;
    }
  }

  /// Get tremor statistics for a patient over a time period
  Future<Map<String, dynamic>> getTremorStatistics({
    required String patientId,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final data = await getPatientTremorData(
        patientId: patientId,
        startTime: startTime,
        endTime: endTime,
        limit: 1000,
      );

      if (data.isEmpty) {
        return {
          'average_score': 0.0,
          'max_score': 0.0,
          'min_score': 0.0,
          'parkinsonian_episodes': 0,
          'total_readings': 0,
        };
      }

      final scores = data.map((a) => a.tremorScore).toList();
      final parkinsonianCount = data.where((a) => a.isParkinsonian).length;

      return {
        'average_score': scores.reduce((a, b) => a + b) / scores.length,
        'max_score': scores.reduce((a, b) => a > b ? a : b),
        'min_score': scores.reduce((a, b) => a < b ? a : b),
        'parkinsonian_episodes': parkinsonianCount,
        'total_readings': data.length,
      };
    } catch (e) {
      debugPrint('$_tag: Error fetching tremor statistics: $e');
      return {
        'average_score': 0.0,
        'max_score': 0.0,
        'min_score': 0.0,
        'parkinsonian_episodes': 0,
        'total_readings': 0,
      };
    }
  }

  /// Mock data generator for testing (remove in production)
  Future<List<TremorAnalysis>> getMockTremorData({
    required String patientId,
    int count = 20,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();
    final data = <TremorAnalysis>[];

    for (int i = count - 1; i >= 0; i--) {
      final timestamp = now.subtract(Duration(minutes: i * 5));
      final tremorIndex = 0.2 + (0.6 * (0.5 + 0.5 * (i % 3) / 3));
      
      data.add(TremorAnalysis(
        deviceId: 'DEV-001',
        patientId: patientId,
        patientName: 'Test Patient',
        analysisTimestamp: timestamp,
        windowStart: timestamp.subtract(const Duration(minutes: 5)),
        windowEnd: timestamp,
        sampleCount: 150,
        samplingRate: 100,
        rms: 9.8 + (tremorIndex * 2),
        dominantFreq: 3.0 + (tremorIndex * 3),
        tremorPower: 15000 + (tremorIndex * 5000),
        tremorIndex: tremorIndex,
        isParkinsonian: tremorIndex > 0.4,
        processedAt: timestamp.add(const Duration(seconds: 5)),
      ));
    }

    return data;
  }
}
