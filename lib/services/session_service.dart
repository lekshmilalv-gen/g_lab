import 'api_client.dart';

class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  Future<List<Map<String, dynamic>>> fetchForPatient(String patientId) async {
    try {
      final items = await ApiClient.instance.getJsonList(
        '/api/patients/${Uri.encodeComponent(patientId)}/sessions/',
      );
      return items.whereType<Map<String, dynamic>>().toList();
    } on Exception catch (e) {
      throw SessionServiceException(e.toString());
    }
  }
}

class SessionServiceException implements Exception {
  const SessionServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
