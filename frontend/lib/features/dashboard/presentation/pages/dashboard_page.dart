import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
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
  String _selectedTimeRange = '1m';
  
  bool _isLoading = false;
  String? _error;
  List<TremorAnalysis> _tremorData = [];
  Map<String, dynamic>? _statistics;
  Timer? _pollingTimer;

  final List<String> _timeRanges = ['1m', '1h', '24h', '7d'];

  @override
  void initState() {
    super.initState();
    // Patient ID will be loaded from AuthBloc in build method
    // We'll call _loadData() after getting patient ID
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load patient data when patient_id is available
    if (_patientId != null && _tremorData.isEmpty && !_isLoading) {
      _initDataLoad();
    }
  }

  void _initDataLoad() {
    if (_selectedTimeRange == '1m') {
      _startPolling();
    } else {
      _loadData();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _loadRealtimeData(); // Initial fetch
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _loadRealtimeData());
  }

  Future<void> _loadRealtimeData() async {
    if (_patientId == null) return;

    try {
      // Fetch more points initially to fill the 1-minute chart (60s)
      // If we already have data, just fetch recent ones to catch up.
      // Use a small overlap (2s) so we don't miss narrowly timed points.
      final int limit = _tremorData.isEmpty ? 80 : 20;

      DateTime now = DateTime.now();
      DateTime? startTime;
      DateTime endTime = now;

      if (_tremorData.isNotEmpty) {
        // Overlap by 2 seconds to guard against race/latency
        startTime = _tremorData.last.analysisTimestamp.subtract(const Duration(seconds: 2));
      }

      // Always request up-to-now (endTime) so we fetch the newest points
      final data = await _tremorApi.getPatientTremorData(
        patientId: _patientId!,
        limit: limit,
        startTime: startTime,
        endTime: endTime,
      );

      if (mounted) {
        setState(() {
          if (data.isNotEmpty) {
            // Merge new data with existing data by appending only strictly newer points.
            if (data.isNotEmpty) {
              DateTime? newestLocal = _tremorData.isNotEmpty ? _tremorData.last.analysisTimestamp : null;

              // Keep points that are newer than the newest local point (allow tiny overlap)
              final newPoints = data.where((t) {
                if (newestLocal == null) return true;
                return t.analysisTimestamp.isAfter(newestLocal.subtract(const Duration(milliseconds: 10)));
              }).toList();

              if (newPoints.isNotEmpty) {
                // Append and dedupe by timestamp (in case API returns overlapping sets)
                _tremorData.addAll(newPoints);
                _tremorData.sort((a, b) => a.analysisTimestamp.compareTo(b.analysisTimestamp));
                // Remove exact-duplicate timestamps
                final deduped = <TremorAnalysis>[];
                DateTime? lastTs;
                for (final t in _tremorData) {
                  if (lastTs == null || t.analysisTimestamp.isAfter(lastTs)) {
                    deduped.add(t);
                    lastTs = t.analysisTimestamp;
                  }
                }
                _tremorData = deduped;

                // Keep a reasonable history window (by count)
                if (_tremorData.length > 240) {
                  _tremorData = _tremorData.sublist(_tremorData.length - 240);
                }
              }
            }
          }
          // Always update state to refresh chart time window (sliding effect)
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error polling realtime data: $e');
    }
  }

  Future<void> _loadData() async {
    _pollingTimer?.cancel();
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
      debugPrint('Loading data for patient_id: $_patientId');
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
        limit: 1000, // Increased limit for longer time ranges
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
      debugPrint('Error loading data for patient $_patientId: $e');
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
      _tremorData = []; // Clear data to show loading/empty state or fresh start
      _isLoading = true;
    });
    
    if (range == '1m') {
      _startPolling();
    } else {
      _loadData();
    }
  }

  String _getActualTimeRangeTitle() {
    if (_tremorData.isEmpty) return 'Tremor Activity';
    
    // Just show the selected time range
    return 'Tremor Activity - $_selectedTimeRange';
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
              debugPrint('Patient Dashboard - User: ${authState.user.email}, Patient ID: $_patientId');
              _initDataLoad();
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
              onPressed: _initDataLoad,
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
              onPressed: _initDataLoad,
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
                    tremorScore: t.tremorScore,
                    isParkinsonian: t.isParkinsonian,
                  )).toList(),
                  title: _getActualTimeRangeTitle(),
                  fixedXRangeMs: _getFixedRangeMs(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int? _getFixedRangeMs() {
    switch (_selectedTimeRange) {
      case '1m': return 60 * 1000;
      case '1h': return 60 * 60 * 1000;
      case '24h': return 24 * 60 * 60 * 1000;
      case '7d': return 7 * 24 * 60 * 60 * 1000;
      default: return null;
    }
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
                            'Tremor Score: ${data.tremorScore.toStringAsFixed(1)}',
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
