import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/tremor_analysis.dart';

/// Real-time tremor chart widget with live updates
class TremorChart extends StatefulWidget {
  final List<TremorDataPoint> dataPoints;
  final bool showParkinsonianMarkers;
  final bool enableZoom;
  final Duration? refreshInterval;
  final VoidCallback? onRefresh;
  final String title;
  final int? fixedXRangeMs; // Optional fixed range in milliseconds

  const TremorChart({
    super.key,
    required this.dataPoints,
    this.showParkinsonianMarkers = true,
    this.enableZoom = true,
    this.refreshInterval,
    this.onRefresh,
    this.title = 'Tremor Score Over Time',
    this.fixedXRangeMs,
  });

  @override
  State<TremorChart> createState() => _TremorChartState();
}

class _TremorChartState extends State<TremorChart> {
  double _minY = 0;
  double _maxY = 100;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
    
    // Start a ticker to update the chart window every 100ms for smooth sliding
    // This ensures the chart slides left even if no new data arrives
    if (widget.fixedXRangeMs != null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _setupAutoRefresh() {
    if (widget.refreshInterval != null && widget.onRefresh != null) {
      Future.delayed(widget.refreshInterval!, () {
        if (mounted) {
          widget.onRefresh!();
          _setupAutoRefresh();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dataPoints.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 8.h),
            _buildChart(),
            SizedBox(height: 6.h),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (widget.onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh),
            iconSize: 20.sp,
            onPressed: widget.onRefresh,
            tooltip: 'Refresh data',
          ),
      ],
    );
  }

  /// Downsample data to target count using Max Pooling to preserve peaks
  List<TremorDataPoint> _processDataPoints() {
    if (widget.dataPoints.isEmpty) return [];

    // 1. Sort by timestamp
    final sorted = List<TremorDataPoint>.from(widget.dataPoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 2. If count is small enough, return as is
    if (sorted.length <= 80) return sorted;

    // 3. Downsample to ~80 points
    final result = <TremorDataPoint>[];
    final bucketSize = sorted.length / 80;

    for (int i = 0; i < 80; i++) {
      final start = (i * bucketSize).floor();
      final end = ((i + 1) * bucketSize).floor();
      
      if (start >= sorted.length) break;
      
      final sliceEnd = end < sorted.length ? end : sorted.length;
      if (start >= sliceEnd) continue;
      
      final slice = sorted.sublist(start, sliceEnd);
      
      // Find the point with the highest tremor score in this bucket
      // This ensures we don't miss any high tremor episodes (Max Pooling)
      final maxPoint = slice.reduce((curr, next) => 
        curr.tremorScore > next.tremorScore ? curr : next
      );
      
      result.add(maxPoint);
    }

    return result;
  }

  Widget _buildChart() {
    final processedPoints = _processDataPoints();
    
    // Calculate min and max X based on timestamps
    double minX = 0;
    double maxX = 0;
    
    if (widget.fixedXRangeMs != null) {
      // Fixed range mode (e.g. for 1M view)
      // Always anchor to NOW to create a continuous sliding window effect
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      
      maxX = now;
      minX = maxX - widget.fixedXRangeMs!;
      
      // Filter points to strictly within [minX, maxX]
      final visiblePoints = processedPoints.where((p) {
        final t = p.timestamp.millisecondsSinceEpoch.toDouble();
        return t >= minX && t <= maxX;
      }).toList();
      
      // Ensure points are sorted by timestamp to prevent zigzag lines
      visiblePoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return SizedBox(
        height: 180.h,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 20,
              verticalInterval: (maxX - minX) > 0 ? (maxX - minX) / 5 : 1.0,
              getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1),
              getDrawingVerticalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (maxX - minX) > 0 ? (maxX - minX) / 5 : 1.0,
                  getTitlesWidget: (value, meta) => _buildBottomTitle(value, meta, visiblePoints),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 42,
                  getTitlesWidget: _buildLeftTitle,
                ),
              ),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: AppColors.divider)),
            minX: minX,
            maxX: maxX,
            minY: _minY,
            maxY: _maxY,
            lineBarsData: [
              _buildTremorScoreLine(visiblePoints),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => AppColors.darkPrimary,
                getTooltipItems: (spots) => _buildTooltipItems(spots, visiblePoints),
              ),
            ),
          ),
        ),
      );
    } else if (processedPoints.isNotEmpty) {
      minX = processedPoints.first.timestamp.millisecondsSinceEpoch.toDouble();
      maxX = processedPoints.last.timestamp.millisecondsSinceEpoch.toDouble();
      
      // Add padding if single point or very small range
      if (maxX - minX < 1000) {
        minX -= 300000; // 5 mins
        maxX += 300000;
      }

      // Filter points to be within the visible range to prevent overflow drawing
      final visiblePoints = processedPoints.where((p) {
        final t = p.timestamp.millisecondsSinceEpoch.toDouble();
        return t >= minX && t <= maxX;
      }).toList();
      
      // Ensure sorted
      visiblePoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return SizedBox(
      height: 180.h,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 20,
            verticalInterval: (maxX - minX) > 0 ? (maxX - minX) / 5 : 1.0, // Dynamic vertical grid
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.divider,
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
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
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxX - minX) > 0 ? (maxX - minX) / 5 : 1.0, // Dynamic interval, prevent div by zero
                getTitlesWidget: (value, meta) => _buildBottomTitle(value, meta, visiblePoints),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 42,
                getTitlesWidget: _buildLeftTitle,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppColors.divider,
            ),
          ),
          minX: minX,
          maxX: maxX > minX ? maxX : minX + 1.0, // Ensure maxX > minX
          minY: _minY,
          maxY: _maxY,
          lineBarsData: [
            _buildTremorScoreLine(visiblePoints),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppColors.darkPrimary,
              getTooltipItems: (spots) => _buildTooltipItems(spots, visiblePoints),
            ),
          ),
        ),
      ),
    );
    }
    
    // Return empty chart if no data points
    return SizedBox(
      height: 180.h,
      child: Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildTremorScoreLine(List<TremorDataPoint> points) {
    final spots = <FlSpot>[];
    
    for (final point in points) {
      spots.add(FlSpot(
        point.timestamp.millisecondsSinceEpoch.toDouble(), 
        point.tremorScore
      ));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: AppColors.primary,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          // Find point by timestamp (x value)
          final timestamp = spot.x.toInt();
          final point = points.firstWhere(
            (p) => p.timestamp.millisecondsSinceEpoch == timestamp,
            orElse: () => points[index],
          );
          
          final score = point.tremorScore;
          Color color;
          if (score > 50) {
            color = Colors.red;
          } else if (score < 30) {
            color = Colors.blue;
          } else {
            color = Colors.yellow;
          }

          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 1,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: AppColors.primary.withOpacity(0.1),
      ),
    );
  }

  Widget _buildBottomTitle(double value, TitleMeta meta, List<TremorDataPoint> points) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final timeFormat = DateFormat('HH:mm');
    
    // If range > 24h, show date too
    final range = meta.max - meta.min;
    final isLongRange = range > 86400000; // 24h in ms

    return SideTitleWidget(
      axisSide: meta.axisSide,
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      child: Text(
        isLongRange ? DateFormat('MM/dd').format(date) : timeFormat.format(date),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10.sp,
        ),
      ),
    );
  }

  Widget _buildLeftTitle(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.sp,
      ),
    );
  }

  List<LineTooltipItem> _buildTooltipItems(List<LineBarSpot> touchedSpots, List<TremorDataPoint> points) {
    return touchedSpots.map((spot) {
      final timestamp = spot.x.toInt();
      // Find closest point
      final point = points.firstWhere(
        (p) => p.timestamp.millisecondsSinceEpoch == timestamp,
        orElse: () => points.first,
      );

      final timeFormat = DateFormat('MMM dd, HH:mm');

      return LineTooltipItem(
        '${timeFormat.format(point.timestamp)}\n'
        'Score: ${point.tremorScore.toStringAsFixed(1)}\n'
        '${point.isParkinsonian ? "⚠ Parkinsonian" : "✓ Normal"}',
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          color: AppColors.primary,
          label: 'Tremor Score',
        ),
        SizedBox(width: 16.w),
        if (widget.showParkinsonianMarkers)
          _buildLegendItem(
            color: AppColors.error,
            label: 'Parkinsonian Episode',
          ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Container(
        height: 250.h,
        padding: EdgeInsets.all(24.w),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 64.sp,
                color: AppColors.textDisabled,
              ),
              SizedBox(height: 16.h),
              Text(
                'No tremor data available',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Data will appear here once the device starts collecting readings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
