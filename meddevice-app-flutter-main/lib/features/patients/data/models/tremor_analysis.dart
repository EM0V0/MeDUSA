import 'package:flutter/foundation.dart'; // Import for debugPrint

/// Tremor analysis data model
/// Represents processed tremor data from AWS Lambda and DynamoDB
class TremorAnalysis {
  final String deviceId;
  final String? patientId;
  final String? patientName;
  final DateTime analysisTimestamp;
  final DateTime windowStart;
  final DateTime windowEnd;
  final int sampleCount;
  final int samplingRate;

  // Tremor metrics
  final double rms;
  final double dominantFreq;
  final double tremorPower;
  final double tremorIndex;
  final bool isParkinsonian;

  final DateTime processedAt;

  TremorAnalysis({
    required this.deviceId,
    this.patientId,
    this.patientName,
    required this.analysisTimestamp,
    required this.windowStart,
    required this.windowEnd,
    required this.sampleCount,
    required this.samplingRate,
    required this.rms,
    required this.dominantFreq,
    required this.tremorPower,
    required this.tremorIndex,
    required this.isParkinsonian,
    required this.processedAt,
  });

  factory TremorAnalysis.fromJson(Map<String, dynamic> json) {
    // API returns: patient_id, timestamp, device_id, tremor_score, tremor_frequency,
    // tremor_amplitude, features.rms, is_parkinsonian, signal_quality
    final timestamp = _parseTimestamp(json['timestamp']);
    
    // Extract RMS from features object if it exists, or directly from json
    final features = json['features'] as Map<String, dynamic>?;
    final rmsValue = features != null 
        ? _parseDouble(features['rms']) 
        : _parseDouble(json['rms_value'] ?? json['rms']);
    
    // Handle tremor_index (0-1)
    // We expect the API to return tremor_index in 0-1 range.
    // If it returns > 1 (legacy data), we normalize it.
    double tremorIndexVal = 0.0;
    
    if (json['tremor_index'] != null) {
      tremorIndexVal = _parseDouble(json['tremor_index']);
      // Ensure it's in 0-1 range
      if (tremorIndexVal > 1.0) {
        tremorIndexVal = tremorIndexVal / 100.0;
      }
    } else if (json['tremor_score'] != null) {
      // Fallback for legacy API responses that might only have score
      tremorIndexVal = _parseDouble(json['tremor_score']) / 100.0;
    }

    // DEBUG LOGGING
    if (json['tremor_index'] != null || json['tremor_score'] != null) {
      final score = (tremorIndexVal * 100).clamp(0.0, 100.0);
      debugPrint('TremorAnalysis Debug: ID=${json['patient_id']}, RawIndex=${json['tremor_index']}, RawScore=${json['tremor_score']}, ParsedIndex=$tremorIndexVal, CalcScore=$score');
    }
    
    return TremorAnalysis(
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      patientId: json['patient_id'] ?? json['patientId'],
      patientName: json['patient_name'] ?? json['patientName'],
      analysisTimestamp: timestamp,
      windowStart: timestamp, // Use timestamp as window boundaries
      windowEnd: timestamp,
      sampleCount: json['sample_count'] ?? json['sampleCount'] ?? 0,
      samplingRate: json['sampling_rate'] ?? json['samplingRate'] ?? 100,
      rms: rmsValue,
      dominantFreq: _parseDouble(json['tremor_frequency'] ?? json['dominant_frequency'] ?? json['dominantFreq']),
      tremorPower: _parseDouble(json['tremor_amplitude'] ?? json['tremor_power'] ?? json['tremorPower']),
      tremorIndex: tremorIndexVal,  // Store as 0-1
      isParkinsonian: json['is_parkinsonian'] ?? json['isParkinsonian'] ?? false,
      processedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'patientId': patientId,
      'patientName': patientName,
      'analysisTimestamp': analysisTimestamp.toIso8601String(),
      'windowStart': windowStart.toIso8601String(),
      'windowEnd': windowEnd.toIso8601String(),
      'sampleCount': sampleCount,
      'samplingRate': samplingRate,
      'rms': rms,
      'dominantFreq': dominantFreq,
      'tremorPower': tremorPower,
      'tremorIndex': tremorIndex,
      'isParkinsonian': isParkinsonian,
      'processedAt': processedAt.toIso8601String(),
    };
  }

  /// Helper to parse timestamp from various formats
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  /// Helper to parse double from various formats (handles DynamoDB Decimal)
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Get tremor severity level based on tremor index
  String get severityLevel {
    if (tremorIndex < 0.2) return 'Minimal';
    if (tremorIndex < 0.4) return 'Mild';
    if (tremorIndex < 0.6) return 'Moderate';
    if (tremorIndex < 0.8) return 'Severe';
    return 'Very Severe';
  }

  /// Get tremor score (0-100 scale)
  double get tremorScore {
    // Convert tremor index (0-1) to score (0-100)
    return (tremorIndex * 100).clamp(0.0, 100.0);
  }
}

/// Data point for tremor chart display
class TremorDataPoint {
  final DateTime timestamp;
  final double tremorScore;
  final bool isParkinsonian;

  TremorDataPoint({
    required this.timestamp,
    required this.tremorScore,
    this.isParkinsonian = false,
  });

  factory TremorDataPoint.fromAnalysis(TremorAnalysis analysis) {
    return TremorDataPoint(
      timestamp: analysis.analysisTimestamp,
      tremorScore: analysis.tremorScore,
      isParkinsonian: analysis.isParkinsonian,
    );
  }
}
