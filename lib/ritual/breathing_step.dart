import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 4-7-8 breathing, four rounds. The orb grows for the full 4s inhale,
/// rests through the 7s hold and empties across the whole 8s exhale. (The
/// old version used one 4s animation for every phase, so the exhale
/// finished halfway through its count.)
class BreathingStep extends StatefulWidget {
  final VoidCallback onComplete;
  const BreathingStep({super.key, required this.onComplete});

  @override
  State<BreathingStep> createState() => _BreathingStepState();
}

class _BreathingStepState extends State<BreathingStep> with TickerProviderStateMixin {
  static const _rounds = 4;

  late final AnimationController _orb = AnimationController(vsync: this, value: 0);
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  String _phase = 'Settle in';
  int _count = 0;
  int _round = 1;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 900));
    for (_round = 1; _round <= _rounds; _round++) {
      if (!await _phaseFor('Breathe in', 4, 1)) return;
      if (!await _phaseFor('Hold', 7, null)) return;
      if (!await _phaseFor('Breathe out', 8, 0)) return;
    }
    if (!_disposed) {
      setState(() {
        _round = _rounds;
        _phase = 'Well done';
        _count = 0;
      });
      widget.onComplete();
    }
  }

  Future<bool> _phaseFor(String label, int seconds, double? target) async {
    if (_disposed) return false;
    setState(() {
      _phase = label;
      _count = seconds;
    });
    // A soft tick at each phase change so it can be followed eyes closed.
    HapticFeedback.lightImpact();
    if (target != null) {
      _hold.stop();
      _orb.animateTo(target,
          duration: Duration(seconds: seconds), curve: Curves.easeInOutSine);
    } else {
      _hold.repeat(reverse: true);
    }
    for (var left = seconds; left > 0; left--) {
      await Future.delayed(const Duration(seconds: 1));
      if (_disposed) return false;
      if (left > 1) setState(() => _count = left - 1);
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _orb.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return LayoutBuilder(builder: (context, box) {
      final stage = math.min(box.maxWidth - 48, box.maxHeight - 150).clamp(200.0, 320.0);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: stage,
              child: AnimatedBuilder(
                animation: Listenable.merge([_orb, _hold]),
                builder: (context, _) {
                  final v = _orb.value;
                  final shimmer = _phase == 'Hold' ? _hold.value : 0.0;
                  final minScale = reduced ? 0.62 : 0.46;
                  final size = stage * (minScale + (0.78 - minScale) * v);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(stage, 0.05),
                      _ring(stage * 0.82, 0.07),
                      // Glow breathes with the orb.
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.10 + 0.22 * v + 0.08 * shimmer),
                              blurRadius: 40 + 50 * v,
                              spreadRadius: 4 + 10 * v,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.25, -0.3),
                            colors: [
                              const Color(0xFFFFFBF2).withValues(alpha: 0.97),
                              const Color(0xFFF3E4C6).withValues(alpha: 0.92),
                              const Color(0xFFE9CF9E).withValues(alpha: 0.62),
                            ],
                            stops: const [0, 0.5, 1],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: Motion.fast,
                          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                          child: Text(
                            _count == 0 ? '' : '$_count',
                            key: ValueKey('$_phase$_count'),
                            style: AppType.number.copyWith(
                              fontSize: 34,
                              color: AppColors.onAccent.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 36),
            AnimatedSwitcher(
              duration: Motion.slow,
              switchInCurve: Motion.easeOut,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                  child: c,
                ),
              ),
              child: Text(
                _phase,
                key: ValueKey(_phase),
                style: AppType.title.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= _rounds; i++)
                  AnimatedContainer(
                    duration: Motion.base,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _round ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < _round
                          ? AppColors.accent.withValues(alpha: 0.5)
                          : i == _round
                              ? AppColors.accent
                              : AppColors.white(0.12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Round $_round of $_rounds · 4-7-8 breathing', style: AppType.caption),
          ],
        ),
      );
    });
  }

  Widget _ring(double d, double alpha) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: alpha)),
        ),
      );
}
