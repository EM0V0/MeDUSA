import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/font_utils.dart';
import '../../core/utils/icon_utils.dart';
import '../services/role_service.dart';

/// Patient selector widget for doctors
/// Allows doctors to select and switch between different patients for data visualization
class PatientSelector extends StatefulWidget {
  final String? selectedPatientId;
  final Function(PatientInfo?) onPatientSelected;
  final bool allowMultiSelect;
  final List<String>? selectedPatientIds;
  final Function(List<PatientInfo>)? onMultipleSelection;

  const PatientSelector({
    super.key,
    this.selectedPatientId,
    required this.onPatientSelected,
    this.allowMultiSelect = false,
    this.selectedPatientIds,
    this.onMultipleSelection,
  });

  @override
  State<PatientSelector> createState() => _PatientSelectorState();
}

class _PatientSelectorState extends State<PatientSelector> {
  final RoleService _roleService = RoleService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showDropdown = false;

  // Demo patients assigned to the current doctor
  final List<PatientInfo> _assignedPatients = [
    PatientInfo(
      id: 'PAT-001',
      name: 'John Doe',
      age: 65,
      gender: 'Male',
      condition: "Parkinson's Disease",
      severity: PatientSeverity.moderate,
      lastReading: DateTime.now().subtract(const Duration(minutes: 15)),
      averageTremorScore: 4.2,
      sensorStatus: SensorStatus.active,
      medicationAdherence: 0.85,
    ),
    PatientInfo(
      id: 'PAT-002',
      name: 'Jane Smith',
      age: 58,
      gender: 'Female',
      condition: 'Essential Tremor',
      severity: PatientSeverity.mild,
      lastReading: DateTime.now().subtract(const Duration(minutes: 32)),
      averageTremorScore: 2.8,
      sensorStatus: SensorStatus.active,
      medicationAdherence: 0.92,
    ),
    PatientInfo(
      id: 'PAT-003',
      name: 'Robert Chen',
      age: 72,
      gender: 'Male',
      condition: "Parkinson's Disease",
      severity: PatientSeverity.severe,
      lastReading: DateTime.now().subtract(const Duration(minutes: 8)),
      averageTremorScore: 7.1,
      sensorStatus: SensorStatus.warning,
      medicationAdherence: 0.78,
    ),
    PatientInfo(
      id: 'PAT-004',
      name: 'Maria Garcia',
      age: 61,
      gender: 'Female',
      condition: 'Essential Tremor',
      severity: PatientSeverity.moderate,
      lastReading: DateTime.now().subtract(const Duration(hours: 2)),
      averageTremorScore: 5.3,
      sensorStatus: SensorStatus.active,
      medicationAdherence: 0.88,
    ),
    PatientInfo(
      id: 'PAT-005',
      name: 'David Wilson',
      age: 67,
      gender: 'Male',
      condition: "Parkinson's Disease",
      severity: PatientSeverity.mild,
      lastReading: DateTime.now().subtract(const Duration(hours: 4)),
      averageTremorScore: 3.1,
      sensorStatus: SensorStatus.inactive,
      medicationAdherence: 0.95,
    ),
  ];

  List<PatientInfo> get _filteredPatients {
    if (_searchQuery.isEmpty) {
      return _assignedPatients;
    }
    return _assignedPatients.where((patient) {
      return patient.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             patient.condition.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             patient.id.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show for doctors
    if (!_roleService.isDoctor) {
      return const SizedBox.shrink();
    }

    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : 400.w,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectorHeader(),
          SizedBox(height: 8.h),
          _buildPatientDropdown(isMobile),
          if (widget.allowMultiSelect && widget.selectedPatientIds != null) ...[
            SizedBox(height: 12.h),
            _buildSelectedPatientsChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorHeader() {
    return Row(
      children: [
        Icon(
          Icons.people_outline,
          color: AppColors.primary,
          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            widget.allowMultiSelect ? 'Select Patients' : 'Select Patient',
            style: FontUtils.body(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        SizedBox(width: 8.w),
        if (_assignedPatients.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              '${_assignedPatients.length} patients',
              style: FontUtils.caption(
                context: context,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPatientDropdown(bool isMobile) {
    final selectedPatient = _assignedPatients
        .where((p) => p.id == widget.selectedPatientId)
        .firstOrNull;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showDropdown = !_showDropdown;
        });
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _showDropdown ? AppColors.primary : AppColors.lightDivider,
            width: _showDropdown ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (selectedPatient != null) ...[
                  _buildPatientAvatar(selectedPatient, size: 32.w),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPatient.name,
                          style: FontUtils.body(
                            context: context,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${selectedPatient.condition} - ${selectedPatient.severity.displayName}',
                          style: FontUtils.caption(
                            context: context,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      'Select a patient to view data',
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                Icon(
                  _showDropdown ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ],
            ),
            
            if (_showDropdown) ...[
              SizedBox(height: 12.h),
              _buildSearchField(),
              SizedBox(height: 8.h),
              _buildPatientsList(isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search patients...',
        prefixIcon: Icon(
          Icons.search,
          size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.r),
          borderSide: const BorderSide(color: AppColors.lightDivider),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        isDense: true,
      ),
      style: FontUtils.body(context: context),
    );
  }

  Widget _buildPatientsList(bool isMobile) {
    final filteredPatients = _filteredPatients;
    
    return Container(
      constraints: BoxConstraints(maxHeight: 200.h),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filteredPatients.length,
        itemBuilder: (context, index) {
          final patient = filteredPatients[index];
          final isSelected = widget.selectedPatientId == patient.id;
          
          return InkWell(
            onTap: () {
              widget.onPatientSelected(patient);
              setState(() {
                _showDropdown = false;
                _searchController.clear();
                _searchQuery = '';
              });
            },
            child: Container(
              padding: EdgeInsets.all(8.w),
              margin: EdgeInsets.only(bottom: 4.h),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                children: [
                  _buildPatientAvatar(patient, size: 28.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        patient.name,
                        style: FontUtils.body(
                          context: context,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                patient.condition,
                                style: FontUtils.caption(
                                  context: context,
                                  color: AppColors.lightOnSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            _buildSeverityIndicator(patient.severity),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildSensorStatusIcon(patient.sensorStatus),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPatientsChips() {
    if (widget.selectedPatientIds == null || widget.selectedPatientIds!.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPatients = _assignedPatients
        .where((p) => widget.selectedPatientIds!.contains(p.id))
        .toList();

    return Wrap(
      spacing: 8.w,
      runSpacing: 4.h,
      children: selectedPatients.map((patient) => Chip(
        avatar: _buildPatientAvatar(patient, size: 20.w),
        label: Text(
          patient.name,
          style: FontUtils.caption(context: context),
        ),
        onDeleted: () {
          final updatedIds = List<String>.from(widget.selectedPatientIds!);
          updatedIds.remove(patient.id);
          final updatedPatients = _assignedPatients
              .where((p) => updatedIds.contains(p.id))
              .toList();
          widget.onMultipleSelection?.call(updatedPatients);
        },
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        deleteIconColor: AppColors.primary,
      )).toList(),
    );
  }

  Widget _buildPatientAvatar(PatientInfo patient, {required double size}) {
    // Apply minimum size protection for avatars
    final protectedSize = size < 24.0 ? 24.0 : size; // Never smaller than 24px
    
    return Container(
      width: protectedSize,
      height: protectedSize,
      decoration: BoxDecoration(
        color: _getSeverityColor(patient.severity).withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: _getSeverityColor(patient.severity),
          width: 1,
        ),
      ),
      child: Icon(
        patient.gender == 'Male' ? Icons.person : Icons.person_outline,
        color: _getSeverityColor(patient.severity),
        size: protectedSize * 0.6,
      ),
    );
  }

  Widget _buildSeverityIndicator(PatientSeverity severity) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: _getSeverityColor(severity).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        severity.displayName.toUpperCase(),
        style: FontUtils.caption(
          context: context,
          color: _getSeverityColor(severity),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSensorStatusIcon(SensorStatus status) {
    IconData iconData;
    Color color;

    switch (status) {
      case SensorStatus.active:
        iconData = Icons.sensors;
        color = AppColors.success;
        break;
      case SensorStatus.warning:
        iconData = Icons.warning;
        color = AppColors.warning;
        break;
      case SensorStatus.inactive:
        iconData = Icons.sensors_off;
        color = AppColors.error;
        break;
    }

    return Icon(
      iconData,
      color: color,
      size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
    );
  }

  Color _getSeverityColor(PatientSeverity severity) {
    switch (severity) {
      case PatientSeverity.mild:
        return AppColors.success;
      case PatientSeverity.moderate:
        return AppColors.warning;
      case PatientSeverity.severe:
        return AppColors.error;
    }
  }
}

/// Patient information model for doctor's patient list
class PatientInfo {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String condition;
  final PatientSeverity severity;
  final DateTime lastReading;
  final double averageTremorScore;
  final SensorStatus sensorStatus;
  final double medicationAdherence;

  const PatientInfo({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.condition,
    required this.severity,
    required this.lastReading,
    required this.averageTremorScore,
    required this.sensorStatus,
    required this.medicationAdherence,
  });

  /// Get formatted last reading time
  String get formattedLastReading {
    final now = DateTime.now();
    final difference = now.difference(lastReading);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Get medication adherence percentage as string
  String get medicationAdherencePercent {
    return '${(medicationAdherence * 100).round()}%';
  }
}

/// Patient severity levels
enum PatientSeverity {
  mild('Mild'),
  moderate('Moderate'),
  severe('Severe');

  const PatientSeverity(this.displayName);
  final String displayName;
}

/// Sensor status enumeration
enum SensorStatus {
  active('Active'),
  warning('Warning'),
  inactive('Inactive');

  const SensorStatus(this.displayName);
  final String displayName;
}
