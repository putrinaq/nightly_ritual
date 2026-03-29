import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/moon_phase_service.dart';

class MoonPhaseIcon extends StatelessWidget {
  final MoonPhaseType phase;
  final double size;
  final Color color;

  const MoonPhaseIcon({
    super.key,
    required this.phase,
    this.size = 28,
    this.color = const Color(0xFFE9D5FF),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: MoonPhasePainter(phase: phase, color: color),
    );
  }
}

class MoonPhasePainter extends CustomPainter {
  final MoonPhaseType phase;
  final Color color;

  MoonPhasePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Base moon outline
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Filled part paint
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Dark part paint (for the shadow)
    final darkPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw the base circle outline
    canvas.drawCircle(center, radius, outlinePaint);

    switch (phase) {
      case MoonPhaseType.newMoon:
        // Just the outline, moon is dark
        canvas.drawCircle(center, radius - 1, darkPaint);
        break;

      case MoonPhaseType.waxingCrescent:
        _drawCrescent(canvas, size, radius, fillPaint, darkPaint, isWaxing: true, crescentSize: 0.3);
        break;

      case MoonPhaseType.firstQuarter:
        _drawHalf(canvas, size, radius, fillPaint, darkPaint, isRight: true);
        break;

      case MoonPhaseType.waxingGibbous:
        _drawGibbous(canvas, size, radius, fillPaint, darkPaint, isWaxing: true);
        break;

      case MoonPhaseType.fullMoon:
        canvas.drawCircle(center, radius - 1, fillPaint);
        break;

      case MoonPhaseType.waningGibbous:
        _drawGibbous(canvas, size, radius, fillPaint, darkPaint, isWaxing: false);
        break;

      case MoonPhaseType.lastQuarter:
        _drawHalf(canvas, size, radius, fillPaint, darkPaint, isRight: false);
        break;

      case MoonPhaseType.waningCrescent:
        _drawCrescent(canvas, size, radius, fillPaint, darkPaint, isWaxing: false, crescentSize: 0.3);
        break;
    }
  }

  void _drawHalf(Canvas canvas, Size size, double radius, Paint fillPaint, Paint darkPaint, {required bool isRight}) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the dark half
    final darkPath = Path();
    if (isRight) {
      darkPath.moveTo(center.dx, center.dy - radius);
      darkPath.arcTo(
        Rect.fromCircle(center: center, radius: radius - 1),
        -math.pi / 2,
        math.pi,
        false,
      );
      darkPath.close();
      canvas.drawPath(darkPath, darkPaint);
    } else {
      darkPath.moveTo(center.dx, center.dy - radius);
      darkPath.arcTo(
        Rect.fromCircle(center: center, radius: radius - 1),
        -math.pi / 2,
        -math.pi,
        false,
      );
      darkPath.close();
      canvas.drawPath(darkPath, darkPaint);
    }

    // Draw the lit half
    final litPath = Path();
    if (isRight) {
      litPath.moveTo(center.dx, center.dy - radius);
      litPath.arcTo(
        Rect.fromCircle(center: center, radius: radius - 1),
        -math.pi / 2,
        -math.pi,
        false,
      );
      litPath.close();
    } else {
      litPath.moveTo(center.dx, center.dy - radius);
      litPath.arcTo(
        Rect.fromCircle(center: center, radius: radius - 1),
        -math.pi / 2,
        math.pi,
        false,
      );
      litPath.close();
    }
    canvas.drawPath(litPath, fillPaint);
  }

  void _drawCrescent(Canvas canvas, Size size, double radius, Paint fillPaint, Paint darkPaint, {required bool isWaxing, required double crescentSize}) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = radius - 1;

    // First fill the whole moon with dark
    canvas.drawCircle(center, r, darkPaint);

    // Create crescent by subtracting a circle
    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: r));

    final innerOffset = isWaxing ? -r * (1 - crescentSize) : r * (1 - crescentSize);
    final innerCenter = Offset(center.dx + innerOffset, center.dy);

    final innerPath = Path();
    innerPath.addOval(Rect.fromCircle(center: innerCenter, radius: r * 0.9));

    final crescentPath = Path.combine(PathOperation.difference, path, innerPath);
    canvas.drawPath(crescentPath, fillPaint);
  }

  void _drawGibbous(Canvas canvas, Size size, double radius, Paint fillPaint, Paint darkPaint, {required bool isWaxing}) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = radius - 1;

    // Fill the moon
    canvas.drawCircle(center, r, fillPaint);

    // Create shadow crescent
    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: r));

    final innerOffset = isWaxing ? r * 0.5 : -r * 0.5;
    final innerCenter = Offset(center.dx + innerOffset, center.dy);

    final innerPath = Path();
    innerPath.addOval(Rect.fromCircle(center: innerCenter, radius: r * 0.8));

    final shadowPath = Path.combine(PathOperation.difference, path, innerPath);
    canvas.drawPath(shadowPath, darkPaint);
  }

  @override
  bool shouldRepaint(covariant MoonPhasePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.color != color;
  }
}
