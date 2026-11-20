import 'dart:ui';

import 'package:flutter/material.dart';

/// One walkthrough tip: its text and where its card sits on screen.
///
/// [left]/[top] are fractions of the screen size, [fromRight] decides which
/// side the card slides in from.
class _WalkthroughStep {
  const _WalkthroughStep({
    required this.text,
    required this.left,
    required this.top,
    required this.fromRight,
  });

  final String text;
  final double left;
  final double top;
  final bool fromRight;
}

const List<_WalkthroughStep> _steps = [
  _WalkthroughStep(
    text:
        'In the dashboard screen shows the Device activity  ,LiveVideo,EMG '
        'Signalling are working correctly.',
    left: 0.49,
    top: 0.13,
    fromRight: true,
  ),
  _WalkthroughStep(
    text:
        'The dashboard will have a Patient List button. Clicking it will open '
        'the list of already added patients. An Add New Patient button will be '
        'available on the Patient List page to create a new patient.',
    left: 0.11,
    top: 0.67,
    fromRight: false,
  ),
  _WalkthroughStep(
    text:
        'The dashboard will have a Patient List button. Clicking it will open '
        'the list of already added patients. An Add New Patient button will be '
        'available on the Patient List page to create a new patient.',
    left: 0.47,
    top: 0.67,
    fromRight: true,
  ),
  _WalkthroughStep(
    text:
        "Clicking on a patient's profile will open the Session List page, "
        'where all previously completed sessions for that patient will be '
        'displayed. The page will also include a Start New Session button to '
        'begin a new session.',
    left: 0.09,
    top: 0.09,
    fromRight: false,
  ),
];

/// Shows the dashboard walkthrough over a blurred background.
///
/// The overlay fades in; each tip card slides in from its own side and the
/// previous one slides back out the way it came. Skip (or Next on the last
/// tip) fades everything away.
Future<void> showWalkthrough(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Walkthrough',
    barrierColor: Colors.transparent, // the blur layer below draws the dim
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _WalkthroughOverlay(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return AnimatedBuilder(
        animation: fade,
        builder: (context, _) => BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * fade.value,
            sigmaY: 8 * fade.value,
          ),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.45 * fade.value),
            child: FadeTransition(opacity: fade, child: child),
          ),
        ),
      );
    },
  );
}

class _WalkthroughOverlay extends StatefulWidget {
  const _WalkthroughOverlay();

  @override
  State<_WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<_WalkthroughOverlay> {
  int _index = 0;

  void _next() {
    if (_index < _steps.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    // Same scale rule as the dashboard (920 x 575 reference design).
    final double s = [
      screen.width / 920,
      screen.height / 575,
    ].reduce((a, b) => a < b ? a : b).clamp(0.8, 2.2);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Each step is a full-screen layer, so both can be on screen while one
      // slides out and the next slides in.
      layoutBuilder: (current, previous) =>
          Stack(children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final _WalkthroughStep step =
            _steps[(child.key! as ValueKey<int>).value];
        final Offset from = Offset(step.fromRight ? 0.6 : -0.6, 0);
        return SlideTransition(
          position: Tween<Offset>(
            begin: from,
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _StepLayer(
        key: ValueKey<int>(_index),
        step: _steps[_index],
        scale: s,
        onSkip: _skip,
        onNext: _next,
      ),
    );
  }
}

class _StepLayer extends StatelessWidget {
  const _StepLayer({
    super.key,
    required this.step,
    required this.scale,
    required this.onSkip,
    required this.onNext,
  });

  final _WalkthroughStep step;
  final double scale;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final double s = scale;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: screen.width * step.left,
            top: screen.height * step.top,
            width: screen.width * 0.46,
            child: Material(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10 * s),
                side: BorderSide(
                  color: const Color(0xFFE7CA55).withValues(alpha: 0.35),
                ),
              ),
              elevation: 12,
              shadowColor: Colors.black,
              child: Padding(
                padding: EdgeInsets.fromLTRB(28 * s, 22 * s, 18 * s, 10 * s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.text,
                      style: TextStyle(
                        fontSize: _fs(s, 9.5),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 10 * s),
                    Row(
                      children: [
                        _action('Skip', onSkip, s),
                        const Spacer(),
                        _action('Next', onNext, s),
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
  }

  Widget _action(String label, VoidCallback onTap, double s) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: Size(0, (24 * s).clamp(36.0, 52.0)),
        padding: EdgeInsets.symmetric(horizontal: 10 * s),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: _fs(s, 8.5), fontWeight: FontWeight.w600),
      ),
    );
  }

  static double _fs(double s, double base) {
    final double size = base * s;
    return size < 10 ? 10 : size;
  }
}
