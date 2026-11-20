import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../services/live_video_session.dart';
import '../services/session_store.dart';
import '../services/session_sensors.dart';
import 'session_details_screen.dart';

import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SessionMonitoringScreen extends StatefulWidget {
  const SessionMonitoringScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<SessionMonitoringScreen> createState() =>
      _SessionMonitoringScreenState();
}

class _SessionMonitoringScreenState extends State<SessionMonitoringScreen> {
  static const Color _gold = Color(0xFFE7CA55);
  static const Color _textMuted = Color(0xFF9A9587);
  static const Color _panelBg = Color(0xFF1A1813);
  static const Color _panelBorder = Color(0xFF3A352A);
  static const Color _ok = Color(0xFF2ED47A);
  static const Color _bad = Color(0xFFE5484D);

  static const List<String> _cameraViews = [
    'LEFT VIEW',
    'FRONT VIEW',
    'RIGHT VIEW',
  ];

  final SessionSensors _sensors = SessionSensors.simulated();
  late final LiveVideoSession _video;
  DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _video = LiveVideoSession();
    unawaited(_video.connect());
  }

  @override
  void dispose() {
    _sensors.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    // Same scale rule as the patient list (920 x 575 reference design).
    final double s = [
      screenWidth / 920,
      screenHeight / 575,
    ].reduce((a, b) => a < b ? a : b).clamp(0.55, 2.2);

    final double gutter = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dash_bg.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              screenHeight * 0.03,
              gutter,
              screenHeight * 0.025,
            ),
            child: ListenableBuilder(
              listenable: Listenable.merge([_sensors, _video]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(s, screenHeight),
                  SizedBox(height: screenHeight * 0.02),
                  _titleRow(s),
                  SizedBox(height: 6 * s),
                  _cameraBar(s),
                  SizedBox(height: 6 * s),
                  Expanded(child: _cameraRow(s)),
                  SizedBox(height: 10 * s),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _pressurePanel(s)),
                        SizedBox(width: 12 * s),
                        Expanded(child: _emgPanel(s)),
                      ],
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  _controls(s),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _fs(double s, double base) => (base * s).clamp(8.0, 30.0);

  // ───────────────────────────────────────────
  // Header
  // ───────────────────────────────────────────

  Widget _header(double s, double screenHeight) {
    final double height = screenHeight * 0.08;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Image.asset(
            'assets/images/app_logo.png',
            height: height,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 16 * s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fs(s, 10),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.patient.patientId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textMuted, fontSize: _fs(s, 8)),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * s),
          _profilePhoto(s, height, widget.patient.photoPath),
        ],
      ),
    );
  }

  Widget _profilePhoto(double s, double diameter, String? photoPath) {
    return Container(
      width: diameter,
      height: diameter,
      padding: EdgeInsets.all(2 * s),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_gold, Color(0xFF5A4A1E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ClipOval(
        child: photoPath == null
            ? _defaultPhoto(s)
            : Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _defaultPhoto(s),
              ),
      ),
    );
  }

  Widget _defaultPhoto(double s) => Container(
    color: _gold,
    child: Icon(Icons.person, size: 28 * s, color: const Color(0xFF2B281C)),
  );

  Widget _titleRow(double s) {
    final double size = (18 * s).clamp(36.0, 48.0);
    return Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold, width: 1.6),
            ),
            child: Icon(Icons.arrow_back, size: size * 0.55, color: _gold),
          ),
        ),
        SizedBox(width: 10 * s),
        Text(
          'Session Monitoring',
          style: TextStyle(
            color: _gold,
            fontSize: 20 * s,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_sensors.isSimulated) ...[
          SizedBox(width: 10 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4 * s),
              border: Border.all(color: _textMuted),
            ),
            child: Text(
              'SIMULATED DATA',
              style: TextStyle(
                color: _textMuted,
                fontSize: _fs(s, 6),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ───────────────────────────────────────────
  // Cameras
  // ───────────────────────────────────────────

  Widget _cameraBar(double s) {
    final bool calibrated = _sensors.calibrated;
    return Row(
      children: [
        Text(
          'Live Video Monitoring',
          style: TextStyle(
            color: Colors.white,
            fontSize: _fs(s, 8),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 10 * s),
        Text(
          '${_video.activeFeeds}/${SessionSensors.cameraCount} '
          'FEEDS ACTIVE',
          style: TextStyle(color: _textMuted, fontSize: _fs(s, 6)),
        ),
        SizedBox(width: 10 * s),
        Expanded(
          child: Text(
            _video.status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _video.hasVideo ? _ok : _textMuted,
              fontSize: _fs(s, 6),
            ),
          ),
        ),
        const Spacer(),
        _statusLabel(
          s,
          calibrated,
          okText: 'CALIBRATED',
          badText: _sensors.calibrating ? 'CALIBRATING…' : 'NOT CALIBRATED',
        ),
        SizedBox(width: 10 * s),
        SizedBox(
          height: (18 * s).clamp(32.0, 44.0),
          child: OutlinedButton.icon(
            onPressed: _sensors.calibrating ? null : _sensors.calibrate,
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              backgroundColor: const Color(0xFF2A2516),
              side: const BorderSide(color: _gold),
              padding: EdgeInsets.symmetric(horizontal: 12 * s),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8 * s),
              ),
            ),
            icon: Icon(Symbols.measuring_tape, size: 11 * s),
            label: Text(
              'Calibrate',
              style: TextStyle(
                fontSize: _fs(s, 7.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraRow(double s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < SessionSensors.cameraCount; i++) ...[
          if (i > 0) SizedBox(width: 12 * s),
          Expanded(child: _cameraTile(s, i)),
        ],
      ],
    );
  }

  Widget _cameraTile(double s, int index) {
    final RTCVideoRenderer renderer = _video.renderers[index];
    final bool connected = renderer.srcObject != null;
    final bool live = connected;

    return _panel(
      s,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: connected
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: RTCVideoView(
                          renderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: false,
                        ),
                      ),
                      Positioned(
                        top: 6 * s,
                        left: 6 * s,
                        child: _feedChip(
                          s,
                          live ? 'LIVE' : 'WAITING',
                          live ? _ok : _textMuted,
                        ),
                      ),
                      Positioned(
                        top: 6 * s,
                        right: 6 * s,
                        child: _feedChip(
                          s,
                          connected && renderer.videoWidth > 0
                              ? '${renderer.videoWidth}×${renderer.videoHeight}'
                              : 'JETSON',
                          null,
                        ),
                      ),
                      Positioned(
                        bottom: 4 * s,
                        left: 0,
                        right: 0,
                        child: Icon(
                          Icons.fullscreen,
                          size: 12 * s,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  )
                : Container(
                    color: const Color(0xFF12100C),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_off_outlined,
                          size: 22 * s,
                          color: _textMuted,
                        ),
                        SizedBox(height: 4 * s),
                        Text(
                          'No signal',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: _fs(s, 7),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 4 * s),
            color: const Color(0xFF14120E),
            child: Row(
              children: [
                Icon(Icons.videocam_outlined, size: 10 * s, color: _gold),
                SizedBox(width: 4 * s),
                Text(
                  'Camera ${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fs(s, 6.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4 * s),
                Flexible(
                  child: Text(
                    _cameraViews[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textMuted, fontSize: _fs(s, 5.5)),
                  ),
                ),
                const Spacer(),
                _statusLabel(s, connected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedChip(double s, String text, Color? dot) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 2 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3 * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 4 * s,
              height: 4 * s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
            SizedBox(width: 3 * s),
          ],
          Text(
            text,
            style: TextStyle(
              color: dot ?? _textMuted,
              fontSize: _fs(s, 5.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  // Pressure insole
  // ───────────────────────────────────────────

  Widget _pressurePanel(double s) {
    final bool connected = _sensors.insoleConnected;
    return _panel(
      s,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(
            s,
            Icons.multiline_chart,
            'Pressure Insole',
            _statusLabel(
              s,
              connected,
              okText: 'SENSOR CONNECTED',
              badText: 'SENSOR NOT CONNECTED',
            ),
          ),
          SizedBox(height: 6 * s),
          Expanded(
            child: connected
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/foot_print.png',
                              fit: BoxFit.contain,
                            ),
                            CustomPaint(
                              painter: _InsolePainter(
                                left: _sensors.leftZones,
                                right: _sensors.rightZones,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Expanded(
                              child: _loadCard(
                                s,
                                'LEFT FOOT',
                                _sensors.leftFootKpa,
                                _gold,
                              ),
                            ),
                            SizedBox(height: 5 * s),
                            Expanded(
                              child: _loadCard(
                                s,
                                'RIGHT FOOT',
                                _sensors.rightFootKpa,
                                const Color(0xFF3FC7C1),
                              ),
                            ),
                            SizedBox(height: 5 * s),
                            Expanded(
                              child: _loadCard(
                                s,
                                'TOTAL LOAD',
                                _sensors.totalLoadKpa,
                                _ok,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _noSensor(s, 'Connect the pressure insoles to see readings.'),
          ),
        ],
      ),
    );
  }

  Widget _loadCard(double s, String label, double kpa, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2823),
        borderRadius: BorderRadius.circular(6 * s),
        border: Border.all(color: _panelBorder),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(3 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(color: _textMuted, fontSize: _fs(s, 5.5)),
              ),
              Text(
                _sensors.running || kpa > 0 ? kpa.toStringAsFixed(0) : '--',
                style: TextStyle(
                  color: color,
                  fontSize: _fs(s, 10),
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                'kPa',
                style: TextStyle(color: _textMuted, fontSize: _fs(s, 5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  // EMG
  // ───────────────────────────────────────────

  Widget _emgPanel(double s) {
    final bool connected = _sensors.emgConnected;
    return _panel(
      s,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(
            s,
            Icons.wb_sunny_outlined,
            'EMG Monitoring',
            _statusLabel(
              s,
              connected,
              okText: 'SENSOR CONNECTED',
              badText: 'SENSOR NOT CONNECTED',
            ),
          ),
          SizedBox(height: 6 * s),
          Expanded(
            child: connected
                ? CustomPaint(
                    painter: _EmgPainter(
                      samples: List<double>.of(_sensors.emgSamples),
                      window: SessionSensors.emgWindow,
                    ),
                    child: _sensors.emgSamples.isEmpty
                        ? Center(
                            child: Text(
                              'Press Start to begin recording.',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: _fs(s, 7),
                              ),
                            ),
                          )
                        : null,
                  )
                : _noSensor(s, 'Connect the EMG sensor to see the signal.'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  // Shared panel pieces
  // ───────────────────────────────────────────

  Widget _panel(double s, {required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? EdgeInsets.all(8 * s),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panelBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8 * s),
        border: Border.all(color: _panelBorder),
      ),
      child: child,
    );
  }

  Widget _panelHeader(double s, IconData icon, String title, Widget status) {
    return Row(
      children: [
        Icon(icon, size: 11 * s, color: _gold),
        SizedBox(width: 5 * s),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: _fs(s, 7.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        status,
      ],
    );
  }

  Widget _statusLabel(
    double s,
    bool ok, {
    String okText = 'CONNECTED',
    String badText = 'NOT CONNECTED',
  }) {
    final Color color = ok ? _ok : _bad;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5 * s,
          height: 5 * s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: 3 * s),
        Text(
          ok ? okText : badText,
          style: TextStyle(
            color: color,
            fontSize: _fs(s, 5.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _noSensor(double s, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off_outlined, size: 22 * s, color: _textMuted),
          SizedBox(height: 4 * s),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted, fontSize: _fs(s, 7)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  // Bottom controls
  // ───────────────────────────────────────────

  Widget _controls(double s) {
    final bool running = _sensors.running;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          s,
          icon: Icons.home,
          label: 'Home',
          onTap: () async {
            _sensors.stop();
            await _video.stopSession();
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        SizedBox(width: 24 * s),
        _controlButton(
          s,
          icon: Icons.replay,
          label: 'Repose',
          onTap: () async {
            if (_sensors.running) await _video.stopSession();
            _sensors.repose();
            _startedAt = DateTime.now();
          },
        ),
        SizedBox(width: 24 * s),
        _controlButton(
          s,
          icon: Icons.stop,
          label: 'Stop',
          onTap: running ? _confirmStop : null,
        ),
        SizedBox(width: 24 * s),
        _controlButton(
          s,
          icon: Icons.play_arrow,
          label: 'Start',
          filled: true,
          onTap: running ? null : _startMonitoring,
        ),
      ],
    );
  }

  Future<void> _startMonitoring() async {
    _startedAt = DateTime.now();
    try {
      await _video.startSession(widget.patient.patientId);
      if (!mounted) return;
      _sensors.start();
    } on Object {
      // The video service publishes a readable connection error in the UI.
    }
  }

  Future<void> _confirmStop() async {
    final String? choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final Size screenSize = MediaQuery.sizeOf(dialogContext);
        final double dialogWidth = min(600, screenSize.width - 24);
        final double dialogHeight = min(300, screenSize.height - 32);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/popup_screen.png'),
                  fit: BoxFit.fill,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double scale = min(
                    constraints.maxWidth / 600,
                    constraints.maxHeight / 300,
                  ).clamp(0.5, 1.0);
                  return Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          38 * scale,
                          22 * scale,
                          38 * scale,
                          24 * scale,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: 16 * scale),
                            Container(
                              width: 38 * scale,
                              height: 38 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF211D12),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.65),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _gold.withValues(alpha: 0.12),
                                    blurRadius: 14 * scale,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.stop_circle_outlined,
                                size: 23 * scale,
                                color: _gold,
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * scale,
                                vertical: 5 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x33251F0B),
                                borderRadius: BorderRadius.circular(20 * scale),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6 * scale,
                                    height: 6 * scale,
                                    decoration: const BoxDecoration(
                                      color: _gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6 * scale),
                                  Text(
                                    'SESSION CONTROL',
                                    style: TextStyle(
                                      color: _gold,
                                      fontSize: 9 * scale,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1 * scale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10 * scale),
                            Text(
                              'End this session?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23 * scale,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2 * scale,
                              ),
                            ),
                            SizedBox(height: 6 * scale),
                            Text(
                              'Are you sure you want to stop monitoring?\nYour session data will be saved.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFFD0CBBE),
                                fontSize: 13 * scale,
                                height: 1.45,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: 12,
                                  child: _sessionDialogButton(
                                    label: 'Restart',
                                    filled: true,
                                    scale: scale,
                                    onPressed: () => Navigator.pop(dialogContext, 'restart'),
                                  ),
                                ),
                                SizedBox(width: 16 * scale),
                                Flexible(
                                  flex: 12,
                                  child: _sessionDialogButton(
                                    label: 'Discard',
                                    scale: scale,
                                    outlined: true,
                                    onPressed: () => Navigator.pop(dialogContext, 'discard'),
                                  ),
                                ),
                                SizedBox(width: 16 * scale),
                                Flexible(
                                  flex: 9,
                                  child: _sessionDialogButton(
                                    label: 'Ok',
                                    scale: scale,
                                    onPressed: () => Navigator.pop(dialogContext, 'ok'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12 * scale,
                        right: 14 * scale,
                        child: _sessionDialogCloseButton(
                          scale,
                          () => Navigator.pop(dialogContext),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'restart') {
      await _video.stopSession();
      _sensors.repose();
      _startedAt = DateTime.now();
      await _startMonitoring();
    } else if (choice == 'discard') {
      _sensors.stop();
      await _video.stopSession();
      Navigator.of(context).pop();
    } else {
      _sensors.stop();
      await _video.stopSession();
      final SessionRecord draft = SessionRecord(
        patient: widget.patient,
        startedAt: _startedAt,
        stoppedAt: DateTime.now(),
        frames: _sensors.frameCount,
        leftPressure: _sensors.leftFootKpa,
        rightPressure: _sensors.rightFootKpa,
        leftZones: List<double>.of(_sensors.leftZones),
        rightZones: List<double>.of(_sensors.rightZones),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailsScreen(record: draft, isDraft: true),
        ),
      );
    }
  }

  Widget _sessionDialogButton({
    required String label,
    required double scale,
    required VoidCallback onPressed,
    bool filled = false,
    bool outlined = false,
  }) {
    return SizedBox(
      height: 48 * scale,
      child: Material(
        color: filled ? _gold : Colors.black,
        shape: StadiumBorder(
          side: BorderSide(color: outlined ? _gold : Colors.transparent, width: 1.5 * scale),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : _gold,
                fontSize: 15 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionDialogCloseButton(double scale, VoidCallback onPressed) {
    return Material(
      color: const Color(0xFF252323),
      shape: const CircleBorder(side: BorderSide(color: _gold, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 50 * scale,
          height: 50 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 12 * scale,
          ),
        ],
      ),
          child: Center(
            child: Icon(Icons.close, color: _gold, size: 27 * scale),
          ),
        ),
      ),
    );
  }

  Widget _controlButton(
    double s, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final double height = (22 * s).clamp(44.0, 56.0);
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: filled ? _gold : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: _gold, width: 1.4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            width: (72 * s).clamp(130.0, 180.0),
            child: Padding(
              padding: EdgeInsets.all(4 * s),
              child: Row(
                children: [
                  Container(
                    width: height - 8 * s,
                    height: height - 8 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Colors.black : _gold,
                    ),
                    child: Icon(
                      icon,
                      size: height * 0.45,
                      color: filled ? _gold : Colors.black,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: filled ? Colors.black : _gold,
                        fontSize: _fs(s, 10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two insoles with a coloured circle per pressure zone.
class _InsolePainter extends CustomPainter {
  _InsolePainter({required this.left, required this.right});

  final List<double> left;
  final List<double> right;

  // Zone centres (x, y) and radius, as fractions of the foot box, for the
  // left foot. The right foot is mirrored.
  static const Map<InsoleZone, (double, double, double)> _layout = {
    InsoleZone.toe: (0.42, 0.11, 0.09),
    InsoleZone.ball: (0.42, 0.32, 0.13),
    InsoleZone.lateral: (0.72, 0.42, 0.08),
    InsoleZone.midfoot: (0.45, 0.58, 0.08),
    InsoleZone.heel: (0.48, 0.82, 0.14),
  };

  @override
  void paint(Canvas canvas, Size size) {
    // The footprint asset is 190x220; place pressure zones in the same
    // centered contain box used by Image.asset.
    final double imageScale = min(size.width / 190, size.height / 220);
    final double imageW = 190 * imageScale;
    final double imageH = 220 * imageScale;
    final double imageLeft = (size.width - imageW) / 2;
    final double imageTop = (size.height - imageH) / 2;
    final double footW = imageW * 0.5;
    final double footH = imageH;
    final double startX = imageLeft;

    _paintFoot(canvas, Rect.fromLTWH(startX, imageTop, footW, footH), left, false);
    _paintFoot(
      canvas,
      Rect.fromLTWH(startX + footW, imageTop, footW, footH),
      right,
      true,
    );
  }

  void _paintFoot(Canvas canvas, Rect box, List<double> zones, bool mirror) {
    double fx(double x) => box.left + box.width * (mirror ? 1 - x : x);
    double fy(double y) => box.top + box.height * y;

    for (final InsoleZone zone in InsoleZone.values) {
      final (double x, double y, double r) = _layout[zone]!;
      final double load = zones.isEmpty ? 0 : zones[zone.index];
      canvas.drawCircle(
        Offset(fx(x), fy(y)),
        box.width * r * 1.1,
        Paint()..color = _heat(load),
      );
    }
  }

  /// Low → high load: purple, teal, gold.
  static Color _heat(double t) {
    const Color low = Color(0xFF7B6AA8);
    const Color mid = Color(0xFF3FC7C1);
    const Color high = Color(0xFFD9B640);
    if (t <= 0) return const Color(0xFF4A473F);
    return t < 0.5
        ? Color.lerp(low, mid, t * 2)!
        : Color.lerp(mid, high, (t - 0.5) * 2)!;
  }

  @override
  bool shouldRepaint(_InsolePainter oldDelegate) =>
      oldDelegate.left != left || oldDelegate.right != right;
}

/// Scrolling EMG trace with horizontal guide lines.
class _EmgPainter extends CustomPainter {
  _EmgPainter({required this.samples, required this.window});

  final List<double> samples;
  final int window;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint guide = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (final double f in [0.2, 0.5, 0.8]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        guide,
      );
    }
    if (samples.length < 2) return;

    final double dx = size.width / (window - 1);
    final double startX = size.width - dx * (samples.length - 1);
    final double mid = size.height / 2;
    final double amp = size.height * 0.45;

    final Path path = Path()..moveTo(startX, mid - samples.first * amp);
    for (int i = 1; i < samples.length; i++) {
      path.lineTo(startX + dx * i, mid - samples[i] * amp);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55E7CA55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE7CA55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_EmgPainter oldDelegate) => true;
}
