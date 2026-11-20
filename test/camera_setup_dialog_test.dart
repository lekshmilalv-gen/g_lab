import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/screens/dashboard_screen.dart';

void main() {
  for (final size in const [
    Size(920, 575),
    Size(1280, 800),
    Size(1920, 1080),
    Size(1024, 768),
    Size(800, 600),
  ]) {
    testWidgets('Acknowledge opens camera check popup at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CAMERA SETUP CHECK'), findsOneWidget);

      // Cancel fades the popup away.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('CAMERA SETUP CHECK'), findsNothing);
    });
  }

  testWidgets('Continue is enabled only after confirming', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();

    // Disabled before the box is ticked: tapping does nothing.
    await tester.tap(find.text('Acknowledge & continue'));
    await tester.pumpAndSettle();
    expect(find.text('CAMERA SETUP CHECK'), findsOneWidget);

    await tester.tap(
      find.text('I confirm that all cameras are correctly positioned'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acknowledge & continue'));
    await tester.pumpAndSettle();
    expect(find.text('CAMERA SETUP CHECK'), findsNothing);
  });
}
