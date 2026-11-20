import '../models/doctor.dart';
import 'api_client.dart';

class DoctorService {
  DoctorService._();

  static final DoctorService instance = DoctorService._();

  Future<List<Doctor>> fetchAll() async {
    try {
      final items = await ApiClient.instance.getJsonList('/api/doctors/');
      return items
          .whereType<Map<String, dynamic>>()
          .map(Doctor.fromJson)
          .where((doctor) => doctor.isActive)
          .toList();
    } on Exception catch (e) {
      throw DoctorServiceException(e.toString());
    }
  }
}

class DoctorServiceException implements Exception {
  const DoctorServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
