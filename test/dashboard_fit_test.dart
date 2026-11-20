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
    testWidgets('fits at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
