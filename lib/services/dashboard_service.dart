import 'api_client.dart';

/// Counts shown in the dashboard's stat cards.
class DashboardSummary {
  const DashboardSummary({
    required this.patients,
    required this.sessionsTotal,
    required this.sessionsThisWeek,
    required this.sessionsActive,
  });

  /// Parses `GET /api/dashboard/summary/`:
  /// `{"patients": 6, "sessions": {"total": 115, "this_week": 0, "active": 0}}`
  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> sessions =
        (json['sessions'] as Map<String, dynamic>?) ?? const {};
    return DashboardSummary(
      patients: _int(json['patients']),
      sessionsTotal: _int(sessions['total']),
      sessionsThisWeek: _int(sessions['this_week']),
      sessionsActive: _int(sessions['active']),
    );
  }

  final int patients;
  final int sessionsTotal;
  final int sessionsThisWeek;
  final int sessionsActive;

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class DashboardService {
  DashboardService._();

  static final DashboardService instance = DashboardService._();

  /// Loads dashboard counts from the backend.
  Future<DashboardSummary?> fetchSummary() async {
    try {
      return DashboardSummary.fromJson(
        await ApiClient.instance.getJson('/api/dashboard/summary/'),
      );
    } on Exception {
      return null;
    }
  }
}

