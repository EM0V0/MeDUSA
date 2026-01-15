import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import 'patient_detail_page.dart';

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  String searchQuery = '';
  String selectedStatus = '';
  List<String> selectedPatients = [];
  int currentPage = 1;
  final int patientsPerPage = 10;

  final List<Patient> allPatients = [
    Patient(
      id: 'PAT-001',
      name: 'John Doe',
      age: 65,
      gender: 'Male',
      condition: "Parkinson's Disease",
      status: PatientStatus.stable,
      lastReading: DateTime.now().subtract(const Duration(minutes: 15)),
      tremorScore: 4.2,
      phone: '+1 (555) 123-4567',
      email: 'john.doe@email.com',
      address: '123 Main St, City, State 12345',
    ),
    Patient(
      id: 'PAT-002',
      name: 'Jane Smith',
      age: 58,
      gender: 'Female',
      condition: 'Essential Tremor',
      status: PatientStatus.moderate,
      lastReading: DateTime.now().subtract(const Duration(minutes: 32)),
      tremorScore: 6.8,
      phone: '+1 (555) 234-5678',
      email: 'jane.smith@email.com',
      address: '456 Oak Ave, City, State 12345',
    ),
    Patient(
      id: 'PAT-003',
      name: 'Robert Chen',
      age: 72,
      gender: 'Male',
      condition: "Parkinson's Disease",
      status: PatientStatus.critical,
      lastReading: DateTime.now().subtract(const Duration(minutes: 8)),
      tremorScore: 9.1,
      phone: '+1 (555) 345-6789',
      email: 'robert.chen@email.com',
      address: '789 Pine Rd, City, State 12345',
    ),
    Patient(
      id: 'PAT-004',
      name: 'Maria Garcia',
      age: 61,
      gender: 'Female',
      condition: 'Essential Tremor',
      status: PatientStatus.stable,
      lastReading: DateTime.now().subtract(const Duration(hours: 2)),
      tremorScore: 3.5,
      phone: '+1 (555) 456-7890',
      email: 'maria.garcia@email.com',
      address: '321 Elm St, City, State 12345',
    ),
    Patient(
      id: 'PAT-005',
      name: 'David Park',
      age: 69,
      gender: 'Male',
      condition: "Parkinson's Disease",
      status: PatientStatus.moderate,
      lastReading: DateTime.now().subtract(const Duration(minutes: 45)),
      tremorScore: 7.3,
      phone: '+1 (555) 567-8901',
      email: 'david.park@email.com',
      address: '654 Maple Dr, City, State 12345',
    ),
  ];

  List<Patient> get filteredPatients {
    return allPatients.where((patient) {
      bool matchesSearch = searchQuery.isEmpty ||
          patient.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          patient.id.toLowerCase().contains(searchQuery.toLowerCase()) ||
          patient.condition.toLowerCase().contains(searchQuery.toLowerCase());

      bool matchesStatus =
          selectedStatus.isEmpty || patient.status.toString().split('.').last == selectedStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<Patient> get currentPagePatients {
    final filtered = filteredPatients;
    final startIndex = (currentPage - 1) * patientsPerPage;
    final endIndex = (startIndex + patientsPerPage).clamp(0, filtered.length);

    if (startIndex >= filtered.length) return [];
    return filtered.sublist(startIndex, endIndex);
  }

  int get totalPages {
    return (filteredPatients.length / patientsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.w : 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            SizedBox(height: 24.h),
            _buildFiltersSection(isMobile),
            SizedBox(height: 24.h),
            _buildBulkActions(isMobile),
            SizedBox(height: 16.h),
            Expanded(child: _buildPatientsTable(isMobile)),
            SizedBox(height: 16.h),
            _buildPagination(isMobile),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPatientDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.lightSurface,
        icon: Icon(
          Icons.add,
          size: IconUtils.getResponsiveIconSize(
            isMobile ? IconSizeType.large : IconSizeType.medium, 
            context
          ),
        ),
        label: Text(
          'Add Patient',
          style: FontUtils.body(
            context: context,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Management',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.bold,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${filteredPatients.length} patients - ${filteredPatients.where((p) => p.status == PatientStatus.critical).length} critical',
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ],
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: () => _showAddPatientDialog(context),
            icon: const Icon(Icons.add),
            label: Text('Add Patient',
                style: FontUtils.body(
                  context: context,
                  fontWeight: FontWeight.w600,
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.lightSurface,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            ),
          ),
      ],
    );
  }

  Widget _buildFiltersSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search & Filter',
            style: FontUtils.body(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 16.h),
          if (isMobile) ...[
            // Mobile layout - stacked filters
            _buildSearchField(isMobile),
            SizedBox(height: 12.h),
            _buildStatusFilter(isMobile),
            SizedBox(height: 16.h),
            _buildClearFiltersButton(isMobile),
          ] else ...[
            // Desktop layout - horizontal filters
            Row(
              children: [
                Expanded(flex: 2, child: _buildSearchField(isMobile)),
                SizedBox(width: 16.w),
                Expanded(child: _buildStatusFilter(isMobile)),
                SizedBox(width: 16.w),
                _buildClearFiltersButton(isMobile),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isMobile) {
    return TextField(
      onChanged: (value) {
        setState(() {
          searchQuery = value;
          currentPage = 1; // Reset to first page when searching
        });
      },
      style: FontUtils.body(
        context: context,
        color: AppColors.lightOnSurface,
      ),
      decoration: InputDecoration(
        hintText: 'Search by name, ID, or condition...',
        hintStyle: FontUtils.body(
          context: context,
          color: AppColors.lightOnSurfaceVariant,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: IconUtils.getResponsiveIconSize(
            isMobile ? IconSizeType.large : IconSizeType.medium, 
            context
          ),
          color: AppColors.lightOnSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: isMobile ? 20.h : 12.h, // Increase padding for mobile devices
        ),
      ),
    );
  }

  Widget _buildStatusFilter(bool isMobile) {
    return DropdownButtonFormField<String>(
      value: selectedStatus.isEmpty ? null : selectedStatus,
      style: FontUtils.body(
        context: context,
        color: AppColors.lightOnSurface,
      ),
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: FontUtils.body(
          context: context,
          color: AppColors.lightOnSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: isMobile ? 20.h : 12.h, // Increase padding for mobile devices
        ),
      ),
      items: ['', 'stable', 'moderate', 'critical'].map((status) {
        return DropdownMenuItem<String>(
          value: status,
          child: Text(
            status.isEmpty ? 'All Status' : status.toUpperCase(),
            style: FontUtils.body(
              context: context,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedStatus = value ?? '';
          currentPage = 1; // Reset to first page when filtering
        });
      },
    );
  }

  Widget _buildClearFiltersButton(bool isMobile) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          searchQuery = '';
          selectedStatus = '';
          currentPage = 1;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightOnSurfaceVariant.withValues(alpha: 0.1),
        foregroundColor: AppColors.lightOnSurface,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.w : 12.w,
          vertical: isMobile ? 16.h : 12.h,
        ),
      ),
      child: Text(
        'Clear',
        style: FontUtils.body(
          context: context,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBulkActions(bool isMobile) {
    if (selectedPatients.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Text(
            '${selectedPatients.length} selected',
            style: FontUtils.body(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          if (isMobile && selectedPatients.isNotEmpty) ...[
            IconButton(
              onPressed: _exportSelectedPatients,
              icon: const Icon(Icons.download_outlined, color: AppColors.primary),
              tooltip: 'Export Selected',
            ),
            IconButton(
              onPressed: _sendMessageToSelected,
              icon: const Icon(Icons.message_outlined, color: AppColors.primary),
              tooltip: 'Send Message',
            ),
            IconButton(
              onPressed: _deleteSelectedPatients,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete Selected',
            ),
          ] else ...[
            TextButton.icon(
              onPressed: _exportSelectedPatients,
              icon: const Icon(Icons.download_outlined),
              label: Text('Export',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            SizedBox(width: 8.w),
            TextButton.icon(
              onPressed: _sendMessageToSelected,
              icon: const Icon(Icons.message_outlined),
              label: Text('Message',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            SizedBox(width: 8.w),
            TextButton.icon(
              onPressed: _deleteSelectedPatients,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              label: Text('Delete',
                  style: FontUtils.body(
                    context: context,
                    color: AppColors.error,
                  )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientsTable(bool isMobile) {
    final patients = currentPagePatients;

    if (patients.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          if (!isMobile) _buildTableHeader(),

          // Patient List
          Expanded(
            child: ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                return _buildPatientRow(patients[index], isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final allSelected = selectedPatients.length == currentPagePatients.length && currentPagePatients.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.r),
          topRight: Radius.circular(12.r),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (value) {
              setState(() {
                if (allSelected) {
                  selectedPatients.clear();
                } else {
                  selectedPatients = currentPagePatients.map((p) => p.id).toList();
                }
              });
            },
            activeColor: AppColors.primary,
          ),
          SizedBox(width: 16.w),
          Expanded(
              flex: 2,
              child: Text('Patient',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ))),
          Expanded(
              child: Text('Condition',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ))),
          Expanded(
              child: Text('Status',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ))),
          Expanded(
              child: Text('Last Reading',
                  style: FontUtils.body(
                    context: context,
                    fontWeight: FontWeight.w600,
                  ))),
          SizedBox(width: 60.w), // Actions column
        ],
      ),
    );
  }

  Widget _buildPatientRow(Patient patient, bool isMobile) {
    final isSelected = selectedPatients.contains(patient.id);
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    selectedPatients.add(patient.id);
                  } else {
                    selectedPatients.remove(patient.id);
                  }
                });
              },
            ),
            SizedBox(width: 16.w),

            // Patient Column (flex: 2)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  // Navigate to patient detail page with tremor chart
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PatientDetailPage(
                        patientId: patient.id,
                        patientName: patient.name,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            patient.name,
                            style: FontUtils.body(
                              context: context,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightOnSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'ID: ${patient.id}',
                      style: FontUtils.caption(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Condition Column (flex: 1)
            Expanded(
              child: Text(
                patient.condition,
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurface,
                ),
              ),
            ),

            // Status Column (flex: 1)
            Expanded(
              child: _buildStatusBadge(patient.status, isMobile),
            ),

            // Last Reading Column (flex: 1)
            Expanded(
              child: Text(
                _formatLastReading(patient.lastReading),
                style: FontUtils.caption(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
            ),

            // Actions Column
            SizedBox(width: 8.w),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
              ),
              onSelected: (value) => _handlePatientAction(value, patient),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Text(
                    'View Details',
                    style: FontUtils.body(context: context),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(
                    'Edit Patient',
                    style: FontUtils.body(context: context),
                  ),
                ),
                PopupMenuItem(
                  value: 'message',
                  child: Text(
                    'Send Message',
                    style: FontUtils.body(context: context),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete Patient',
                    style: FontUtils.body(context: context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PatientStatus status, bool isMobile) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case PatientStatus.stable:
        backgroundColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        label = 'Stable';
        break;
      case PatientStatus.moderate:
        backgroundColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        label = 'Moderate';
        break;
      case PatientStatus.critical:
        backgroundColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        label = 'Critical';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8.w : 6.w,
        vertical: isMobile ? 4.h : 2.h,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: FontUtils.caption(
          context: context,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: IconUtils.getResponsiveIconSize(
              isMobile ? IconSizeType.xxlarge : IconSizeType.xlarge, 
              context
            ),
            color: AppColors.lightOnSurfaceVariant,
          ),
          SizedBox(height: 16.h),
          Text(
            'No patients found',
            style: FontUtils.title(
              context: context,
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try adjusting your search or add a new patient',
            style: FontUtils.body(
              context: context,
              color: AppColors.lightOnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(bool isMobile) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 1
              ? () {
                  setState(() {
                    currentPage--;
                  });
                }
              : null,
          icon: Icon(
            Icons.chevron_left,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
        ),
        ...List.generate(totalPages, (index) {
          final page = index + 1;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: TextButton(
              onPressed: () {
                setState(() {
                  currentPage = page;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: currentPage == page ? AppColors.primary : null,
                foregroundColor: currentPage == page ? AppColors.lightSurface : AppColors.lightOnSurface,
              ),
              child: Text(
                '$page',
                style: FontUtils.body(
                  context: context,
                ),
              ),
            ),
          );
        }),
        IconButton(
          onPressed: currentPage < totalPages
              ? () {
                  setState(() {
                    currentPage++;
                  });
                }
              : null,
          icon: Icon(
            Icons.chevron_right,
            size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
          ),
        ),
      ],
    );
  }

  String _formatLastReading(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Action methods
  void _showAddPatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: FontUtils.titleText('Add New Patient', context),
        content: FontUtils.bodyText('Add patient feature will be implemented soon.', context),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: FontUtils.bodyText('OK', context),
          ),
        ],
      ),
    );
  }

  void _editPatient(Patient patient) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing patient: ${patient.name}')),
    );
  }

  void _deletePatient(Patient patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: FontUtils.titleText('Delete Patient', context),
        content: FontUtils.bodyText('Are you sure you want to delete ${patient.name}?', context),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: FontUtils.bodyText('Deleted patient: ${patient.name}', context),
                ),
              );
            },
            child: FontUtils.bodyText('Delete', context),
          ),
        ],
      ),
    );
  }

  void _exportSelectedPatients() {
    if (selectedPatients.isEmpty) return;

    _showSnackBar('Exporting data for ${selectedPatients.length} patients...');
  }

  void _sendMessageToSelected() {
    if (selectedPatients.isEmpty) return;

    _showSnackBar('Sending message to ${selectedPatients.length} patients...');
  }

  void _deleteSelectedPatients() {
    if (selectedPatients.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: FontUtils.titleText('Delete Patients', context),
        content: FontUtils.bodyText('Are you sure you want to delete ${selectedPatients.length} patients?', context),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              allPatients.removeWhere((p) => selectedPatients.contains(p.id));
              selectedPatients.clear();
              setState(() {});
              _showSnackBar('Selected patients deleted successfully');
            },
            child: FontUtils.bodyText('Delete', context),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: FontUtils.bodyText(message, context),
      ),
    );
  }

  void _showPatientDetails(Patient patient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: FontUtils.titleText('Patient Details', context),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Name', patient.name),
                _buildDetailRow('ID', patient.id),
                _buildDetailRow('Age', '${patient.age} years'),
                _buildDetailRow('Gender', patient.gender),
                _buildDetailRow('Condition', patient.condition),
                _buildDetailRow('Status', patient.status.toString().split('.').last),
                _buildDetailRow('Tremor Score', '${patient.tremorScore}'),
                _buildDetailRow('Phone', patient.phone),
                _buildDetailRow('Email', patient.email),
                _buildDetailRow('Address', patient.address),
                _buildDetailRow('Last Reading', _formatLastReading(patient.lastReading)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: FontUtils.body(context: context),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editPatient(patient);
              },
              child: Text(
                'Edit',
                style: FontUtils.body(
                  context: context,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: FontUtils.body(
                context: context,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: FontUtils.body(
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePatientAction(String value, Patient patient) {
    switch (value) {
      case 'view':
        // Navigate to patient detail page with tremor chart
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PatientDetailPage(
              patientId: patient.id,
              patientName: patient.name,
            ),
          ),
        );
        break;
      case 'edit':
        _editPatient(patient);
        break;
      case 'message':
        _sendMessageToSelected();
        break;
      case 'delete':
        _deletePatient(patient);
        break;
    }
  }
}

// Data models
enum PatientStatus { stable, moderate, critical }

class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String condition;
  final PatientStatus status;
  final DateTime lastReading;
  final double tremorScore;
  final String phone;
  final String email;
  final String address;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.condition,
    required this.status,
    required this.lastReading,
    required this.tremorScore,
    required this.phone,
    required this.email,
    required this.address,
  });
}
