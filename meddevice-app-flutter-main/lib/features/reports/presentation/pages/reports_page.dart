import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String selectedReportType = '';
  String selectedPatientId = '';
  String searchQuery = '';

  final List<String> reportTypes = [
    'Tremor Analysis Report',
    'Medication Effectiveness Report',
    'Daily Activity Summary',
    'Sleep Quality Analysis',
    'Progress Tracking Report',
  ];

  final List<Patient> patients = [
    Patient(id: 'PAT-001', name: 'John Doe'),
    Patient(id: 'PAT-002', name: 'Jane Smith'),
    Patient(id: 'PAT-003', name: 'Robert Chen'),
    Patient(id: 'PAT-004', name: 'Maria Garcia'),
  ];

  final List<Report> reports = [
    Report(
      id: 'RPT-001',
      title: 'Weekly Tremor Analysis - John Doe',
      type: 'Tremor Analysis Report',
      patientName: 'John Doe',
      createdDate: DateTime.now().subtract(const Duration(days: 2)),
      status: ReportStatus.completed,
      author: 'Dr. Smith',
    ),
    Report(
      id: 'RPT-002',
      title: 'Medication Effectiveness - Jane Smith',
      type: 'Medication Effectiveness Report',
      patientName: 'Jane Smith',
      createdDate: DateTime.now().subtract(const Duration(days: 5)),
      status: ReportStatus.processing,
      author: 'Dr. Johnson',
    ),
    Report(
      id: 'RPT-003',
      title: 'Daily Activity Summary - Robert Chen',
      type: 'Daily Activity Summary',
      patientName: 'Robert Chen',
      createdDate: DateTime.now().subtract(const Duration(days: 1)),
      status: ReportStatus.completed,
      author: 'Dr. Williams',
    ),
  ];

  List<Report> get filteredReports {
    return reports.where((report) {
      bool matchesSearch = searchQuery.isEmpty ||
          report.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          report.patientName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          report.author.toLowerCase().contains(searchQuery.toLowerCase());

      bool matchesType = selectedReportType.isEmpty || report.type == selectedReportType;
      bool matchesPatient =
          selectedPatientId.isEmpty || report.patientName == patients.firstWhere((p) => p.id == selectedPatientId).name;

      return matchesSearch && matchesType && matchesPatient;
    }).toList();
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
            _buildReportsGrid(isMobile),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateReportDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.lightSurface,
        icon: Icon(
          Icons.add,
          size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        ),
        label: Text(
          'Generate Report',
          style: FontUtils.body(
            fontWeight: FontWeight.w600,
            context: context,
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
              'Reports Management',
              style: FontUtils.title(
                fontWeight: FontWeight.bold,
                color: AppColors.lightOnSurface,
                context: context,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Generate, view and manage patient reports',
              style: FontUtils.body(
                color: AppColors.lightOnSurfaceVariant,
                context: context,
              ),
            ),
          ],
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: () => _showGenerateReportDialog(context),
            icon: Icon(
              Icons.add,
              size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
            ),
            label: Text(
              'Generate Report',
              style: FontUtils.body(
                fontWeight: FontWeight.w600,
                context: context,
              ),
            ),
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
            'Filters',
            style: FontUtils.body(
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
              context: context,
            ),
          ),
          SizedBox(height: 16.h),
          if (isMobile) ...[
            // Mobile layout - stacked filters
            _buildSearchField(isMobile),
            SizedBox(height: 12.h),
            _buildReportTypeFilter(isMobile),
            SizedBox(height: 12.h),
            _buildPatientFilter(isMobile),
            SizedBox(height: 16.h),
            _buildClearFiltersButton(isMobile),
          ] else ...[
            // Desktop layout - horizontal filters
            Row(
              children: [
                Expanded(flex: 2, child: _buildSearchField(isMobile)),
                SizedBox(width: 16.w),
                Expanded(child: _buildReportTypeFilter(isMobile)),
                SizedBox(width: 16.w),
                Expanded(child: _buildPatientFilter(isMobile)),
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
        });
      },
      style: FontUtils.body(
        color: AppColors.lightOnSurface,
        context: context,
      ),
      decoration: InputDecoration(
        hintText: 'Search reports, patients, or authors...',
        hintStyle: FontUtils.body(
          color: AppColors.lightOnSurfaceVariant,
          context: context,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: IconUtils.getResponsiveIconSize(isMobile ? IconSizeType.medium : IconSizeType.small, context),
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
          vertical: isMobile ? 16.h : 12.h,
        ),
      ),
    );
  }

  Widget _buildReportTypeFilter(bool isMobile) {
    return DropdownButtonFormField<String>(
      value: selectedReportType.isEmpty ? null : selectedReportType,
      style: FontUtils.body(
        color: AppColors.lightOnSurface,
        context: context,
      ),
      decoration: InputDecoration(
        labelText: 'Report Type',
        labelStyle: FontUtils.body(
          color: AppColors.lightOnSurfaceVariant,
          context: context,
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
          vertical: isMobile ? 16.h : 12.h,
        ),
      ),
      items: ['', ...reportTypes].map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(
            type.isEmpty ? 'All Types' : type,
            style: FontUtils.body(
              color: AppColors.lightOnSurface,
              context: context,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedReportType = value ?? '';
        });
      },
    );
  }

  Widget _buildPatientFilter(bool isMobile) {
    return DropdownButtonFormField<String>(
      value: selectedPatientId.isEmpty ? null : selectedPatientId,
      style: FontUtils.body(
        color: AppColors.lightOnSurface,
        context: context,
      ),
      decoration: InputDecoration(
        labelText: 'Patient',
        labelStyle: FontUtils.body(
          color: AppColors.lightOnSurfaceVariant,
          context: context,
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
          vertical: isMobile ? 16.h : 12.h,
        ),
      ),
      items: ['', ...patients.map((p) => p.id)].map((id) {
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            id.isEmpty ? 'All Patients' : patients.firstWhere((p) => p.id == id).name,
            style: FontUtils.body(
              color: AppColors.lightOnSurface,
              context: context,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedPatientId = value ?? '';
        });
      },
    );
  }

  Widget _buildClearFiltersButton(bool isMobile) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedReportType = '';
          selectedPatientId = '';
          searchQuery = '';
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
          fontWeight: FontWeight.w500,
          context: context,
        ),
      ),
    );
  }

  Widget _buildReportsGrid(bool isMobile) {
    final filteredList = filteredReports;

    return Expanded(
      child: filteredList.isEmpty
          ? _buildEmptyState(isMobile)
          : ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                return _buildReportCard(filteredList[index], isMobile);
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: IconUtils.getResponsiveIconSize(isMobile ? IconSizeType.xxlarge : IconSizeType.xlarge, context),
            color: AppColors.lightOnSurfaceVariant,
          ),
          SizedBox(height: 16.h),
          Text(
            'No reports found',
            style: FontUtils.title(
              fontWeight: FontWeight.w600,
              color: AppColors.lightOnSurface,
              context: context,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try adjusting your filters or generate a new report',
            style: FontUtils.body(
              color: AppColors.lightOnSurfaceVariant,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Report report, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: FontUtils.body(
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurface,
                    context: context,
                  ),
                ),
              ),
              _buildStatusBadge(report.status, isMobile),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                color: AppColors.lightOnSurfaceVariant,
              ),
              SizedBox(width: 4.w),
              Text(
                report.patientName,
                style: FontUtils.body(
                  color: AppColors.lightOnSurfaceVariant,
                  context: context,
                ),
              ),
              SizedBox(width: 16.w),
              Icon(
                Icons.person_outline,
                size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                color: AppColors.lightOnSurfaceVariant,
              ),
              SizedBox(width: 4.w),
              Text(
                'By ${report.author}',
                style: FontUtils.body(
                  color: AppColors.lightOnSurfaceVariant,
                  context: context,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: IconUtils.getResponsiveIconSize(IconSizeType.small, context),
                color: AppColors.lightOnSurfaceVariant,
              ),
              SizedBox(width: 4.w),
              Text(
                _formatDate(report.createdDate),
                style: FontUtils.body(
                  color: AppColors.lightOnSurfaceVariant,
                  context: context,
                ),
              ),
              const Spacer(),
              if (report.status == ReportStatus.completed) ...[
                IconButton(
                  onPressed: () => _viewReport(report),
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: IconUtils.getResponsiveIconSize(isMobile ? IconSizeType.medium : IconSizeType.small, context),
                    color: AppColors.primary,
                  ),
                  tooltip: 'View Report',
                ),
                IconButton(
                  onPressed: () => _downloadReport(report),
                  icon: Icon(
                    Icons.download_outlined,
                    size: IconUtils.getResponsiveIconSize(isMobile ? IconSizeType.medium : IconSizeType.small, context),
                    color: AppColors.success,
                  ),
                  tooltip: 'Download Report',
                ),
              ],
              IconButton(
                onPressed: () => _deleteReport(report),
                icon: Icon(
                  Icons.delete_outline,
                  size: IconUtils.getResponsiveIconSize(isMobile ? IconSizeType.medium : IconSizeType.small, context),
                  color: AppColors.error,
                ),
                tooltip: 'Delete Report',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ReportStatus status, bool isMobile) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case ReportStatus.processing:
        backgroundColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        label = 'Processing';
        break;
      case ReportStatus.completed:
        backgroundColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        label = 'Completed';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12.w : 8.w,
        vertical: isMobile ? 6.h : 4.h,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: FontUtils.body(
          fontWeight: FontWeight.w600,
          color: textColor,
          context: context,
        ),
      ),
    );
  }

  void _showGenerateReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Generate New Report',
          style: FontUtils.title(
            context: context,
          ),
        ),
        content: Text(
          'Report generation feature will be implemented soon.',
          style: FontUtils.body(
            context: context,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: FontUtils.body(
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewReport(Report report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
        'Viewing report: ${report.title}',
        style: FontUtils.body(
          context: context,
        ),
      )),
    );
  }

  void _downloadReport(Report report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
        'Downloading report: ${report.title}',
        style: FontUtils.body(
          context: context,
        ),
      )),
    );
  }

  void _deleteReport(Report report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Report',
          style: FontUtils.title(
            context: context,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${report.title}"?',
          style: FontUtils.body(
            context: context,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: FontUtils.body(
                context: context,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                  'Deleted report: ${report.title}',
                  style: FontUtils.body(
                    context: context,
                  ),
                )),
              );
            },
            child: Text(
              'Delete',
              style: FontUtils.body(
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Data models
class Patient {
  final String id;
  final String name;

  Patient({required this.id, required this.name});
}

enum ReportStatus { processing, completed }

class Report {
  final String id;
  final String title;
  final String type;
  final String patientName;
  final DateTime createdDate;
  final ReportStatus status;
  final String author;

  Report({
    required this.id,
    required this.title,
    required this.type,
    required this.patientName,
    required this.createdDate,
    required this.status,
    required this.author,
  });
}
