import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/tremor_api_service.dart';
import '../../data/models/tremor_analysis.dart';

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
  final List<TremorDataPoint> _dataPoints = [];
  Timer? _timer;
  bool _isPaused = false;
  static const int _maxDataPoints = 60; // Show last 60 seconds

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
    // Poll every 1 second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _fetchLatestData();
      }
    });
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
                      'Real-time Tremor Monitor',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Updates every second',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  onPressed: () {
                    setState(() {
                      _isPaused = !_isPaused;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
            SizedBox(
              height: 200.h,
              child: _dataPoints.isEmpty
                  ? const Center(child: Text('Waiting for data...'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppColors.divider,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 20,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10.sp,
                                  ),
                                );
                              },
                              reservedSize: 30,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: _maxDataPoints.toDouble(),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _dataPoints
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.tremorScore))
                                .toList(),
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            SizedBox(height: 16.h),
            if (_dataPoints.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('Current', _dataPoints.last.tremorScore.toStringAsFixed(1)),
                  _buildMetric('Peak (1m)', 
                    _dataPoints.map((e) => e.tremorScore).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                  ),
                  _buildMetric('Avg (1m)', 
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
