import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/screens/dashboard_screen.dart';

const _step1 = 'In the dashboard screen shows the Device activity';
const _patientList = 'The dashboard will have a Patient List button.';
const _step4 = "Clicking on a patient's profile will open the Session List";

void main() {
  for (final size in const [
    Size(920, 575),
    Size(1280, 800),
    Size(1920, 1080),
    Size(1024, 768),
    Size(800, 600),
  ]) {
    testWidgets('Walkthrough steps through all tips at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> next() async {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.tap(find.text('Walkthrough'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining(_step1), findsOneWidget);

      // Steps 2 and 3 share the Patient List text, at different positions.
      await next();
      expect(find.textContaining(_step1), findsNothing);
      expect(find.textContaining(_patientList), findsOneWidget);
      final Offset step2Pos = tester.getTopLeft(
        find.textContaining(_patientList),
      );

      await next();
      expect(find.textContaining(_patientList), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining(_patientList)).dx,
        greaterThan(step2Pos.dx),
      );

      await next();
      expect(find.textContaining(_patientList), findsNothing);
      expect(find.textContaining(_step4), findsOneWidget);

      // Next on the last tip closes the walkthrough.
      await next();
      expect(find.textContaining(_step4), findsNothing);
    });
  }

  testWidgets('Skip closes the walkthrough', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.tap(find.text('Walkthrough'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_step1), findsNothing);
  });
}
