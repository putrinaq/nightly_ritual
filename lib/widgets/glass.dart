import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A glass surface: translucent fill, a gradient edge that catches light at
/// the top and fades at the bottom (the "refraction" line), and optionally a
/// real backdrop blur.
///
/// Blur is opt-in. Each blur re-samples what's behind it every frame the sky
/// repaints, so it's reserved for surfaces that float over moving content
/// (nav bar, sheets, the hero card). List rows use the same material without
/// the blur — over a dark sky the difference is invisible, the cost isn't.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final double fill;
  final Color? tint;
  final bool shadow;
  final bool reduceTransparency;

  const Glass({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
    this.blur = 0,
    this.padding,
    this.fill = 0.045,
    this.tint,
    this.shadow = false,
    this.reduceTransparency = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final solid = reduceTransparency || highContrast;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: solid ? AppColors.inkSheet : null,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tint ?? Colors.white).withValues(alpha: fill * 1.6),
                  (tint ?? Colors.white).withValues(alpha: fill * 0.55),
                ],
              ),
      ),
      child: CustomPaint(
        foregroundPainter: _GlassEdgePainter(radius: radius, strong: highContrast),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );

    if (blur > 0 && !solid) {
      surface = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: surface,
        ),
      );
    }

    if (shadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: const [
            // Tinted toward the ink, not pure black.
            BoxShadow(color: Color(0x66010308), blurRadius: 40, offset: Offset(0, 18)),
          ],
        ),
        child: surface,
      );
    }
    return surface;
  }
}

class _GlassEdgePainter extends CustomPainter {
  final double radius;
  final bool strong;
  const _GlassEdgePainter({required this.radius, this.strong = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: strong
              ? [AppColors.white(0.5), AppColors.white(0.3)]
              : [AppColors.white(0.20), AppColors.white(0.06), AppColors.white(0.03)],
          stops: strong ? null : const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter old) =>
      old.radius != radius || old.strong != strong;
}

/// A hairline divider for rows grouped inside one glass surface.
class GlassDivider extends StatelessWidget {
  final double indent;
  const GlassDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: const SizedBox(
          height: 1,
          width: double.infinity,
          child: ColoredBox(color: AppColors.hairline),
        ),
      );
}
