import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/moon_phase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/controls.dart';
import 'breathing_step.dart';
import 'cast_step.dart';
import 'listen_step.dart';
import 'seal_step.dart';

class RitualFlow extends StatefulWidget {
  /// Persists the completed ritual and resolves to the new streak.
  final Future<int> Function() onComplete;
  final VoidCallback onExit;
  final String uid;
  final MoonPhaseInfo moon;

  const RitualFlow({
    super.key,
    required this.onComplete,
    required this.onExit,
    required this.uid,
    required this.moon,
  });

  @override
  State<RitualFlow> createState() => _RitualFlowState();
}

class _RitualFlowState extends State<RitualFlow> {
  static const _steps = ['Breathe', 'Listen', 'Cast', 'Seal'];

  int _step = 0;
  int _dir = 1;
  bool _sealing = false;
  int? _sealedStreak;

  bool get _sealed => _sealedStreak != null;

  void _go(int to) {
    if (to < 0) {
      widget.onExit();
      return;
    }
    if (to >= _steps.length || to == _step) return;
    setState(() {
      _dir = to > _step ? 1 : -1;
      _step = to;
    });
  }

  Future<void> _seal() async {
    if (_sealing || _sealed) return; // guards double taps
    setState(() => _sealing = true);
    try {
      final streak = await widget.onComplete();
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _sealedStreak = streak);
    } finally {
      if (mounted) setState(() => _sealing = false);
    }
  }

  Widget _content() {
    return switch (_step) {
      // Late timers from an outgoing step must not advance the flow twice.
      0 => BreathingStep(onComplete: () {
          if (_step == 0) _go(1);
        }),
      1 => ListenStep(uid: widget.uid),
      2 => CastStep(
          uid: widget.uid,
          onDone: () {
            if (_step == 2) _go(3);
          },
        ),
      _ => SealStep(moon: widget.moon, streak: _sealedStreak),
    };
  }

  Widget _bottom() {
    if (_step == 3) {
      return _sealed
          ? PrimaryButton(label: 'Return home', onPressed: widget.onExit)
          : PrimaryButton(
              label: "Seal tonight's ritual",
              loading: _sealing,
              onPressed: _seal,
            );
    }
    if (_step == 2) {
      return Center(
        child: TextAction(label: 'Skip to the seal', onPressed: () => _go(3)),
      );
    }
    return PrimaryButton(
      label: 'Continue',
      icon: Icons.arrow_forward_rounded,
      onPressed: () => _go(_step + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      // System back steps backwards instead of closing the app mid-ritual.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sealed) {
          widget.onExit();
        } else {
          _go(_step - 1);
        }
      },
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Leave ritual',
                    onPressed: widget.onExit,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Step ${_step + 1} of ${_steps.length}', style: AppType.caption),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: Motion.base,
                          child: Text(
                            _steps[_step],
                            key: ValueKey(_step),
                            style: AppType.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _step > 0 && !_sealed ? 1 : 0,
                    duration: Motion.fast,
                    child: IgnorePointer(
                      ignoring: _step == 0 || _sealed,
                      child: GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        semanticLabel: 'Previous step',
                        onPressed: () => _go(_step - 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Segments(count: _steps.length, active: _step, complete: _sealed),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.slow,
                reverseDuration: Motion.base,
                switchInCurve: Motion.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  // Incoming arrives from the direction of travel; outgoing
                  // leaves the opposite way. Rebuilt for outgoing entries
                  // after _step changes, so the key check is reliable.
                  final incoming = child.key == ValueKey(_step);
                  final dx = (incoming ? 1 : -1) * _dir * 0.06;
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: _content()),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + 20),
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: KeyedSubtree(
                  key: ValueKey('$_step-$_sealed'),
                  child: _bottom(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  final int count;
  final int active;
  final bool complete;

  const _Segments({required this.count, required this.active, required this.complete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: AppColors.hairline)),
                    AnimatedFractionallySizedBox(
                      duration: Motion.slow,
                      curve: Motion.easeOut,
                      alignment: Alignment.centerLeft,
                      widthFactor: (i <= active || complete) ? 1 : 0,
                      child: AnimatedContainer(
                        duration: Motion.slow,
                        color: i == active && !complete
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
