import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import 'login_screen.dart';
import 'patient_list_screen.dart';
import '../widgets/camera_setup_dialog.dart';
import '../widgets/walkthrough_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.summary});

  /// Counts from `/api/dashboard/summary/`; null if they could not be loaded.
  final DashboardSummary? summary;

  static const Color _gold = Color(0xFFE7CA55);
  static const Color _goldMuted = Color(0xFFA38B45);
  static const Color _panelBg = Color(0xFF1A1813);
  static const Color _panelInner = Color(0xFF0F0E0B);
  static const Color _border = Color(0xFF3A352A);
  static const Color _textMuted = Color(0xFF9A9A9A);

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // Text/icon scale relative to the 920 x 575 reference design, limited by
    // whichever dimension is tighter so everything still fits on screen.
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
              screenHeight * 0.04,
              gutter,
              screenHeight * 0.03,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────────────────────
                // HEADER: logo + logout
                // ─────────────────────────
                SizedBox(
                  height: screenHeight * 0.08,
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/app_logo.png',
                        height: screenHeight * 0.08,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        child: Image.asset(
                          'assets/images/shutdown_icon.png',
                          height: screenHeight * 0.075,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.025),

                // ─────────────────────────
                // TITLE + ACTIONS (one row)
                // ─────────────────────────
                SizedBox(
                  // Never smaller than a comfortable tap target.
                  height: (screenHeight * 0.07).clamp(40.0, 64.0),
                  child: Row(
                    children: [
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w700,
                          color: _gold,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      _walkthroughButton(context, s),
                      SizedBox(width: 12 * s),
                      _patientListButton(context, s),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.02),

                // Stat cards and live panels share the remaining height.
                Expanded(flex: 19, child: _buildStatCards(s)),

                SizedBox(height: screenHeight * 0.015),

                Expanded(
                  flex: 32,
                  child: _buildPanels(context, s, screenWidth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Scaled font size that never drops below 9px, so text stays readable.
  static double _fs(double s, double base) {
    final double size = base * s;
    return size < 9 ? 9 : size;
  }

  // ───────────────────────────────────────────
  // Header buttons
  // ───────────────────────────────────────────

  Widget _walkthroughButton(BuildContext context, double s) {
    return OutlinedButton(
      onPressed: () => showWalkthrough(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: _gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * s),
        ),
        side: const BorderSide(color: _gold, width: 1.2),
        padding: EdgeInsets.symmetric(horizontal: 22 * s),
      ),
      child: Text(
        'Walkthrough',
        style: TextStyle(fontSize: _fs(s, 10.5), fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _patientListButton(BuildContext context, double s) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PatientListScreen())),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * s),
        ),
        padding: EdgeInsets.symmetric(horizontal: 22 * s),
      ),
      icon: Image.asset('assets/images/patientlist_icon.png', width: 14 * s),
      label: Text(
        'Patient List',
        style: TextStyle(fontSize: _fs(s, 10.5), fontWeight: FontWeight.w600),
      ),
    );
  }

  // ───────────────────────────────────────────
  // Stat cards
  // ───────────────────────────────────────────

  Widget _buildStatCards(double s) {
    final List<(String, String)> cards = [
      ('TOTAL MONITORED PATIENTS', '${summary?.patients ?? '--'}'),
      ('SESSION TRACKED THIS WEEK', '${summary?.sessionsThisWeek ?? '--'}'),
      ('COMPLETED GAIT REPORT', '42'),
      ('SENSOR DIAGNOSIS', '42'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, value) in cards)
          Expanded(
            child: _statCard(s, title: title, value: value),
          ),
      ],
    );
  }

  Widget _statCard(double s, {required String title, required String value}) {
    // card_img.png includes a soft drop shadow in its transparent margins
    // (~4% each side, ~14% bottom), so the content is padded to sit inside
    // the visible card.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        return Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/card_img.png'),
              fit: BoxFit.fill,
            ),
          ),
          padding: EdgeInsets.fromLTRB(w * 0.1, h * 0.1, w * 0.1, h * 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: _fs(s, 8),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                        color: _textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  _iconBadge(s, Icons.dashboard_customize_outlined),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 30 * s,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconBadge(double s, IconData icon) {
    return Container(
      width: 16 * s,
      height: 16 * s,
      decoration: BoxDecoration(
        color: const Color(0xFF2A261C),
        borderRadius: BorderRadius.circular(4 * s),
        border: Border.all(color: _goldMuted.withValues(alpha: 0.6)),
      ),
      child: Icon(icon, size: 10 * s, color: _gold),
    );
  }

  // ───────────────────────────────────────────
  // Live panels
  // ───────────────────────────────────────────

  Widget _buildPanels(BuildContext context, double s, double screenWidth) {
    final double gap = screenWidth * 0.012;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.004),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 37, child: _videoStatusPanel(context, s)),
          SizedBox(width: gap),
          Expanded(flex: 24, child: _pressurePanel(s)),
          SizedBox(width: gap),
          Expanded(flex: 24, child: _emgPanel(s)),
        ],
      ),
    );
  }

  Widget _panel(
    double s, {
    required IconData icon,
    required String title,
    required List<Widget> badges,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        color: _panelBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8 * s),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            // Tall enough for the Acknowledge button's tap target.
            height: (28 * s).clamp(36.0, 60.0),
            child: Row(
              children: [
                Icon(icon, size: 14 * s, color: _gold),
                SizedBox(width: 6 * s),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _fs(s, 11),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 6 * s),
                // Badges shrink (never overflow) when the panel is narrow.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < badges.length; i++) ...[
                          if (i > 0) SizedBox(width: 6 * s),
                          badges[i],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * s),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _statusPill(double s, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3 * s),
      decoration: BoxDecoration(
        color: _panelInner,
        borderRadius: BorderRadius.circular(20 * s),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(s, 5),
          SizedBox(width: 5 * s),
          Text(
            text,
            style: TextStyle(
              fontSize: _fs(s, 8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double s, double size) {
    return Container(
      width: size * s,
      height: size * s,
      decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
    );
  }

  Widget _footerBar(
    double s, {
    required String label,
    required Widget trailing,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF24211A),
        borderRadius: BorderRadius.circular(5 * s),
      ),
      // Label and value sit side by side; on narrow panels the value wraps
      // onto a second line instead of shrinking the text.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6 * s,
        runSpacing: 3 * s,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: _fs(s, 8), color: _textMuted),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _acknowledgeButton(BuildContext context, double s) {
    return ElevatedButton(
      onPressed: () => showCameraSetupDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: Size(0, (26 * s).clamp(34.0, 54.0)),
        padding: EdgeInsets.symmetric(horizontal: 20 * s),
        shape: const StadiumBorder(),
      ),
      child: Text(
        'Acknowledge',
        style: TextStyle(fontSize: _fs(s, 9.5), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _videoStatusPanel(BuildContext context, double s) {
    return _panel(
      s,
      icon: Icons.videocam_outlined,
      title: '3-Live Video Status',
      badges: [
        _acknowledgeButton(context, s),
        _statusPill(s, 'ONLINE · 30 FPS'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cameraTile(s, 'LEFT', 'C1: Connected')),
                SizedBox(width: 8 * s),
                Expanded(child: _cameraTile(s, 'FRONT', 'C2: Connected')),
                SizedBox(width: 8 * s),
                Expanded(child: _cameraTile(s, 'RIGHT', 'C3: Connected')),
              ],
            ),
          ),
          SizedBox(height: 8 * s),
          _footerBar(
            s,
            label: 'All three Camera Connection Status is Good',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 10 * s, color: _gold),
                SizedBox(width: 3 * s),
                Text(
                  'PASS',
                  style: TextStyle(
                    fontSize: _fs(s, 8.5),
                    fontWeight: FontWeight.w600,
                    color: _gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraTile(double s, String label, String status) {
    return Container(
      padding: EdgeInsets.all(7 * s),
      decoration: BoxDecoration(
        color: _panelInner,
        borderRadius: BorderRadius.circular(6 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video area — takes whatever height the panel has left.
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(s, 5),
                  SizedBox(width: 4 * s),
                  Text(
                    'LIVE',
                    style: TextStyle(fontSize: _fs(s, 8), color: _textMuted),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _fs(s, 8.5),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * s,
                  vertical: 1.5 * s,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(6 * s),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontSize: _fs(s, 7.5),
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * s),
          Text(
            status,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _fs(s, 8), color: _gold),
          ),
        ],
      ),
    );
  }

  Widget _pressurePanel(double s) {
    return _panel(
      s,
      icon: Icons.wb_sunny_outlined,
      title: 'Pressure Sensor',
      badges: [_statusPill(s, 'CONNECTED · 100 Hz')],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(7 * s),
              decoration: BoxDecoration(
                color: _panelInner,
                borderRadius: BorderRadius.circular(5 * s),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  // Pads follow the box height but never take more than
                  // ~20% of its width each, leaving room for the text.
                  final double padH = box.maxHeight * 0.8;
                  final double padW = (padH * 0.55).clamp(
                    0.0,
                    box.maxWidth * 0.2,
                  );
                  return Row(
                    children: [
                      _footPad(s, 'LEFT', padW, padH),
                      SizedBox(width: 5 * s),
                      _footPad(s, 'RIGHT', padW, padH),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEFT',
                              style: TextStyle(
                                fontSize: _fs(s, 10),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4 * s),
                            Row(
                              children: [
                                Icon(Icons.check, size: 10 * s, color: _gold),
                                SizedBox(width: 2 * s),
                                Flexible(
                                  child: Text(
                                    'Zero-Point Calibrated',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: _fs(s, 8.5),
                                      color: _gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6 * s),
                            Text(
                              'Corridor gait plate ready for dynamic strikes',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _fs(s, 8),
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 8 * s),
          _footerBar(
            s,
            label: 'Dynamic Range Calibration',
            trailing: Text(
              '0 – 1200 kPa (READY)',
              style: TextStyle(
                fontSize: _fs(s, 8),
                fontWeight: FontWeight.w600,
                color: _gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footPad(double s, String label, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2310),
          borderRadius: BorderRadius.circular(20 * s),
          border: Border.all(color: _gold),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 2 * s),
          child: FittedBox(
            child: Text(
              label,
              style: TextStyle(
                fontSize: _fs(s, 8),
                fontWeight: FontWeight.w600,
                color: _gold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emgPanel(double s) {
    return _panel(
      s,
      icon: Icons.wb_sunny_outlined,
      title: 'EMG Value',
      badges: [_statusPill(s, 'Live')],
      child: Center(
        child: FittedBox(
          child: Text(
            '345',
            style: TextStyle(
              fontSize: 44 * s,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
