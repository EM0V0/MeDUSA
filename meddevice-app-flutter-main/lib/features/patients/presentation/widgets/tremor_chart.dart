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

  const TremorChart({
    super.key,
    required this.dataPoints,
    this.showParkinsonianMarkers = true,
    this.enableZoom = true,
    this.refreshInterval,
    this.onRefresh,
    this.title = 'Tremor Score Over Time',
  });

  @override
  State<TremorChart> createState() => _TremorChartState();
}

class _TremorChartState extends State<TremorChart> {
  double _minX = 0;
  double _maxX = 20;
  double _minY = 0;
  double _maxY = 100;

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
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

  Widget _buildChart() {
    return SizedBox(
      height: 180.h,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 20,
            verticalInterval: 1,
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
                interval: 1,
                getTitlesWidget: _buildBottomTitle,
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
          minX: _minX,
          maxX: _maxX,
          minY: _minY,
          maxY: _maxY,
          lineBarsData: [
            _buildTremorScoreLine(),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppColors.darkPrimary,
              getTooltipItems: _buildTooltipItems,
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildTremorScoreLine() {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < widget.dataPoints.length; i++) {
      final point = widget.dataPoints[i];
      spots.add(FlSpot(i.toDouble(), point.tremorScore));
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
          final point = widget.dataPoints[index];
          final color = point.isParkinsonian && widget.showParkinsonianMarkers
              ? AppColors.error
              : AppColors.primary;

          return FlDotCirclePainter(
            radius: point.isParkinsonian ? 6 : 4,
            color: color,
            strokeWidth: 2,
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

  Widget _buildBottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= widget.dataPoints.length) {
      return const SizedBox.shrink();
    }

    final point = widget.dataPoints[index];
    final timeFormat = DateFormat('HH:mm');

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        timeFormat.format(point.timestamp),
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

  List<LineTooltipItem> _buildTooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.map((spot) {
      final index = spot.x.toInt();
      if (index < 0 || index >= widget.dataPoints.length) {
        return LineTooltipItem('', const TextStyle());
      }

      final point = widget.dataPoints[index];
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
