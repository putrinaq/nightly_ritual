import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Anything tappable. Shrinks the instant a finger lands (feedback on press,
/// not release), springs back when it lifts, and exposes itself as a button
/// to screen readers.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.semanticLabel,
    this.haptic = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _set(false);
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          // Fast in, a touch slower out: the press is acknowledged
          // immediately, the release settles.
          duration: _down ? Motion.press : Motion.fast,
          curve: Motion.easeOut,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: Motion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child into place once, after [delay]. Used to stagger
/// a screen's sections on first appearance. Never blocks interaction.
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  /// Delay for the nth item in a staggered group.
  static Duration stagger(int index, {int stepMs = 55, int startMs = 0}) =>
      Duration(milliseconds: startMs + (index.clamp(0, 8) * stepMs));

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.reveal);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Motion.easeOut);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Counts up to [value] when it first appears and whenever it changes.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;

  const CountUp({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      // Starts from 0 on first build; later changes animate from the
      // current on-screen value.
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Motion.easeOut,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
