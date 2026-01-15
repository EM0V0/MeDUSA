import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/tremor_api_service.dart';
import '../../data/models/tremor_analysis.dart';
import 'tremor_chart.dart';

enum TimeRange {
  oneMinute,
  oneHour,
  twentyFourHours,
  sevenDays,
}

class RealtimeTremorChart extends StatefulWidget {
  final String patientId;
  final String? deviceId;

  const RealtimeTremorChart({
    super.key,
    required this.patientId,
    this.deviceId,
  });

  @override
  State<RealtimeTremorChart> createState() => _RealtimeTremorChartState();
}

class _RealtimeTremorChartState extends State<RealtimeTremorChart> {
  final TremorApiService _apiService = TremorApiService();
  List<TremorDataPoint> _dataPoints = [];
  Timer? _timer;
  bool _isPaused = false;
  TimeRange _selectedRange = TimeRange.oneMinute;
  static const int _maxDataPoints = 80;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    // Poll every 1 second for 1-minute view
    if (_selectedRange == TimeRange.oneMinute) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          _fetchLatestData();
        }
      });
    } else {
      // For other ranges, fetch once (or poll less frequently, e.g. every minute)
      _fetchHistoricalData();
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (!_isPaused) {
          _fetchHistoricalData();
        }
      });
    }
  }

  Future<void> _fetchLatestData() async {
    try {
      final data = await _apiService.getPatientTremorData(
        patientId: widget.patientId,
        deviceId: widget.deviceId,
        limit: 1, // Get only the latest point
      );

      if (data.isNotEmpty && mounted) {
        final latest = data.first;
        final point = TremorDataPoint.fromAnalysis(latest);

        setState(() {
          // Avoid duplicates if timestamp matches last point
          if (_dataPoints.isEmpty || 
              point.timestamp.isAfter(_dataPoints.last.timestamp)) {
            _dataPoints.add(point);
            
            // Keep only last N points
            if (_dataPoints.length > _maxDataPoints) {
              _dataPoints.removeAt(0);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching realtime data: $e');
    }
  }

  Future<void> _fetchHistoricalData() async {
    try {
      DateTime startTime;
      final now = DateTime.now();
      
      switch (_selectedRange) {
        case TimeRange.oneHour:
          startTime = now.subtract(const Duration(hours: 1));
          break;
        case TimeRange.twentyFourHours:
          startTime = now.subtract(const Duration(hours: 24));
          break;
        case TimeRange.sevenDays:
          startTime = now.subtract(const Duration(days: 7));
          break;
        default:
          startTime = now.subtract(const Duration(minutes: 1));
      }

      final data = await _apiService.getPatientTremorData(
        patientId: widget.patientId,
        deviceId: widget.deviceId,
        startTime: startTime,
        endTime: now,
        limit: 2000, // Fetch more data to cover the time range
      );

      if (mounted) {
        setState(() {
          _dataPoints = data
              .map((a) => TremorDataPoint.fromAnalysis(a))
              .toList()
              .reversed // API returns newest first, we want oldest first for chart
              .toList();
          
          // No need to downsample here, TremorChart handles it
        });
      }
    } catch (e) {
      debugPrint('Error fetching historical data: $e');
    }
  }

  void _onRangeSelected(TimeRange range) {
    setState(() {
      _selectedRange = range;
      _dataPoints.clear();
    });
    _startPolling();
  }

  int? _getFixedRangeMs() {
    switch (_selectedRange) {
      case TimeRange.oneMinute:
        return 60 * 1000;
      case TimeRange.oneHour:
        return 60 * 60 * 1000;
      case TimeRange.twentyFourHours:
        return 24 * 60 * 60 * 1000;
      case TimeRange.sevenDays:
        return 7 * 24 * 60 * 60 * 1000;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tremor Monitor',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _selectedRange == TimeRange.oneMinute 
                          ? 'Real-time updates' 
                          : 'Historical data',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Time Range Selector
                DropdownButton<TimeRange>(
                  value: _selectedRange,
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(
                      value: TimeRange.oneMinute,
                      child: Text('1 Min'),
                    ),
                    DropdownMenuItem(
                      value: TimeRange.oneHour,
                      child: Text('1 Hour'),
                    ),
                    DropdownMenuItem(
                      value: TimeRange.twentyFourHours,
                      child: Text('24 Hours'),
                    ),
                    DropdownMenuItem(
                      value: TimeRange.sevenDays,
                      child: Text('7 Days'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _onRangeSelected(value);
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
            
            // Use TremorChart widget instead of custom LineChart
            TremorChart(
              dataPoints: _dataPoints,
              title: '', // Title is handled outside
              fixedXRangeMs: _getFixedRangeMs(),
              showParkinsonianMarkers: true,
              enableZoom: false, // Disable zoom inside this card
            ),
            
            SizedBox(height: 16.h),
            if (_dataPoints.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('Current', _dataPoints.last.tremorScore.toStringAsFixed(1)),
                  _buildMetric('Peak', 
                    _dataPoints.map((e) => e.tremorScore).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                  ),
                  _buildMetric('Avg', 
                    (_dataPoints.map((e) => e.tremorScore).reduce((a, b) => a + b) / _dataPoints.length).toStringAsFixed(1)
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
