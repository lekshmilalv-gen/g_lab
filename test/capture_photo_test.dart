import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_lab/models/patient.dart';
import 'package:g_lab/screens/patient_list_screen.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stands in for the device camera.
class _FakeCamera extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  _FakeCamera({this.path, this.error});

  final String? path;
  final PlatformException? error;
  ImageSource? lastSource;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    lastSource = source;
    if (error != null) throw error!;
    return path == null ? null : XFile(path!);
  }
}

Finder _field(String hint) => find.widgetWithText(TextField, hint);

void main() {
  late File photo;

  setUpAll(() {
    // A real 1x1 PNG so Image.file can load it.
    photo = File('${Directory.systemTemp.path}/g_lab_test_photo.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYA'
          'AjCB0C8AAAAASUVORK5CYII=',
        ),
      );
  });

  setUp(() {
    PatientStore.instance.fetcher = () async => [];
    PatientStore.instance.clear();
  });

  Future<void> openPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PatientListScreen())),
    );
    await tester.tap(find.text('Create New Patient'));
    await tester.pumpAndSettle();
  }

  testWidgets('Capture Photo opens the camera and saves the photo', (
    tester,
  ) async {
    final camera = _FakeCamera(path: photo.path);
    ImagePickerPlatform.instance = camera;
    await openPanel(tester);

    await tester.tap(find.text('Capture Photo'));
    await tester.pumpAndSettle();

    expect(camera.lastSource, ImageSource.camera);
    expect(find.text('Tap to retake'), findsOneWidget);

    await tester.enterText(_field('Enter Patient Name'), 'Asha Nair');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(PatientStore.instance.patients.single.photoPath, photo.path);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelling the camera keeps the placeholder', (tester) async {
    ImagePickerPlatform.instance = _FakeCamera();
    await openPanel(tester);

    await tester.tap(find.text('Capture Photo'));
    await tester.pumpAndSettle();

    expect(find.text('Capture Photo'), findsOneWidget);
  });

  testWidgets('Denied camera permission shows a message', (tester) async {
    ImagePickerPlatform.instance = _FakeCamera(
      error: PlatformException(code: 'camera_access_denied'),
    );
    await openPanel(tester);

    await tester.tap(find.text('Capture Photo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Camera permission denied. Allow it in Settings.'),
      findsOneWidget,
    );
  });
}
