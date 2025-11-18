import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';

/// Service for doctor-patient management operations
class DoctorPatientService {
  /// Get list of patients assigned to a doctor
  Future<List<Map<String, dynamic>>> getDoctorPatients(String doctorId) async {
    try {
      final url = Uri.parse(
        '${AppConstants.tremorApiUrl}/api/v1/doctor/patients?doctor_id=$doctorId'
      );

      print('Fetching patients for doctor: $doctorId');
      print('URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['patients'] != null) {
          return List<Map<String, dynamic>>.from(data['patients']);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load patients: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching doctor patients: $e');
      rethrow;
    }
  }

  /// Assign a patient to a doctor by patient email
  Future<Map<String, dynamic>> assignPatientToDoctor({
    required String doctorId,
    required String patientEmail,
  }) async {
    try {
      final url = Uri.parse(
        '${AppConstants.tremorApiUrl}/api/v1/doctor/assign-patient'
      );

      final body = jsonEncode({
        'doctor_id': doctorId,
        'patient_email': patientEmail,
      });

      print('Assigning patient $patientEmail to doctor $doctorId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['error'] ?? 'Failed to assign patient');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to assign patient');
      }
    } catch (e) {
      print('Error assigning patient: $e');
      rethrow;
    }
  }
}
