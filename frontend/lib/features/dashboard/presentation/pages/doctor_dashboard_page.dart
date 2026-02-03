import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/services/network_service.dart';
import '../../../../shared/services/role_service.dart';
import '../../../../shared/services/tremor_simulation_service.dart';
import '../../../patients/data/datasources/tremor_api_service.dart';
import '../../../patients/data/models/tremor_analysis.dart';
import '../../../patients/presentation/widgets/tremor_chart.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/services/doctor_patient_service.dart';

/// Enhanced dashboard page specifically designed for doctors
/// Features patient selection and multi-patient data visualization with real data
class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final RoleService _roleService = RoleService();
  final TremorApiService _tremorApi = TremorApiService();
  final TremorSimulationService _simulationService = TremorSimulationService();
  late final DoctorPatientService _doctorPatientService;
  
  String? _doctorId;
  List<Map<String, dynamic>> _availablePatients = [];
  bool _isLoadingPatients = false;
  
  String? _selectedPatientId;
  String _selectedPatientName = 'Select a patient';
  String _selectedTimeRange = '24h';
  
  bool _isLoading = false;
  String? _error;
  List<TremorAnalysis> _tremorData = [];
  Map<String, dynamic>? _statistics;

  // Simulation mode
  bool _isSimulationMode = false;
  List<TremorDataPoint> _simulatedDataPoints = [];
  StreamSubscription<List<TremorDataPoint>>? _simulationSubscription;

  final List<String> _timeRanges = ['1h', '24h', '7d'];
  final TextEditingController _patientEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _doctorPatientService = DoctorPatientService(serviceLocator.get<NetworkService>());
  }

  @override
  void dispose() {
    _patientEmailController.dispose();
    _simulationSubscription?.cancel();
    _simulationService.stopSimulation();
    super.dispose();
  }

  Future<void> _loadPatientsList() async {
    if (_doctorId == null) return;

    setState(() {
      _isLoadingPatients = true;
    });

    try {
      final patients = await _doctorPatientService.getDoctorPatients(_doctorId!);
      setState(() {
        _availablePatients = patients;
        _isLoadingPatients = false;
        
        // Auto-select first patient if none selected
        if (_availablePatients.isNotEmpty && _selectedPatientId == null) {
          _selectedPatientId = _availablePatients.first['patient_id'];
          _selectedPatientName = _availablePatients.first['name'] ?? _availablePatients.first['email'];
          _loadData();
        }
      });
    } catch (e) {
      debugPrint('Error loading patients: $e');
      setState(() {
        _isLoadingPatients = false;
        _error = 'Failed to load patient list: $e';
      });
    }
  }

  Future<void> _loadData() async {
    if (_selectedPatientId == null) {
      setState(() {
        _error = 'Please select a patient';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Calculate time range
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

      // Load tremor data
      final data = await _tremorApi.getPatientTremorData(
        patientId: _selectedPatientId!,
        startTime: startTime,
        endTime: now,
        limit: 1000,
      );

      // Load statistics
      final stats = await _tremorApi.getTremorStatistics(
        patientId: _selectedPatientId!,
        startTime: startTime,
        endTime: now,
      );

      setState(() {
        _tremorData = data;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onPatientChanged(String? patientId) {
    if (_isSimulationMode) return; // Ignore in simulation mode
    
    if (patientId != null) {
      final patient = _availablePatients.firstWhere(
        (p) => p['patient_id'] == patientId,
        orElse: () => _availablePatients.first,
      );
      setState(() {
        _selectedPatientId = patientId;
        _selectedPatientName = patient['name'] ?? patient['email'];
      });
      _loadData();
    }
  }

  // ========== Simulation Mode Methods ==========
  
  void _toggleSimulationMode() {
    if (_isSimulationMode) {
      _stopSimulation();
    } else {
      _startSimulation();
    }
  }

  void _startSimulation() {
    setState(() {
      _isSimulationMode = true;
      _selectedPatientName = 'Demo Patient';
      _error = null;
      _isLoading = false;
    });
    
    _simulationSubscription = _simulationService.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _simulatedDataPoints = data;
          _statistics = _simulationService.getSimulatedStatistics();
        });
      }
    });
    
    _simulationService.startSimulation(intervalMs: 1000);
  }

  void _stopSimulation() {
    _simulationSubscription?.cancel();
    _simulationSubscription = null;
    _simulationService.stopSimulation();
    
    setState(() {
      _isSimulationMode = false;
      _simulatedDataPoints = [];
      if (_availablePatients.isNotEmpty) {
        _selectedPatientName = _availablePatients.first['name'] ?? _availablePatients.first['email'];
      } else {
        _selectedPatientName = 'Select a patient';
      }
    });
    
    if (_selectedPatientId != null) {
      _loadData();
    }
  }

  void _triggerParkinsonianEpisode() {
    if (_isSimulationMode) {
      _simulationService.triggerParkinsonianEpisode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🔴 Parkinsonian episode triggered!'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAddPatientDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isAdding = false;
        String? addError;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Patient'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _patientEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Patient Email',
                      hintText: 'patient@example.com',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (addError != null) ...[
                    SizedBox(height: 16.h),
                    Text(
                      addError!,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          final email = _patientEmailController.text.trim();
                          if (email.isEmpty) {
                            setState(() => addError = 'Please enter an email');
                            return;
                          }

                          setState(() {
                            isAdding = true;
                            addError = null;
                          });

                          try {
                            await _doctorPatientService.assignPatientToDoctor(
                              doctorId: _doctorId!,
                              patientEmail: email,
                            );
                            
                            // Close dialog
                            if (context.mounted) Navigator.pop(context);
                            
                            // Reload patients list
                            _patientEmailController.clear();
                            await _loadPatientsList();
                            
                            // Show success message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Patient added successfully'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              isAdding = false;
                              addError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isAdding
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Patient'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onTimeRangeChanged(String timeRange) {
    setState(() {
      _selectedTimeRange = timeRange;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Get doctor_id from authenticated user
        if (authState is AuthAuthenticated) {
          if (_doctorId == null) {
            // First time getting user data
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _doctorId = authState.user.id;
              });
              debugPrint('Doctor Dashboard - Doctor ID: $_doctorId');
              _loadPatientsList();
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
                _buildHeader(),
                SizedBox(height: 24.h),
                
                if (isMobile) ...[
                  _buildPatientSelector(),
                  SizedBox(height: 20.h),
                  _buildControlsSection(),
                  SizedBox(height: 20.h),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildPatientSelector()),
                      SizedBox(width: 20.w),
                      Expanded(flex: 3, child: _buildControlsSection()),
                    ],
                  ),
                  SizedBox(height: 24.h),
                ],
                
                _buildOverviewStats(),
                SizedBox(height: 24.h),
                _buildDataVisualizationSection(isMobile),
                SizedBox(height: 24.h),
                _buildRecentAlertsSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: _isSimulationMode
            ? Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 2)
            : Border.all(color: AppColors.lightDivider.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _isSimulationMode 
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  _isSimulationMode ? Icons.science : Icons.dashboard_rounded,
                  color: _isSimulationMode ? AppColors.warning : AppColors.primary,
                  size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Medical Dashboard',
                          style: FontUtils.headline(
                            context: context,
                            color: AppColors.lightOnSurface,
                          ),
                        ),
                        if (_isSimulationMode) ...[
                          SizedBox(width: 12.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: AppColors.warning, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.science, size: 14.sp, color: AppColors.warning),
                                SizedBox(width: 4.w),
                                Text(
                                  'SIMULATION',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _isSimulationMode 
                          ? 'Viewing simulated patient data for demonstration'
                          : 'Monitor and analyze your patients\' health data',
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Demo Mode Button
              _buildSimulationButton(),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.success,
                      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Dr. ${_roleService.currentUser?.name ?? 'Doctor'}',
                      style: FontUtils.label(
                        context: context,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Show simulation controls when in simulation mode
          if (_isSimulationMode) ...[
            SizedBox(height: 16.h),
            _buildSimulationControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulationButton() {
    return ElevatedButton.icon(
      onPressed: _toggleSimulationMode,
      icon: Icon(
        _isSimulationMode ? Icons.stop : Icons.play_arrow,
        size: 18.sp,
      ),
      label: Text(
        _isSimulationMode ? 'Stop Demo' : 'Demo Mode',
        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isSimulationMode ? AppColors.error : AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        elevation: _isSimulationMode ? 4 : 2,
      ),
    );
  }

  Widget _buildSimulationControls() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Simulated data is being displayed. This is for demonstration purposes only.',
              style: FontUtils.caption(
                context: context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton.icon(
            onPressed: _triggerParkinsonianEpisode,
            icon: Icon(Icons.flash_on, size: 16.sp),
            label: Text('Trigger Episode', style: TextStyle(fontSize: 11.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightOnSurface.withValues(alpha: 0.04),
            blurRadius: 8,
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
                Text(
                  'Select Patient',
                  style: FontUtils.title(
                    context: context,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.person_add, color: AppColors.primary),
                  onPressed: _doctorId != null ? _showAddPatientDialog : null,
                  tooltip: 'Add Patient',
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (_isLoadingPatients)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20.h),
                  child: const CircularProgressIndicator(),
                ),
              )
            else if (_availablePatients.isEmpty)
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'No patients assigned yet',
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ElevatedButton.icon(
                      onPressed: _showAddPatientDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Your First Patient'),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lightDivider),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPatientId,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: _availablePatients.map((patient) {
                      return DropdownMenuItem<String>(
                        value: patient['patient_id'],
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 20.sp,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient['name'] ?? patient['email'] ?? 'Unknown',
                                    style: FontUtils.body(
                                      context: context,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    patient['email'] ?? '',
                                    style: FontUtils.caption(
                                      context: context,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _onPatientChanged,
                  ),
                ),
              ),
            if (_tremorData.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      '${_tremorData.length} data points loaded',
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightOnSurface.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _timeRanges.map((range) {
                final isSelected = _selectedTimeRange == range;
                String label;
                switch (range) {
                  case '24h':
                    label = 'Last 24 Hours';
                    break;
                  case '7d':
                    label = 'Last 7 Days';
                    break;
                  case '30d':
                    label = 'Last 30 Days';
                    break;
                  default:
                    label = range;
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _onTimeRangeChanged(range);
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.lightBackground,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats() {
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
              style: FontUtils.title(context: context, color: AppColors.error),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: FontUtils.body(context: context),
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

    final stats = _statistics;
    if (stats == null || _tremorData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48.sp, color: AppColors.textSecondary),
              SizedBox(height: 16.h),
              Text(
                'No data available',
                style: FontUtils.title(context: context),
              ),
              SizedBox(height: 8.h),
              Text(
                'No tremor data found for $_selectedPatientName in the selected time range',
                style: FontUtils.body(context: context, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final tremorScores = stats['statistics']?['tremor_scores'] ?? {};
    final avgScore = tremorScores['average']?.toDouble() ?? 0.0;
    final maxScore = tremorScores['max']?.toDouble() ?? 0.0;
    final totalReadings = stats['statistics']?['total_readings'] ?? 0;
    final parkinsonianEpisodes = stats['statistics']?['parkinsonian_episodes'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_selectedPatientName - Overview',
            style: FontUtils.headline(
              context: context,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 16.h,
            children: [
              _buildStatCard('Avg Tremor Score', avgScore.toStringAsFixed(2), Icons.trending_up, AppColors.primary),
              _buildStatCard('Max Score', maxScore.toStringAsFixed(2), Icons.arrow_upward, AppColors.warning),
              _buildStatCard('Total Readings', totalReadings.toString(), Icons.analytics, AppColors.success),
              _buildStatCard('Parkinsonian Episodes', parkinsonianEpisodes.toString(), Icons.warning_amber, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      constraints: BoxConstraints(minWidth: 150.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 12.h),
          Text(
            value,
            style: FontUtils.headline(
              context: context,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: FontUtils.caption(
              context: context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataVisualizationSection(bool isMobile) {
    // Determine which data to display
    final bool hasData = _isSimulationMode 
        ? _simulatedDataPoints.isNotEmpty 
        : _tremorData.isNotEmpty;
    
    final List<TremorDataPoint> displayData = _isSimulationMode
        ? _simulatedDataPoints
        : _tremorData.map((t) => TremorDataPoint(
            timestamp: t.analysisTimestamp,
            tremorScore: t.tremorScore,
            isParkinsonian: t.isParkinsonian,
          )).toList();

    if (!_isSimulationMode && _isLoading) {
      return const SizedBox.shrink();
    }

    if (!hasData && !_isSimulationMode) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        padding: EdgeInsets.all(40.w),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.show_chart, size: 48.sp, color: AppColors.textSecondary),
              SizedBox(height: 16.h),
              Text(
                'No patient data available',
                style: FontUtils.body(context: context, color: AppColors.textSecondary),
              ),
              SizedBox(height: 8.h),
              Text(
                'Try Demo Mode to see how the chart works',
                style: FontUtils.caption(context: context, color: AppColors.textSecondary),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: _startSimulation,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Demo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: _isSimulationMode 
            ? Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _isSimulationMode 
                          ? 'Simulated Tremor Activity' 
                          : 'Tremor Activity - $_selectedTimeRange',
                      style: FontUtils.headline(
                        context: context,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isSimulationMode) ...[
                      SizedBox(width: 8.w),
                      _buildLiveIndicator(),
                    ],
                  ],
                ),
              ),
              if (!_isSimulationMode)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                  tooltip: 'Refresh data',
                ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 350.h,
            child: TremorChart(
              dataPoints: displayData,
              title: _isSimulationMode 
                  ? 'Demo Patient - Live Simulation' 
                  : 'Tremor Activity - $_selectedPatientName',
              fixedXRangeMs: _isSimulationMode ? 60 * 1000 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlertsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: FontUtils.headline(
              context: context,
              fontWeight: FontWeight.w600,
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
    );
  }
}
