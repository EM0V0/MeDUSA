import 'package:flutter/foundation.dart';
import '../../../../shared/services/network_service.dart';

/// Service for doctor-patient management operations
class DoctorPatientService {
  final NetworkService _networkService;

  DoctorPatientService(this._networkService);

  /// Get list of patients assigned to a doctor
  Future<List<Map<String, dynamic>>> getDoctorPatients(String doctorId) async {
    try {
      debugPrint('Fetching patients for doctor: $doctorId');

      final response = await _networkService.get(
        '/doctor/patients',
        queryParameters: {'doctor_id': doctorId},
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['patients'] != null) {
          return List<Map<String, dynamic>>.from(data['patients']);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load patients: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching doctor patients: $e');
      rethrow;
    }
  }

  /// Assign a patient to a doctor by patient email
  Future<Map<String, dynamic>> assignPatientToDoctor({
    required String doctorId,
    required String patientEmail,
  }) async {
    try {
      final body = {
        'doctor_id': doctorId,
        'patient_email': patientEmail,
      };

      debugPrint('Assigning patient $patientEmail to doctor $doctorId');

      final response = await _networkService.post(
        '/doctor/assign-patient',
        data: body,
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['error'] ?? 'Failed to assign patient');
        }
      } else {
        final data = response.data;
        throw Exception(data['error'] ?? 'Failed to assign patient');
      }
    } catch (e) {
      debugPrint('Error assigning patient: $e');
      rethrow;
    }
  }
}
