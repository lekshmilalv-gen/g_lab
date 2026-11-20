import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/models/patient.dart';
import 'package:g_lab/screens/session_monitoring_screen.dart';

void main() {
  for (final Size size in const [Size(960, 600), Size(1280, 800), Size(1920, 1200)]) {
    testWidgets('session monitoring lays out at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: SessionMonitoringScreen(
          patient: Patient(patientId: '1234597', name: 'Patient Name'),
        ),
      ));
      await tester.pump(const Duration(seconds: 1)); // sensors connect
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(seconds: 2)); // stream data
      expect(find.text('Session Monitoring'), findsOneWidget);
      expect(find.text('CONNECTED'), findsNWidgets(3));
      await tester.tap(find.text('Stop'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
