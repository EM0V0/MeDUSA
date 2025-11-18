import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/tremor_api_service.dart';
import '../../data/models/tremor_analysis.dart';
import '../widgets/tremor_chart.dart';

class PatientDetailPage extends StatefulWidget {
  final String patientId;
  final String? patientName;

  const PatientDetailPage({
    super.key,
    required this.patientId,
    this.patientName,
  });

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> with SingleTickerProviderStateMixin {
  final TremorApiService _tremorApi = TremorApiService();
  
  List<TremorAnalysis> _tremorData = [];
  bool _isLoading = true;
  String? _error;
  TabController? _tabController;
  
  // Time range filters
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _endTime = DateTime.now();
  String _selectedTimeRange = '24h';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTremorData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadTremorData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Calculate time range based on selected tab
      final now = DateTime.now();
      DateTime startTime;
      
      switch (_selectedTimeRange) {
        case '1h':
          startTime = now.subtract(const Duration(hours: 1));
          break;
        case '6h':
          startTime = now.subtract(const Duration(hours: 6));
          break;
        case '24h':
          startTime = now.subtract(const Duration(hours: 24));
          break;
        case '7d':
          startTime = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          startTime = now.subtract(const Duration(days: 30));
          break;
        default:
          startTime = now.subtract(const Duration(hours: 24));
      }

      // Call real API with time range
      final data = await _tremorApi.getPatientTremorData(
        patientId: widget.patientId,
        startTime: startTime,
        endTime: now,
        limit: 500,
      );

      if (mounted) {
        setState(() {
          _tremorData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If API fails, fall back to mock data for development
      debugPrint('Failed to load real data, using mock: $e');
      
      try {
        final mockData = await _tremorApi.getMockTremorData(
          patientId: widget.patientId,
          count: 30,
        );
        
        if (mounted) {
          setState(() {
            _tremorData = mockData;
            _error = 'Using mock data (API unavailable)';
            _isLoading = false;
          });
        }
      } catch (mockError) {
        if (mounted) {
          setState(() {
            _error = 'Failed to load tremor data: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  void _changeTimeRange(String range) {
    setState(() {
      _selectedTimeRange = range;
      final now = DateTime.now();
      
      switch (range) {
        case '1h':
          _startTime = now.subtract(const Duration(hours: 1));
          break;
        case '6h':
          _startTime = now.subtract(const Duration(hours: 6));
          break;
        case '24h':
          _startTime = now.subtract(const Duration(hours: 24));
          break;
        case '7d':
          _startTime = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          _startTime = now.subtract(const Duration(days: 30));
          break;
      }
      _endTime = now;
    });
    
    _loadTremorData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.patientName ?? 'Patient Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTremorData,
            tooltip: 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Chart', icon: Icon(Icons.show_chart)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildChartTab(),
                    _buildStatisticsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final latestReading = _tremorData.isNotEmpty ? _tremorData.last : null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.defaultPadding.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientInfoCard(),
          SizedBox(height: 16.h),
          _buildLatestReadingCard(latestReading),
          SizedBox(height: 16.h),
          _buildQuickStatsCards(),
        ],
      ),
    );
  }

  Widget _buildChartTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.defaultPadding.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeSelector(),
          SizedBox(height: 16.h),
          TremorChart(
            dataPoints: _tremorData
                .map((analysis) => TremorDataPoint.fromAnalysis(analysis))
                .toList(),
            showParkinsonianMarkers: true,
            onRefresh: _loadTremorData,
            title: 'Tremor Score Trend',
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_tremorData.isEmpty) {
      return Center(
        child: Text(
          'No data available for statistics',
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final scores = _tremorData.map((a) => a.tremorScore).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final parkinsonianCount = _tremorData.where((a) => a.isParkinsonian).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.defaultPadding.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistical Analysis',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          _buildStatCard('Average Tremor Score', avgScore.toStringAsFixed(1), Icons.show_chart),
          SizedBox(height: 12.h),
          _buildStatCard('Maximum Score', maxScore.toStringAsFixed(1), Icons.trending_up),
          SizedBox(height: 12.h),
          _buildStatCard('Minimum Score', minScore.toStringAsFixed(1), Icons.trending_down),
          SizedBox(height: 12.h),
          _buildStatCard('Parkinsonian Episodes', parkinsonianCount.toString(), Icons.warning),
          SizedBox(height: 12.h),
          _buildStatCard('Total Readings', _tremorData.length.toString(), Icons.data_usage),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
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
              children: [
                CircleAvatar(
                  radius: 30.r,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (widget.patientName ?? 'P')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patientName ?? 'Unknown Patient',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'ID: ${widget.patientId}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestReadingCard(TremorAnalysis? reading) {
    if (reading == null) {
      return const SizedBox.shrink();
    }

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
                Text(
                  'Latest Reading',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, HH:mm').format(reading.analysisTimestamp),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Score',
                    reading.tremorScore.toStringAsFixed(1),
                    reading.severityLevel,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Frequency',
                    '${reading.dominantFreq.toStringAsFixed(1)} Hz',
                    reading.isParkinsonian ? 'Parkinsonian' : 'Normal',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String sublabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCards() {
    if (_tremorData.isEmpty) {
      return const SizedBox.shrink();
    }

    final scores = _tremorData.map((a) => a.tremorScore).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final parkinsonianCount = _tremorData.where((a) => a.isParkinsonian).length;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Avg Score',
            avgScore.toStringAsFixed(1),
            Icons.analytics,
            AppColors.success,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildQuickStatCard(
            'Episodes',
            parkinsonianCount.toString(),
            Icons.warning,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Icon(icon, size: 32.sp, color: color),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final ranges = ['1h', '6h', '24h', '7d', '30d'];
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ranges.map((range) {
            final isSelected = _selectedTimeRange == range;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: ElevatedButton(
                  onPressed: () => _changeTimeRange(range),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.primary : Colors.white,
                    foregroundColor: isSelected ? Colors.white : AppColors.textPrimary,
                    elevation: isSelected ? 2 : 0,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(icon, size: 32.sp, color: AppColors.primary),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: AppColors.error,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _loadTremorData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
