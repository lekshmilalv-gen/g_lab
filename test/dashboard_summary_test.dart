import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/services/dashboard_service.dart';

void main() {
  test('parses the dashboard summary response', () {
    final DashboardSummary summary = DashboardSummary.fromJson({
      'patients': 6,
      'sessions': {'total': 115, 'this_week': 0, 'active': 0},
    });
    expect(summary.patients, 6);
    expect(summary.sessionsThisWeek, 0);
    expect(summary.sessionsTotal, 115);
    expect(summary.sessionsActive, 0);
  });
}
