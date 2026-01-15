import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/font_utils.dart';
import '../../../../core/utils/icon_utils.dart';

/// Symptoms tracking page for patients
/// Allows patients to record and monitor their tremor symptoms
class SymptomsPage extends StatefulWidget {
  const SymptomsPage({super.key});

  @override
  State<SymptomsPage> createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  final TextEditingController _notesController = TextEditingController();
  
  double _tremorIntensity = 3.0;

  // Demo symptom records
  final List<SymptomRecord> _recentRecords = [
    SymptomRecord(
      id: '1',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      intensity: 4.0,
      symptoms: ['Hand tremor', 'Difficulty writing'],
      trigger: 'Stress',
      notes: 'Had an important meeting today, tremor was more noticeable',
    ),
    SymptomRecord(
      id: '2',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      intensity: 2.0,
      symptoms: ['Hand tremor'],
      trigger: 'Caffeine',
      notes: 'Morning coffee seemed to increase tremor slightly',
    ),
    SymptomRecord(
      id: '3',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      intensity: 1.0,
      symptoms: ['Hand tremor'],
      trigger: '',
      notes: 'Very mild symptoms today, feeling good',
    ),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24.h),
            _buildQuickLogSection(isMobile),
            SizedBox(height: 24.h),
            _buildRecentRecordsSection(isMobile),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDetailedLogDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.onPrimary),
        label: Text(
          'Log Symptoms',
          style: FontUtils.body(
            context: context,
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.health_and_safety,
          color: AppColors.primary,
          size: IconUtils.getResponsiveIconSize(IconSizeType.large, context),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Symptom Tracking',
                style: FontUtils.title(
                  context: context,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                'Monitor your tremor symptoms and patterns',
                style: FontUtils.body(
                  context: context,
                  color: AppColors.lightOnSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLogSection(bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Symptom Log',
              style: FontUtils.title(
                context: context,
                fontWeight: FontWeight.w600,
                color: AppColors.lightOnSurface,
              ),
            ),
            SizedBox(height: 16.h),
            
            // Tremor intensity slider
            Text(
              'Current Tremor Intensity',
              style: FontUtils.body(
                context: context,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Text(
                  'Mild',
                  style: FontUtils.caption(context: context),
                ),
                Expanded(
                  child: Slider(
                    value: _tremorIntensity,
                    min: 1.0,
                    max: 5.0,
                    divisions: 4,
                    activeColor: _getIntensityColor(_tremorIntensity),
                    onChanged: (value) {
                      setState(() {
                        _tremorIntensity = value;
                      });
                    },
                  ),
                ),
                Text(
                  'Severe',
                  style: FontUtils.caption(context: context),
                ),
              ],
            ),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _getIntensityColor(_tremorIntensity).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${_tremorIntensity.toInt()}/5 - ${_getIntensityLabel(_tremorIntensity)}',
                  style: FontUtils.body(
                    context: context,
                    color: _getIntensityColor(_tremorIntensity),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 20.h),
            
            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _logQuickSymptom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Quick Log'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showDetailedLogDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Detailed Log'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecordsSection(bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Records',
                    style: FontUtils.title(
                      context: context,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to full symptom history
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            if (_recentRecords.isEmpty) ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: IconUtils.getProtectedSize(
                        context,
                        targetSize: 48.0,
                        minSize: 36.0, // Never smaller than 36px
                      ),
                      color: AppColors.lightOnSurfaceVariant,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No symptom records yet',
                      style: FontUtils.body(
                        context: context,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ..._recentRecords.map((record) => _buildRecordCard(record)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(SymptomRecord record) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: _getIntensityColor(record.intensity).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  record.intensity.toInt().toString(),
                  style: FontUtils.caption(
                    context: context,
                    color: _getIntensityColor(record.intensity),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(record.timestamp),
                      style: FontUtils.body(
                        context: context,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.trigger.isNotEmpty)
                      Text(
                        'Trigger: ${record.trigger}',
                        style: FontUtils.caption(
                          context: context,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _getIntensityLabel(record.intensity),
                style: FontUtils.caption(
                  context: context,
                  color: _getIntensityColor(record.intensity),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          if (record.symptoms.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: record.symptoms.map((symptom) => Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  symptom,
                  style: FontUtils.caption(
                    context: context,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
          
          if (record.notes.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              record.notes,
              style: FontUtils.body(
                context: context,
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getIntensityColor(double intensity) {
    if (intensity <= 2) return AppColors.success;
    if (intensity <= 3) return AppColors.warning;
    return AppColors.error;
  }

  String _getIntensityLabel(double intensity) {
    if (intensity <= 1) return 'Very Mild';
    if (intensity <= 2) return 'Mild';
    if (intensity <= 3) return 'Moderate';
    if (intensity <= 4) return 'Severe';
    return 'Very Severe';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _logQuickSymptom() {
    // Create a quick symptom record
    final newRecord = SymptomRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      intensity: _tremorIntensity,
      symptoms: ['Hand tremor'], // Default symptom for quick log
      trigger: '',
      notes: 'Quick log entry',
    );

    // In a real app, this would be saved to the database
    setState(() {
      _recentRecords.insert(0, newRecord);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Symptom logged successfully'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showDetailedLogDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detailed Symptom Log'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This would show a detailed form for logging symptoms with:'),
              SizedBox(height: 8.h),
              const Text('- Multiple symptom selection'),
              const Text('- Trigger identification'),
              const Text('- Detailed notes'),
              const Text('- Photo attachments'),
              const Text('- Medication timing'),
              const Text('- Activity correlation'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logQuickSymptom(); // For demo purposes
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Symptom record data model
class SymptomRecord {
  final String id;
  final DateTime timestamp;
  final double intensity;
  final List<String> symptoms;
  final String trigger;
  final String notes;

  const SymptomRecord({
    required this.id,
    required this.timestamp,
    required this.intensity,
    required this.symptoms,
    required this.trigger,
    required this.notes,
  });
}
