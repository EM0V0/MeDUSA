import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../patients/data/datasources/tremor_api_service.dart';
import '../../../patients/data/models/tremor_analysis.dart';
import '../../../patients/presentation/widgets/tremor_chart.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TremorApiService _tremorApi = TremorApiService();
  
  String? _patientId;  // Will be set from authenticated user
  String _patientName = 'Patient';  // Will be updated from authenticated user
  String _selectedTimeRange = '1h';
  
  bool _isLoading = false;
  String? _error;
  List<TremorAnalysis> _tremorData = [];
  Map<String, dynamic>? _statistics;

  final List<String> _timeRanges = ['1h', '24h', '7d'];

  @override
  void initState() {
    super.initState();
    // Patient ID will be loaded from AuthBloc in build method
    // We'll call _loadData() after getting patient ID
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load patient data when patient_id is available
    if (_patientId != null && _tremorData.isEmpty && !_isLoading) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_patientId == null) {
      setState(() {
        _error = 'Patient ID not found. Please ensure you are logged in as a patient.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Loading data for patient_id: $_patientId');
      final now = DateTime.now();
      DateTime startTime;
      switch (_selectedTimeRange) {
        case '1h':
          startTime = now.subtract(const Duration(hours: 1));
          break;
        case '24h':
          startTime = now.subtract(const Duration(hours: 24));
          break;
        case '7d':
          startTime = now.subtract(const Duration(days: 7));
          break;
        default:
          startTime = now.subtract(const Duration(hours: 24));
      }

      final data = await _tremorApi.getPatientTremorData(
        patientId: _patientId!,  // Safe because we checked in the beginning
        startTime: startTime,
        endTime: now,
        limit: 100,
      );

      final stats = await _tremorApi.getTremorStatistics(
        patientId: _patientId!,  // Safe because we checked in the beginning
        startTime: startTime,
        endTime: now,
      );

      setState(() {
        _tremorData = data;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data for patient $_patientId: $e');
      setState(() {
        if (e.toString().contains('400')) {
          _error = 'No tremor data found for this patient.\n\nThis could mean:\n• No device is paired with your account\n• The device hasn\'t collected data yet\n• Data collection is not active\n\nPlease pair a device and ensure it\'s collecting data.';
        } else {
          _error = 'Failed to load data: ${e.toString()}';
        }
        _isLoading = false;
      });
    }
  }

  void _onTimeRangeChanged(String range) {
    setState(() {
      _selectedTimeRange = range;
    });
    _loadData();
  }

  String _getActualTimeRangeTitle() {
    if (_tremorData.isEmpty) return 'Tremor Activity';
    
    final timestamps = _tremorData.map((d) => d.analysisTimestamp).toList();
    timestamps.sort();
    final oldest = timestamps.first;
    final newest = timestamps.last;
    final duration = newest.difference(oldest);
    
    String timeRange;
    if (duration.inMinutes < 60) {
      timeRange = '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      timeRange = minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else {
      timeRange = '${duration.inDays}d';
    }
    
    return 'Tremor Activity - $timeRange (${_tremorData.length} points)';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Get patient_id from authenticated user
        if (authState is AuthAuthenticated) {
          if (_patientId == null) {
            // First time getting user data
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _patientId = authState.user.patientId ?? authState.user.id;
                _patientName = authState.user.name;
              });
              print('Patient Dashboard - User: ${authState.user.email}, Patient ID: $_patientId, Has patientId field: ${authState.user.patientId != null}');
              _loadData();
            });
          }
        }

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppConstants.defaultPadding.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                SizedBox(height: 28.h),

                // Stats Grid
                _buildStatsGrid(),
                SizedBox(height: 28.h),

                // Chart Section
                _buildChartSection(),
                SizedBox(height: 28.h),

                // Recent Activity
                _buildRecentActivity(),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Health Dashboard',
                  style: FontUtils.title(
                    context: context,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Welcome back, $_patientName',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.lightOnSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (ResponsiveBreakpoints.of(context).largerThan(MOBILE))
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh data',
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(40.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
            SizedBox(height: 16.h),
            Text(
              'Error loading data',
              style: FontUtils.body(context: context, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: FontUtils.caption(context: context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_statistics == null || _statistics!['statistics'] == null) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: Text(
            'No statistics available',
            style: FontUtils.body(context: context),
          ),
        ),
      );
    }

    final stats = _statistics!['statistics'];
    final tremorScores = stats['tremor_scores'] ?? {};
    final avgScore = tremorScores['average']?.toDouble() ?? 0.0;
    final totalReadings = stats['total_readings'] ?? 0;
    final parkinsonianEpisodes = stats['parkinsonian_episodes'] ?? 0;
    final freqAnalysis = stats['frequency_analysis'] ?? {};
    final avgFreq = freqAnalysis['avg_dominant_freq']?.toDouble() ?? 0.0;

    return ResponsiveBreakpoints.of(context).smallerThan(TABLET)
        ? Column(
            children: [
              _buildStatCard(
                'Average Score', 
                avgScore.toStringAsFixed(1), 
                Icons.show_chart, 
                AppColors.primary,
                subtitle: 'Tremor Index',
              ),
              SizedBox(height: 16.h),
              _buildStatCard(
                'Parkinsonian Episodes', 
                parkinsonianEpisodes.toString(), 
                Icons.warning_amber, 
                AppColors.error,
                subtitle: 'Total occurrences',
              ),
              SizedBox(height: 16.h),
              _buildStatCard(
                'Total Readings', 
                totalReadings.toString(), 
                Icons.analytics, 
                AppColors.info,
                subtitle: 'Data points',
              ),
              SizedBox(height: 16.h),
              _buildStatCard(
                'Avg Frequency', 
                '${avgFreq.toStringAsFixed(1)} Hz', 
                Icons.graphic_eq, 
                AppColors.success,
                subtitle: 'Dominant frequency',
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: _buildStatCard(
                'Average Score', 
                avgScore.toStringAsFixed(1), 
                Icons.show_chart, 
                AppColors.primary,
                subtitle: 'Tremor Index',
              )),
              SizedBox(width: 16.w),
              Expanded(child: _buildStatCard(
                'Parkinsonian Episodes', 
                parkinsonianEpisodes.toString(), 
                Icons.warning_amber, 
                AppColors.error,
                subtitle: 'Total occurrences',
              )),
              SizedBox(width: 16.w),
              Expanded(child: _buildStatCard(
                'Total Readings', 
                totalReadings.toString(), 
                Icons.analytics, 
                AppColors.info,
                subtitle: 'Data points',
              )),
              SizedBox(width: 16.w),
              Expanded(child: _buildStatCard(
                'Avg Frequency', 
                '${avgFreq.toStringAsFixed(1)} Hz', 
                Icons.graphic_eq, 
                AppColors.success,
                subtitle: 'Dominant frequency',
              )),
            ],
          );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.lightOnSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              value,
              style: FontUtils.headline(
                context: context,
                fontWeight: FontWeight.w700,
                color: AppColors.lightOnSurface,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tremor Activity - $_selectedTimeRange',
                    style: FontUtils.title(
                      context: context,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _timeRanges.map((range) {
                    final isSelected = _selectedTimeRange == range;
                    return Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: ChoiceChip(
                        label: Text(range.toUpperCase()),
                        selected: isSelected,
                        onSelected: (_) => _onTimeRangeChanged(range),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            if (_isLoading)
              SizedBox(
                height: 250.h,
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 250.h,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                      SizedBox(height: 16.h),
                      Text('Error loading chart data', style: FontUtils.body(context: context)),
                    ],
                  ),
                ),
              )
            else if (_tremorData.isEmpty)
              SizedBox(
                height: 250.h,
                child: Center(
                  child: Text(
                    'No data available for selected time range',
                    style: FontUtils.body(context: context, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SizedBox(
                height: 290.h,
                child: TremorChart(
                  dataPoints: _tremorData.map((t) => TremorDataPoint(
                    timestamp: t.analysisTimestamp,
                    tremorScore: t.tremorIndex,
                    isParkinsonian: t.isParkinsonian,
                  )).toList(),
                  title: _getActualTimeRangeTitle(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Tremor Readings',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 16.h),
            if (_tremorData.isNotEmpty) ...[
              ...(_tremorData.take(5).map((data) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: data.isParkinsonian 
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        data.isParkinsonian ? Icons.warning_amber : Icons.check_circle,
                        color: data.isParkinsonian ? AppColors.warning : AppColors.success,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tremor Index: ${data.tremorIndex.toStringAsFixed(2)}',
                            style: FontUtils.body(
                              context: context,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            data.analysisTimestamp.toString().substring(0, 19),
                            style: FontUtils.caption(
                              context: context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))),
            ] else ...[
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20.h),
                  child: Text(
                    'No recent activity',
                    style: FontUtils.body(
                      context: context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
