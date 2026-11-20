import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/models/patient.dart';

void main() {
  test('parses a patient from the patients API', () {
    final Patient p = Patient.fromJson({
      'id': 1,
      'patient_id': 'PAT001',
      'name': 'Jane Doe',
      'date_of_birth': null,
      'age': null,
      'gender': 'UNSPECIFIED',
      'phone': '',
      'email': '',
      'address': '',
      'diagnosis': '',
      'emergency_contact_name': '',
      'emergency_contact_phone': '',
      'notes': 'Test patient for API/dev testing',
      'is_active': true,
      'session_count': 92,
      'last_session_at': '2026-09-04T08:52:08.618358Z',
      'created_at': '2026-08-18T06:26:50.195416Z',
      'updated_at': '2026-10-16T05:39:36.240572Z',
    });
    expect(p.serverId, 1);
    expect(p.patientId, 'PAT001');
    expect(p.name, 'Jane Doe');
    expect(p.dob, isNull);
    expect(p.age, isNull);
    expect(p.gender, isNull);
    expect(p.remark, 'Test patient for API/dev testing');
    expect(p.isActive, isTrue);
    expect(p.sessionCount, 92);
    expect(p.lastSessionAt, isNotNull);
  });

  test('maps gender and date of birth', () {
    final Patient p = Patient.fromJson({
      'id': 17,
      'patient_id': 'DEMO005',
      'name': 'Lakshmi Varma',
      'date_of_birth': '1965-01-30',
      'gender': 'FEMALE',
    });
    expect(p.gender, 'Female');
    expect(p.dob, DateTime(1965, 1, 30));
  });
}
