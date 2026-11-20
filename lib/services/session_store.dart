import 'package:flutter/foundation.dart';

import '../models/patient.dart';
import 'auth_service.dart';
import 'session_service.dart';

class SessionRecord {
  SessionRecord({
    required this.patient,
    required this.startedAt,
    required this.stoppedAt,
    required this.frames,
    required this.leftPressure,
    required this.rightPressure,
    required this.leftZones,
    required this.rightZones,
    this.remark = '',
    this.id,
    this.sessionId,
    this.sessionNumber,
    this.status = '',
    this.deviceId = '',
    this.hasReport = false,
    this.spasmCount = 0,
    this.alertCount = 0,
    this.recordingCount = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json, Patient patient) {
    String string(String key) => json[key]?.toString() ?? '';
    int integer(String key) => (json[key] as num?)?.toInt() ?? 0;
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;

    final DateTime created =
        DateTime.tryParse(string('created_at')) ?? DateTime.now();
    final DateTime started = DateTime.tryParse(string('started_at')) ?? created;
    final int durationSeconds = number('duration_seconds').round();
    final DateTime ended =
        DateTime.tryParse(string('ended_at')) ??
        started.add(Duration(seconds: durationSeconds));

    return SessionRecord(
      patient: patient,
      id: integer('id'),
      sessionId: string('session_id'),
      sessionNumber: integer('session_number'),
      status: string('status'),
      deviceId: string('device_id'),
      startedAt: started.toLocal(),
      stoppedAt: ended.toLocal(),
      frames: integer('sample_count'),
      leftPressure: 0,
      rightPressure: 0,
      leftZones: const [],
      rightZones: const [],
      hasReport: json['has_report'] as bool? ?? false,
      spasmCount: integer('spasm_count'),
      alertCount: integer('alert_count'),
      recordingCount: integer('recording_count'),
      avgSpeed: number('avg_speed'),
      maxSpeed: number('max_speed'),
    );
  }

  final Patient patient;
  final DateTime startedAt;
  final DateTime stoppedAt;
  final int frames;
  final double leftPressure;
  final double rightPressure;
  final List<double> leftZones;
  final List<double> rightZones;
  int? id;
  String remark;
  final String? sessionId;
  final int? sessionNumber;
  final String status;
  final String deviceId;
  final bool hasReport;
  final int spasmCount;
  final int alertCount;
  final int recordingCount;
  final double avgSpeed;
  final double maxSpeed;

  Duration get duration => stoppedAt.difference(startedAt);
  String get title => 'Session ${sessionNumber ?? id ?? 'Draft'}';
}

class SessionStore extends ChangeNotifier {
  SessionStore._();

  static final SessionStore instance = SessionStore._();
  final Map<String, List<SessionRecord>> _sessions = {};
  final Map<String, List<SessionRecord>> _remoteSessions = {};
  final Set<String> _loadingPatients = {};
  final Map<String, String> _errors = {};

  List<SessionRecord> forPatient(Patient patient) => List.unmodifiable([
    ...?_sessions[patient.patientId],
    ...?_remoteSessions[patient.patientId],
  ]);

  bool isLoading(Patient patient) =>
      _loadingPatients.contains(patient.patientId);

  String? errorFor(Patient patient) => _errors[patient.patientId];

  Future<void> loadForPatient(Patient patient) async {
    if (!AuthService.instance.isSignedIn) return;
    final patientId = patient.patientId;
    if (_loadingPatients.contains(patientId)) return;
    _loadingPatients.add(patientId);
    _errors.remove(patientId);
    notifyListeners();
    try {
      final items = await SessionService.instance.fetchForPatient(patientId);
      _remoteSessions[patientId] = items
          .map((item) => SessionRecord.fromJson(item, patient))
          .toList();
    } on SessionServiceException catch (e) {
      _errors[patientId] = e.message;
    } finally {
      _loadingPatients.remove(patientId);
      notifyListeners();
    }
  }

  void save(SessionRecord record) {
    final List<SessionRecord> records = _sessions.putIfAbsent(
      record.patient.patientId,
      () => [],
    );
    record.id = records.length + 1;
    records.insert(0, record);
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _sessions.clear();
    _remoteSessions.clear();
    _loadingPatients.clear();
    _errors.clear();
    notifyListeners();
  }
}
