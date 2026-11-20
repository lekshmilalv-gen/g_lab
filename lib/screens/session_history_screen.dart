import 'dart:io';

import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../services/session_store.dart';
import 'session_details_screen.dart';
import 'session_monitoring_screen.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  static const Color _gold = Color(0xFFE7CA55);
  static const Color _textMuted = Color(0xFF9A9587);

  @override
  void initState() {
    super.initState();
    SessionStore.instance.loadForPatient(widget.patient);
  }

  @override
  Widget build(BuildContext context) {
    final Patient patient = widget.patient;
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
              screenHeight * 0.04,
              gutter,
              screenHeight * 0.03,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────────────────────
                // LOGO + PATIENT
                // ─────────────────────────
                SizedBox(
                  height: screenHeight * 0.08,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/app_logo.png',
                        height: screenHeight * 0.08,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 16 * s),
                      // Expanded (not Spacer + Flexible) so the name block
                      // and photo sit flush against the top-right corner.
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              patient.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _fs(s, 10),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              patient.patientId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: _fs(s, 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10 * s),
                      _profilePhoto(s, screenHeight * 0.08, patient.photoPath),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.04),

                // ─────────────────────────
                // TITLE + START SESSION
                // ─────────────────────────
                SizedBox(
                  height: (screenHeight * 0.07).clamp(40.0, 64.0),
                  child: Row(
                    children: [
                      _backButton(context, s),
                      SizedBox(width: 10 * s),
                      Text(
                        'Session History',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _startSessionButton(context, s),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.03),

                // ─────────────────────────
                // SESSIONS / EMPTY STATE
                // ─────────────────────────
                Expanded(
                  child: ListenableBuilder(
                    listenable: SessionStore.instance,
                    builder: (context, _) {
                      final sessions = SessionStore.instance.forPatient(
                        patient,
                      );
                      if (sessions.isEmpty) {
                        if (SessionStore.instance.isLoading(patient)) {
                          return const Center(
                            child: CircularProgressIndicator(color: _gold),
                          );
                        }
                        final String? error = SessionStore.instance.errorFor(
                          patient,
                        );
                        if (error != null) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Could not load sessions',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _fs(s, 11),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8 * s),
                                Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: _fs(s, 8),
                                  ),
                                ),
                                SizedBox(height: 8 * s),
                                TextButton.icon(
                                  onPressed: () => SessionStore.instance
                                      .loadForPatient(patient),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _gold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No sessions found for ${patient.name}.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _fs(s, 11),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 7 * s),
                              Text(
                                'Click "Start New Session" above to start a session.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: _fs(s, 8),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return RefreshIndicator(
                        color: _gold,
                        onRefresh: () =>
                            SessionStore.instance.loadForPatient(patient),
                        child: ListView.separated(
                          padding: EdgeInsets.only(bottom: 12 * s),
                          itemCount: sessions.length,
                          separatorBuilder: (_, _) => SizedBox(height: 12 * s),
                          itemBuilder: (context, index) {
                            final record = sessions[index];
                            final date = record.stoppedAt;
                            return Container(
                              height: (76 * s).clamp(68.0, 92.0),
                              padding: EdgeInsets.symmetric(horizontal: 16 * s),
                              decoration: BoxDecoration(
                                color: const Color(0xFF24211F),
                                border: Border.all(
                                  color: const Color(0xFF3B3732),
                                ),
                                borderRadius: BorderRadius.circular(8 * s),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48 * s,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _month(date.month),
                                          style: TextStyle(
                                            color: _textMuted,
                                            fontSize: _fs(s, 8),
                                          ),
                                        ),
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _fs(s, 17),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${date.year}',
                                          style: TextStyle(
                                            color: _textMuted,
                                            fontSize: _fs(s, 7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 48 * s,
                                    child: const VerticalDivider(
                                      color: Color(0xFF615D56),
                                    ),
                                  ),
                                  SizedBox(width: 16 * s),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _fs(s, 18),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${record.status.isEmpty ? 'Session' : record.status} - ${_duration(record.duration)}',
                                          style: TextStyle(
                                            color: _textMuted,
                                            fontSize: _fs(s, 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SessionDetailsScreen(
                                          record: record,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 15,
                                    ),
                                    label: const Text('View Details'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _gold,
                                      side: const BorderSide(
                                        color: Color(0xFF6B602F),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context, double s) {
    final double size = (18 * s).clamp(36.0, 48.0);
    return InkWell(
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
    );
  }

  Widget _startSessionButton(BuildContext context, double s) {
    return SizedBox(
      height: (28 * s).clamp(48.0, 60.0),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionMonitoringScreen(patient: widget.patient),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * s),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20 * s),
        ),
        icon: Icon(Icons.play_circle_outline, size: 18 * s),
        label: Text(
          'Start New Session',
          style: TextStyle(fontSize: _fs(s, 11), fontWeight: FontWeight.w600),
        ),
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

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  String _duration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  static double _fs(double s, double base) => (base * s).clamp(9.0, 30.0);
}
