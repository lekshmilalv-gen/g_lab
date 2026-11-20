import '../models/patient.dart';
import 'api_client.dart';

class PatientService {
  PatientService._();

  static final PatientService instance = PatientService._();

  /// Creates a patient and returns the server record, including its id.
  Future<Patient> create(Patient patient) async {
    try {
      final response = await ApiClient.instance.postJson(
        '/api/patients/',
        _payload(patient),
      );
      return _withLocalFields(Patient.fromJson(response), patient);
    } on Exception catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  /// Updates an existing patient by its current patient ID.
  Future<Patient> update(String currentPatientId, Patient patient) async {
    try {
      final response = await ApiClient.instance.patchJson(
        '/api/patients/${Uri.encodeComponent(currentPatientId)}/',
        _payload(patient),
      );
      return _withLocalFields(Patient.fromJson(response), patient);
    } on Exception catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  /// Loads patients from the backend.
  Future<List<Patient>> fetchAll() async {
    try {
      final items = await ApiClient.instance.getJsonList('/api/patients/');
      return items
          .whereType<Map<String, dynamic>>()
          .map(Patient.fromJson)
          .toList();
    } on Exception catch (e) {
      throw PatientServiceException(e.toString());
    }
  }

  static String _genderToApi(String? gender) => switch (gender?.toLowerCase()) {
    'male' => 'MALE',
    'female' => 'FEMALE',
    'other' => 'OTHER',
    _ => 'UNSPECIFIED',
  };

  static Map<String, dynamic> _payload(Patient patient) => {
    'patient_id': patient.patientId,
    'name': patient.name,
    'gender': _genderToApi(patient.gender),
    'phone': patient.phone,
    'doctor_id': patient.doctorId,
    'doctor_name': patient.doctor.isEmpty ? null : patient.doctor,
    'height_cm': num.tryParse(patient.height),
    'weight_kg': num.tryParse(patient.weight),
    'date_of_birth': patient.dob == null
        ? null
        : '${patient.dob!.year.toString().padLeft(4, '0')}-'
              '${patient.dob!.month.toString().padLeft(2, '0')}-'
              '${patient.dob!.day.toString().padLeft(2, '0')}',
    'diagnosis': patient.diagnosis.isNotEmpty
        ? patient.diagnosis
        : patient.remark,
  };

  static Patient _withLocalFields(Patient server, Patient local) => Patient(
    patientId: server.patientId,
    name: server.name,
    dob: server.dob,
    doctorId: server.doctorId ?? local.doctorId,
    doctor: server.doctor.isNotEmpty ? server.doctor : local.doctor,
    height: server.height.isNotEmpty ? server.height : local.height,
    weight: server.weight.isNotEmpty ? server.weight : local.weight,
    gender: server.gender ?? local.gender,
    phone: server.phone,
    remark: server.remark,
    photoPath: local.photoPath,
    serverId: server.serverId,
    age: server.age,
    email: server.email,
    address: server.address,
    diagnosis: server.diagnosis,
    isActive: server.isActive,
    sessionCount: server.sessionCount,
    lastSessionAt: server.lastSessionAt,
  );
}

class PatientServiceException implements Exception {
  const PatientServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
