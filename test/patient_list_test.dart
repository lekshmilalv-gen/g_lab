import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/models/patient.dart';
import 'package:g_lab/screens/dashboard_screen.dart';
import 'package:g_lab/screens/patient_list_screen.dart';

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _field(String hint) => find.widgetWithText(TextField, hint);

void main() {
  setUp(() {
    PatientStore.instance.fetcher = () async => [];
    PatientStore.instance.clear();
  });

  testWidgets('Dashboard Patient List button opens the empty list', (
    tester,
  ) async {
    await _setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.tap(find.text('Patient List'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientListScreen), findsOneWidget);
    expect(find.text('No patients found'), findsOneWidget);
  });

  for (final size in const [
    Size(920, 575),
    Size(1280, 800),
    Size(1920, 1080),
    Size(1024, 768),
    Size(800, 600),
  ]) {
    testWidgets('Create, list and search patients at $size', (tester) async {
      await _setSize(tester, size);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PatientListScreen())),
      );
      await tester.pump(); // finish loading patients
      expect(tester.takeException(), isNull);
      expect(find.text('No patients found'), findsOneWidget);

      // Open the side panel from the header button.
      // Only the top-right button; the empty state has no second one.
      expect(find.text('Create New Patient'), findsOneWidget);
      await tester.tap(find.text('Create New Patient'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Capture Photo'), findsOneWidget);

      // Name is required.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);

      await tester.enterText(_field('Enter Patient Name'), 'Asha Nair');
      await tester.enterText(_field('Enter Patient ID'), 'AB1478');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Panel closed and the new patient is in the grid.
      expect(find.text('Capture Photo'), findsNothing);
      expect(find.text('No patients found'), findsNothing);
      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('Patient ID : AB1478'), findsOneWidget);

      // Second patient with an auto-generated ID.
      await tester.tap(find.text('Create New Patient'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Enter Patient Name'), 'Ravi Kumar');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Patient ID : P0002'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Search filters by name or ID.
      await tester.enterText(find.widgetWithText(TextField, 'Search'), 'ravi');
      await tester.pumpAndSettle();
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Asha Nair'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching patients'), findsOneWidget);
    });
  }

  testWidgets('Duplicate patient ID is rejected; close keeps list unchanged', (
    tester,
  ) async {
    await _setSize(tester, const Size(1280, 800));
    PatientStore.instance.add(Patient(patientId: 'AB1478', name: 'Asha'));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PatientListScreen())),
    );
    await tester.pump(); // finish loading patients

    await tester.tap(find.text('Create New Patient'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Enter Patient Name'), 'Other');
    await tester.enterText(_field('Enter Patient ID'), 'ab1478');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('ID already in use'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(PatientStore.instance.patients, hasLength(1));
  });

  testWidgets('Edit icon updates an existing patient', (tester) async {
    await _setSize(tester, const Size(1280, 800));
    PatientStore.instance.add(Patient(patientId: 'AB1478', name: 'Asha'));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PatientListScreen())),
    );
    await tester.pump(); // finish loading patients

    await tester.tap(find.byTooltip('Edit patient'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Patient'), findsOneWidget);
    await tester.enterText(_field('Asha'), 'Asha Menon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Asha Menon'), findsOneWidget);
    expect(PatientStore.instance.patients, hasLength(1));
  });

  testWidgets('Phone number takes digits only, max 10, and must be 10', (
    tester,
  ) async {
    await _setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PatientListScreen())),
    );
    await tester.pump(); // finish loading patients
    await tester.tap(find.text('Create New Patient'));
    await tester.pumpAndSettle();

    final Finder phone = _field('Enter Mobile Number');
    await tester.enterText(phone, '98a76-54321099');
    await tester.pump();
    expect(tester.widget<TextField>(phone).controller!.text, '9876543210');

    await tester.enterText(_field('Enter Patient Name'), 'Asha');
    await tester.enterText(phone, '98765');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
    expect(PatientStore.instance.patients, isEmpty);

    await tester.enterText(phone, '9876543210');
    await tester.pump();
    expect(find.text('Enter a 10-digit mobile number'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(PatientStore.instance.patients.single.phone, '9876543210');
  });
}
