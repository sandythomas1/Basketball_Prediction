import 'package:flutter/material.dart';

/// The asset path kept for any legacy references (watermark only).
const String signalLogoAsset =
    'lib/Assets/Gemini_Generated_Image_40aqrz40aqrz40aq.png';

/// Reusable Signal Sports logo widget — drawn programmatically so it is
/// always transparent regardless of theme or background.
class SignalLogo extends StatelessWidget {
  final double size;

  const SignalLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SignalIconPainter(),
      ),
    );
  }
}

class _SignalIconPainter extends CustomPainter {
  static const Color _teal = Color(0xFF00D4CC);
  static const Color _tealDark = Color(0xFF00A89E);
  static const Color _tealLight = Color(0xFF4DEAE4);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // --- Outer mountain triangle ---
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_tealLight, _teal],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final outer = Path()
      ..moveTo(cx, size.height * 0.08)
      ..lineTo(size.width * 0.92, size.height * 0.82)
      ..lineTo(size.width * 0.08, size.height * 0.82)
      ..close();

    canvas.drawPath(outer, outerPaint);

    // --- Inner highlight triangle (gives depth) ---
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final inner = Path()
      ..moveTo(cx, size.height * 0.22)
      ..lineTo(size.width * 0.68, size.height * 0.60)
      ..lineTo(size.width * 0.32, size.height * 0.60)
      ..close();

    canvas.drawPath(inner, innerPaint);

    // --- Dark cutout triangle at base (creates layered mountain look) ---
    final cutPaint = Paint()
      ..color = _tealDark
      ..style = PaintingStyle.fill;

    final cut = Path()
      ..moveTo(cx, size.height * 0.48)
      ..lineTo(size.width * 0.92, size.height * 0.82)
      ..lineTo(size.width * 0.08, size.height * 0.82)
      ..close();

    canvas.drawPath(cut, cutPaint);

    // --- Signal dot at apex ---
    canvas.drawCircle(
      Offset(cx, size.height * 0.08),
      size.width * 0.065,
      Paint()..color = _tealLight,
    );

    // --- Small signal arcs around the dot ---
    final arcPaint = Paint()
      ..color = _teal.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..strokeCap = StrokeCap.round;

    final dotR = size.width * 0.065;
    for (final r in [dotR * 2.2, dotR * 3.5]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, size.height * 0.08), radius: r),
        -2.4,
        1.6,
        false,
        arcPaint,
      );
    }

    // --- Baseline bar ---
    final barPaint = Paint()
      ..color = _tealLight.withValues(alpha: 0.5)
      ..strokeWidth = size.height * 0.03
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.87),
      Offset(size.width * 0.85, size.height * 0.87),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Transparent watermark overlay showing the Signal Sports logo.
/// Place inside a [Stack] — it fills the parent and is non-interactive.
class SignalWatermark extends StatelessWidget {
  const SignalWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: 0.04,
            child: SignalLogo(size: 220),
          ),
        ),
      ),
    );
  }
}
