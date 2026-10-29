import 'package:flutter/material.dart';

import '../services/moon_phase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/moon_phase_icon.dart';

/// The last step. Before sealing it asks for one more breath; once sealed,
/// light ripples out from the moon. This is the one celebratory moment in
/// the app, seen at most once a night, so it's allowed to take its time.
class SealStep extends StatefulWidget {
  final MoonPhaseInfo moon;

  /// Set once the ritual has been saved.
  final int? streak;

  const SealStep({super.key, required this.moon, this.streak});

  @override
  State<SealStep> createState() => _SealStepState();
}

class _SealStepState extends State<SealStep> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool get _sealed => widget.streak != null;

  @override
  void didUpdateWidget(SealStep old) {
    super.didUpdateWidget(old);
    if (old.streak == null && widget.streak != null && !Motion.reduced(context)) {
      _ripple.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak ?? 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 240,
              child: AnimatedBuilder(
                animation: _ripple,
                builder: (context, child) => CustomPaint(
                  painter: _RipplePainter(_ripple.value),
                  child: child,
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: _sealed ? 1.06 : 1,
                    duration: const Duration(milliseconds: 900),
                    curve: Motion.easeOut,
                    child: MoonPhaseIcon(
                      // Sealing fills the moon: the night is complete.
                      cycleFraction: _sealed ? 0.5 : widget.moon.cycleFraction,
                      size: 128,
                      glow: true,
                      detailed: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Motion.easeOut,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: Column(
                key: ValueKey(_sealed),
                children: [
                  Text(
                    _sealed ? 'Sealed.' : 'Seal tonight',
                    style: AppType.display.copyWith(fontStyle: _sealed ? FontStyle.italic : null),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      _sealed
                          ? 'Rest well. The night is yours.'
                          : 'One more slow breath. When you\'re ready, seal the ritual.',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  if (_sealed) ...[
                    const SizedBox(height: 24),
                    Glass(
                      radius: 999,
                      fill: 0.06,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            streak == 1 ? 'First night of a new streak' : '$streak-night streak',
                            style: AppType.bodyStrong.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t;
  _RipplePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final local = ((t - i * 0.14) / 0.72).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final r = 64 + eased * size.width * 0.62;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * (1 - local) + 0.4
          ..color = AppColors.accent.withValues(alpha: 0.55 * (1 - local)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}
