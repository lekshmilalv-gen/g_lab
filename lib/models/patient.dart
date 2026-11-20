import 'package:flutter/foundation.dart';

import '../services/patient_service.dart';

class Patient {
  Patient({
    required this.patientId,
    required this.name,
    this.dob,
    this.doctor = '',
    this.height = '',
    this.weight = '',
    this.gender,
    this.phone = '',
    this.remark = '',
    this.photoPath,
    this.serverId,
    this.doctorId,
    this.age,
    this.email = '',
    this.address = '',
    this.diagnosis = '',
    this.isActive = true,
    this.sessionCount = 0,
    this.lastSessionAt,
  });

  /// Builds a patient from one item of `GET /api/patients/`.
  factory Patient.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] as String?)?.trim() ?? '';
    return Patient(
      serverId: (json['id'] as num?)?.toInt(),
      doctorId: json['doctor_id'] as String?,
      patientId: str('patient_id'),
      name: str('name'),
      doctor: (json['doctor_name'] as String?) ?? '',
      dob: DateTime.tryParse(str('date_of_birth')),
      height: json['height_cm']?.toString() ?? '',
      weight: json['weight_kg']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt(),
      gender: _genderFromApi(str('gender')),
      phone: str('phone'),
      email: str('email'),
      address: str('address'),
      diagnosis: str('diagnosis'),
      remark: str('notes'),
      isActive: json['is_active'] as bool? ?? true,
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
      lastSessionAt: DateTime.tryParse(str('last_session_at'))?.toLocal(),
    );
  }

  /// API values (MALE / FEMALE / OTHER / UNSPECIFIED) to the form's options.
  static String? _genderFromApi(String value) => switch (value.toUpperCase()) {
    'MALE' => 'Male',
    'FEMALE' => 'Female',
    'OTHER' => 'Other',
    _ => null,
  };

  final String patientId;
  final String name;
  final DateTime? dob;
  final String doctor;
  final String height;
  final String weight;
  final String? gender;
  final String phone;
  final String remark;

  /// Local file path of the captured profile photo, if any.
  final String? photoPath;

  /// Backend record id; null for patients created only on this device.
  final int? serverId;
  final String? doctorId;
  final int? age;
  final String email;
  final String address;
  final String diagnosis;
  final bool isActive;
  final int sessionCount;
  final DateTime? lastSessionAt;
}

/// Patients loaded from the backend plus any created on this device, shared
/// by every screen. Widgets rebuild via [ListenableBuilder] when it changes.
class PatientStore extends ChangeNotifier {
  PatientStore._();

  static final PatientStore instance = PatientStore._();

  final List<Patient> _patients = [];

  List<Patient> get patients => List.unmodifiable(_patients);

  /// Where [load] gets patients from; tests swap in a fake.
  @visibleForTesting
  Future<List<Patient>> Function() fetcher = PatientService.instance.fetchAll;

  bool _loading = false;
  bool get loading => _loading;
  Future<void>? _loadOperation;

  /// Message from the last failed [load], or null.
  String? _error;
  String? get error => _error;

  /// Replaces the server patients with a fresh copy from the backend.
  /// Patients created only on this device are kept.
  Future<void> load() {
    final Future<void>? pending = _loadOperation;
    if (pending != null) return pending;
    late final Future<void> operation;
    operation = _load().whenComplete(() {
      if (identical(_loadOperation, operation)) _loadOperation = null;
    });
    _loadOperation = operation;
    return operation;
  }

  /// Waits for any in-flight request, then fetches a fresh patient list.
  Future<void> reload() async {
    final Future<void>? pending = _loadOperation;
    if (pending != null) await pending;
    await load();
  }

  Future<void> _load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final List<Patient> fetched = await fetcher();
      _patients
        ..removeWhere((p) => p.serverId != null)
        ..insertAll(0, fetched);
    } on PatientServiceException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Distinct consulting doctors already entered, for the doctor picker.
  List<String> get doctors => {
    for (final p in _patients)
      if (p.doctor.trim().isNotEmpty) p.doctor.trim(),
  }.toList();

  /// Whether [patientId] is used by a patient other than [except].
  bool isIdTaken(String patientId, {Patient? except}) => _patients.any(
    (p) =>
        !identical(p, except) &&
        p.patientId.toLowerCase() == patientId.trim().toLowerCase(),
  );

  /// Next free ID in the form P0001, P0002, ...
  String nextPatientId() {
    int n = _patients.length + 1;
    String id;
    do {
      id = 'P${n.toString().padLeft(4, '0')}';
      n++;
    } while (isIdTaken(id));
    return id;
  }

  void add(Patient patient) {
    _patients.add(patient);
    notifyListeners();
  }

  void replace(Patient old, Patient updated) {
    final int i = _patients.indexWhere((p) => identical(p, old));
    if (i == -1) return;
    _patients[i] = updated;
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _patients.clear();
    notifyListeners();
  }
}
