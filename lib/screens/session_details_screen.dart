import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/session_store.dart';

class SessionDetailsScreen extends StatefulWidget {
  const SessionDetailsScreen({
    super.key,
    required this.record,
    this.isDraft = false,
  });

  final SessionRecord record;
  final bool isDraft;

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  static const _gold = Color(0xFFE7CA55);
  static const _muted = Color(0xFF9A9587);

  Future<void> _editRemark() async {
    final value = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _RemarkDialog(initialRemark: widget.record.remark),
    );
    if (!mounted || value == null) return;
    setState(() => widget.record.remark = value);
  }

  void _saveSession() {
    if (widget.isDraft) SessionStore.instance.save(widget.record);
    Navigator.of(context).pop();
    if (widget.isDraft && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.record.patient;
    final s = min(
      MediaQuery.sizeOf(context).width / 920,
      MediaQuery.sizeOf(context).height / 575,
    ).clamp(0.65, 1.4);
    return Scaffold(
      backgroundColor: const Color(0xFF100D09),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dash_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        28 * s,
                        18 * s,
                        28 * s,
                        16 * s,
                      ),
                      sliver: SliverList.list(
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/app_logo.png',
                                height: 54 * s,
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    patient.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10 * s,
                                    ),
                                  ),
                                  Text(
                                    patient.patientId,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 8 * s,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              _photo(patient.photoPath, 42 * s),
                            ],
                          ),
                          SizedBox(height: 22 * s),
                          Row(
                            children: [
                              _backButton(s),
                              SizedBox(width: 10 * s),
                              Text(
                                'Session Details',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 22 * s,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                height: (28 * s).clamp(48.0, 60.0),
                                child: ElevatedButton.icon(
                                  onPressed: _editRemark,
                                  icon: Icon(Icons.edit_note, size: 18 * s),
                                  label: Text(
                                    'Add Remark',
                                    style: TextStyle(
                                      fontSize: 11 * s,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _gold,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        8 * s,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20 * s,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 18 * s),
                          Wrap(
                            spacing: 22 * s,
                            runSpacing: 20 * s,
                            children: [
                              _metricCard('ASSESSMENT DETAILS', 330 * s, [
                                if (widget.record.sessionId != null &&
                                    widget.record.sessionId!.isNotEmpty)
                                  _metric(
                                    'Session ID',
                                    widget.record.sessionId!,
                                  ),
                                if (widget.record.status.isNotEmpty)
                                  _metric('Status', widget.record.status),
                                _metric('Test Type', 'Walking Test'),
                                _metric(
                                  'System Duration',
                                  _duration(widget.record.duration),
                                ),
                                _metric(
                                  'Frames Captured',
                                  '${widget.record.frames}',
                                ),
                                _metric(
                                  'Average Speed',
                                  '${widget.record.avgSpeed.toStringAsFixed(2)} m/s',
                                ),
                                _metric(
                                  'Maximum Speed',
                                  '${widget.record.maxSpeed.toStringAsFixed(2)} m/s',
                                ),
                                _metric(
                                  'Spasms',
                                  '${widget.record.spasmCount}',
                                ),
                                _metric(
                                  'Alerts',
                                  '${widget.record.alertCount}',
                                ),
                              ]),
                              _metricCard('TEMPORAL PARAMETERS', 330 * s, [
                                _metric('Cadence', '— steps/min'),
                                _metric('Step Time', '— s'),
                                _metric('Stride Time', '— s'),
                                _metric('Stance Phase', '— %'),
                                _metric('Swing Phase', '— %'),
                              ]),
                              _metricCard('SPATIAL PARAMETERS', 330 * s, [
                                _metric('Step Length', '— cm'),
                                _metric('Stride Length', '— cm'),
                                _metric('Step Width', '— cm'),
                                _metric('Foot Rotation Angle', '—°'),
                                _metric('Walking Velocity', '— m/s'),
                              ]),
                            ],
                          ),
                          SizedBox(height: 34 * s),
                          Text(
                            'Foot Pressure Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12 * s),
                          Row(
                            children: [
                              Expanded(
                                child: _pressureCard(
                                  'AVERAGE',
                                  widget.record.leftPressure,
                                  widget.record.rightPressure,
                                ),
                              ),
                              SizedBox(width: 14 * s),
                              Expanded(
                                child: _pressureCard(
                                  'MAXIMUM',
                                  widget.record.leftPressure * 1.2,
                                  widget.record.rightPressure * 1.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12 * s),
                          _chartCard(
                            'COP DIAGRAM',
                            height: 150 * s,
                            line: true,
                          ),
                          SizedBox(height: 30 * s),
                          Text(
                            'EMG MUSCLE ACTIVATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12 * s),
                          Row(
                            children: [
                              Expanded(
                                child: _chartCard(
                                  'TIBIALIS ANTERIOR',
                                  height: 155 * s,
                                ),
                              ),
                              SizedBox(width: 12 * s),
                              Expanded(
                                child: _chartCard(
                                  'MEDIAL GASTROCNEMIUS',
                                  height: 155 * s,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 30 * s),
                          Text(
                            'Joint Trajectory',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12 * s),
                          Wrap(
                            spacing: 12 * s,
                            runSpacing: 12 * s,
                            children: [
                              for (final title in ['HIP', 'KNEE', 'ANKLE'])
                                _chartCard(
                                  title,
                                  width: 350 * s,
                                  height: 155 * s,
                                ),
                            ],
                          ),
                          SizedBox(height: 28 * s),
                          _remarkCard(widget.record.remark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 28 * s,
                  vertical: 12 * s,
                ),
                color: const Color(0xFF100D09),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _saveSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      minimumSize: Size(132 * s, 44 * s),
                      padding: EdgeInsets.symmetric(horizontal: 20 * s),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8 * s),
                      ),
                    ),
                    child: Text(widget.isDraft ? 'Save Session' : 'Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backButton(double s) {
    final size = (18 * s).clamp(36.0, 48.0);
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

  Widget _photo(String? path, double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: _gold),
    clipBehavior: Clip.antiAlias,
    child: path == null
        ? const Icon(Icons.person, color: Colors.black)
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.person),
          ),
  );

  Widget _metricCard(String title, double width, List<Widget> rows) =>
      Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: const Color(0xFF695A25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(13),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF39352A)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: rows),
            ),
          ],
        ),
      );

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ),
        const Text(':  ', style: TextStyle(color: _muted)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pressureCard(String title, double left, double right) => Container(
    height: 190,
    decoration: BoxDecoration(
      color: const Color(0xFF100D09),
      border: Border.all(color: const Color(0xFF383329)),
      borderRadius: BorderRadius.circular(9),
    ),
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Color(0xFF29251E)),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/foot_print.png',
                    fit: BoxFit.contain,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        left.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                      Text(
                        right.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chartCard(
    String title, {
    double? width,
    required double height,
    bool line = false,
  }) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF100D09),
      border: Border.all(color: const Color(0xFF383329)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Color(0xFF29251E)),
        Expanded(
          child: CustomPaint(
            painter: _ReportChartPainter(cop: line),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    ),
  );

  Widget _remarkCard(String remark) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 120),
    decoration: BoxDecoration(
      color: Colors.black,
      border: Border.all(color: const Color(0xFF695A25)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'REMARK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFF39352A)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            remark.isEmpty ? 'No remark added.' : remark,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  String _duration(Duration value) =>
      '${value.inMinutes} min ${value.inSeconds % 60} sec';
}

class _RemarkDialog extends StatefulWidget {
  const _RemarkDialog({required this.initialRemark});

  final String initialRemark;

  @override
  State<_RemarkDialog> createState() => _RemarkDialogState();
}

class _RemarkDialogState extends State<_RemarkDialog> {
  static const _gold = Color(0xFFE7CA55);
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRemark);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        48;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 690,
            maxHeight: max(160.0, availableHeight),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.48),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.08),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            autofocus: true,
                            maxLines: 5,
                            minLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Enter Remark Here........',
                              hintStyle: TextStyle(color: Colors.white),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              side: BorderSide(
                                color: _gold.withValues(alpha: .45),
                              ),
                              shape: const CircleBorder(),
                            ),
                            icon: const Icon(
                              Icons.close,
                              color: _gold,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: const BorderSide(color: _gold),
                          minimumSize: const Size(102, 36),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(102, 36),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(_controller.text.trim()),
                        child: const Text('Save'),
                      ),
                    ],
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

class _ReportChartPainter extends CustomPainter {
  _ReportChartPainter({required this.cop});
  final bool cop;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x332B2B20)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i <= 60; i++) {
      final x = size.width * i / 60;
      final y = size.height * (0.5 - 0.32 * sin(i / 8) - 0.04 * sin(i / 2.4));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..color = cop ? const Color(0xFFE65A50) : const Color(0xFF55B964)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _ReportChartPainter oldDelegate) =>
      oldDelegate.cop != cop;
}
