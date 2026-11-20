import 'dart:ui';

import 'package:flutter/material.dart';

/// Shows the "Camera Setup Check" popup over a blurred dashboard.
///
/// Opens with a short fade + scale-up animation and fades out when closed.
/// Resolves to `true` when the user confirms and taps
/// "Acknowledge & continue", otherwise `false`.
Future<bool> showCameraSetupDialog(BuildContext context) async {
  final bool? result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Camera setup check',
    barrierColor: Colors.transparent, // the blur layer below draws the dim
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _CameraSetupDialog(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      // Pops in with a slight overshoot; on close the scale stays put so the
      // card simply fades away.
      final Animation<double> scale = Tween<double>(begin: 0.88, end: 1)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: const Threshold(0),
            ),
          );

      return AnimatedBuilder(
        animation: fade,
        builder: (context, _) => BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * fade.value,
            sigmaY: 8 * fade.value,
          ),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55 * fade.value),
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: scale, child: child),
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class _CameraSetupDialog extends StatefulWidget {
  const _CameraSetupDialog();

  @override
  State<_CameraSetupDialog> createState() => _CameraSetupDialogState();
}

class _CameraSetupDialogState extends State<_CameraSetupDialog> {
  static const Color _gold = Color(0xFFE7CA55);
  static const Color _textMuted = Color(0xFF9A9A9A);
  static const Color _rowBg = Color(0xFF17150F);
  static const Color _border = Color(0xFF34302A);

  // popup_acknowledge.png is 700 x 788; the visible card occupies
  // x 90–610, y 60–667 and the rest is its drop shadow.
  static const double _imgW = 700;
  static const double _imgH = 788;
  static const EdgeInsets _cardInset = EdgeInsets.fromLTRB(90, 60, 90, 121);

  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    // Fit the whole image (shadow included) inside 95% of the screen height
    // and 60% of its width, keeping the asset's proportions.
    final double scale = [
      screen.height * 0.95 / _imgH,
      screen.width * 0.6 / _imgW,
    ].reduce((a, b) => a < b ? a : b);

    return Center(
      child: SizedBox(
        width: _imgW * scale,
        height: _imgH * scale,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/popup_acknowledge.png',
                fit: BoxFit.fill,
              ),
            ),
            // Content is laid out at the asset's native size and scaled with
            // it, so proportions always match the design.
            Positioned.fill(
              child: FittedBox(
                child: SizedBox(
                  width: _imgW,
                  height: _imgH,
                  child: Padding(
                    padding: _cardInset,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
          // Content fills the card (buttons pinned to the bottom) and, if it
          // ever needs more room than the card has, shrinks to fit instead
          // of overflowing.
          child: LayoutBuilder(
            builder: (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: box.maxWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _headerIcon(),
                        const SizedBox(height: 14),
                        const Text(
                          'PRE-SESSION VERIFICATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: _gold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'CAMERA SETUP CHECK',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Confirm that all cameras are correctly positioned before '
                          'continuing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _cameraRow('Left camera', 'Camera 01'),
                        const SizedBox(height: 10),
                        _cameraRow('Front camera', 'Camera 02'),
                        const SizedBox(height: 10),
                        _cameraRow('Right camera', 'Camera 03'),
                        const SizedBox(height: 16),
                        _confirmBox(),
                        const SizedBox(height: 20),
                        const Spacer(),
                        _actions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 14, right: 14, child: _closeButton()),
      ],
    );
  }

  Widget _headerIcon() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF221E14),
              border: Border.all(color: _gold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: _gold.withValues(alpha: 0.15), blurRadius: 18),
              ],
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 28,
              color: _gold,
            ),
          ),
          Positioned(
            right: -2,
            bottom: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold,
                border: Border.all(color: const Color(0xFF1D1B15), width: 2),
              ),
              child: const Icon(Icons.check, size: 13, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraRow(String name, String id) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _rowBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2516),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.check, size: 16, color: _gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  id,
                  style: const TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ),
          ),
          const Text(
            'POSITION OK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmBox() {
    return Material(
      color: _rowBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _confirmed ? _gold.withValues(alpha: 0.6) : _border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _confirmed = !_confirmed),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _confirmed ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _gold, width: 1.5),
                ),
                child: _confirmed
                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'I confirm that all cameras are correctly positioned',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'This setup is ready for the next clinical session',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF15130E),
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 26),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              // Enabled only once the confirmation box is ticked.
              onPressed: _confirmed
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _gold.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.black54,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Acknowledge & continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _closeButton() {
    return Material(
      color: const Color(0xFF15130E),
      shape: const CircleBorder(side: BorderSide(color: _border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).pop(false),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close, size: 18, color: Colors.white70),
        ),
      ),
    );
  }
}
