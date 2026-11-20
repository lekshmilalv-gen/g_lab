import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Connection state and live readings for one monitoring session: three
/// cameras, the pressure insoles and the EMG sensor.
///
/// Screens only read from this class and call [start], [stop], [repose] and
/// [calibrate]. The real device drivers should update the same fields and
/// call [notifyListeners]; until they exist, [SessionSensors.simulated]
/// produces demo data so the UI can be exercised.
class SessionSensors extends ChangeNotifier {
  SessionSensors._({required this.isSimulated});

  /// Demo data source. Devices "connect" shortly after the screen opens and
  /// readings stream while the session is running.
  factory SessionSensors.simulated() {
    final SessionSensors sensors = SessionSensors._(isSimulated: true);
    sensors._connectTimer = Timer(const Duration(milliseconds: 900), () {
      sensors
        ..cameraConnected = [true, true, true]
        ..insoleConnected = true
        ..emgConnected = true;
      sensors.notifyListeners();
    });
    return sensors;
  }

  static const int cameraCount = 3;

  /// Number of EMG samples kept for the graph.
  static const int emgWindow = 240;

  final bool isSimulated;

  List<bool> cameraConnected = List<bool>.filled(cameraCount, false);
  bool insoleConnected = false;
  bool emgConnected = false;

  bool calibrated = false;
  bool calibrating = false;
  bool running = false;

  /// Frames received per camera since the session started.
  int frameCount = 0;
  int fps = 0;

  /// Average plantar pressure per foot, in kPa.
  double leftFootKpa = 0;
  double rightFootKpa = 0;
  double get totalLoadKpa => leftFootKpa + rightFootKpa;

  /// Relative load (0–1) of each insole zone, ordered as [InsoleZone.values].
  List<double> leftZones = List<double>.filled(InsoleZone.values.length, 0);
  List<double> rightZones = List<double>.filled(InsoleZone.values.length, 0);

  /// Normalised EMG samples in the range -1…1, oldest first.
  final List<double> emgSamples = [];

  int get camerasOnline => cameraConnected.where((c) => c).length;

  final Random _rng = Random();
  Timer? _connectTimer;
  Timer? _streamTimer;
  Timer? _calibrateTimer;
  int _tick = 0;
  int _burst = 0;

  void start() {
    if (running) return;
    running = true;
    fps = 30;
    _streamTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _simulateTick(),
    );
    notifyListeners();
  }

  void stop() {
    if (!running) return;
    running = false;
    fps = 0;
    _streamTimer?.cancel();
    notifyListeners();
  }

  /// Puts the patient back into the neutral pose: clears the recorded
  /// readings so the next capture starts fresh.
  void repose() {
    stop();
    frameCount = 0;
    leftFootKpa = 0;
    rightFootKpa = 0;
    leftZones = List<double>.filled(InsoleZone.values.length, 0);
    rightZones = List<double>.filled(InsoleZone.values.length, 0);
    emgSamples.clear();
    notifyListeners();
  }

  void calibrate() {
    if (calibrating) return;
    calibrating = true;
    notifyListeners();
    _calibrateTimer = Timer(const Duration(milliseconds: 1500), () {
      calibrating = false;
      calibrated = true;
      notifyListeners();
    });
  }

  void _simulateTick() {
    _tick++;
    frameCount++;

    if (emgConnected) {
      // Background noise with occasional muscle-activation bursts.
      if (_burst == 0 && _rng.nextDouble() < 0.02) _burst = 12;
      final double amp = _burst > 0 ? 0.95 : 0.45;
      if (_burst > 0) _burst--;
      emgSamples.add(((_rng.nextDouble() * 2 - 1) * amp).clamp(-1.0, 1.0));
      if (emgSamples.length > emgWindow) emgSamples.removeAt(0);
    }

    if (insoleConnected && _tick % 10 == 0) {
      // Slow weight shift from one foot to the other.
      final double shift = sin(_tick / 60);
      leftFootKpa = 58 + shift * 6 + _rng.nextDouble() * 2;
      rightFootKpa = 58 - shift * 6 + _rng.nextDouble() * 2;
      leftZones = _zones(0.5 + shift * 0.2);
      rightZones = _zones(0.5 - shift * 0.2);
    }

    notifyListeners();
  }

  List<double> _zones(double load) => [
    for (final InsoleZone zone in InsoleZone.values)
      (zone.baseLoad * load * 2 + _rng.nextDouble() * 0.08).clamp(0.0, 1.0),
  ];

  @override
  void dispose() {
    _connectTimer?.cancel();
    _streamTimer?.cancel();
    _calibrateTimer?.cancel();
    super.dispose();
  }
}

/// Pressure zones on each insole.
enum InsoleZone {
  toe(0.25),
  ball(0.55),
  lateral(0.45),
  midfoot(0.35),
  heel(0.85);

  const InsoleZone(this.baseLoad);

  /// Typical share of load while standing, used by the simulator.
  final double baseLoad;
}
