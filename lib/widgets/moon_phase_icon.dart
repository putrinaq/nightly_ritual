import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Draws the moon as it actually looks tonight: a lit limb plus an
/// elliptical terminator whose width follows the cycle, so every night of
/// the month renders differently (not just eight stock shapes).
class MoonPhaseIcon extends StatelessWidget {
  /// 0 = new moon, 0.5 = full moon.
  final double cycleFraction;
  final double size;
  final bool glow;
  final bool detailed;

  const MoonPhaseIcon({
    super.key,
    required this.cycleFraction,
    this.size = 28,
    this.glow = false,
    this.detailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: MoonPhasePainter(
          cycleFraction: cycleFraction,
          glow: glow,
          detailed: detailed,
        ),
      ),
    );
  }
}

class MoonPhasePainter extends CustomPainter {
  final double cycleFraction;
  final bool glow;
  final bool detailed;

  MoonPhasePainter({
    required this.cycleFraction,
    this.glow = false,
    this.detailed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final disk = Rect.fromCircle(center: c, radius: r);
    final f = cycleFraction % 1.0;
    final illumination = (1 - math.cos(f * 2 * math.pi)) / 2;

    if (glow && illumination > 0.02) {
      canvas.drawCircle(
        c,
        r * 1.05,
        Paint()
          ..color = AppColors.moonSurface.withValues(alpha: 0.10 + 0.22 * illumination)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );
    }

    // Unlit body: barely there, like earthshine.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, -0.2),
          colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.015)],
        ).createShader(disk),
    );

    final lit = _litPath(c, r, f);
    canvas.save();
    canvas.clipPath(lit);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          radius: 1.1,
          colors: [Color(0xFFFAF6EC), AppColors.moonSurface, Color(0xFFCFC7B3)],
          stops: [0, 0.55, 1],
        ).createShader(disk),
    );
    if (detailed) _paintMaria(canvas, c, r);
    canvas.restore();

    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.07),
    );
  }

  Path _litPath(Offset c, double r, double f) {
    final waxing = f < 0.5;
    // cos goes 1 (new) → -1 (full) → 1 (new). Its magnitude is the
    // terminator's horizontal radius; its sign says crescent vs gibbous.
    final t = math.cos(f * 2 * math.pi);
    final rx = (r * t.abs()).clamp(0.001, r);
    final ellipse = Rect.fromCenter(center: c, width: rx * 2, height: r * 2);
    final disk = Rect.fromCircle(center: c, radius: r);

    final path = Path()..moveTo(c.dx, c.dy - r);
    // Lit limb: the right edge while waxing, left while waning.
    path.arcTo(disk, -math.pi / 2, waxing ? math.pi : -math.pi, false);
    // Terminator back to the top. For crescents it bows toward the lit
    // limb, for gibbous phases it bows away from it.
    final crescent = t > 0;
    final bowRight = waxing == crescent;
    path.arcTo(ellipse, math.pi / 2, bowRight ? -math.pi : math.pi, false);
    path.close();
    return path;
  }

  void _paintMaria(Canvas canvas, Offset c, double r) {
    // Soft, irregular seas — suggested, not drawn.
    final paint = Paint()
      ..color = const Color(0xFF9A927F).withValues(alpha: 0.13)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.09);
    final seas = [
      (-0.26, -0.20, 0.50, 0.30),
      (-0.06, -0.34, 0.26, 0.20),
      (0.22, -0.18, 0.30, 0.38),
      (0.10, 0.22, 0.36, 0.22),
      (-0.34, 0.20, 0.22, 0.30),
    ];
    for (final (dx, dy, w, h) in seas) {
      canvas.drawOval(
        Rect.fromCenter(center: c + Offset(r * dx, r * dy), width: r * w * 1.4, height: r * h * 1.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MoonPhasePainter old) =>
      old.cycleFraction != cycleFraction ||
      old.glow != glow ||
      old.detailed != detailed;
}
