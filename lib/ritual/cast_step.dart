import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/manifestation_ritual.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';

/// Reads each intention as a card. Swipe (or tap the arrow) to absorb it;
/// the deck behind rises to take its place.
class CastStep extends StatefulWidget {
  final String uid;
  final VoidCallback onDone;

  const CastStep({super.key, required this.uid, required this.onDone});

  @override
  State<CastStep> createState() => _CastStepState();
}

class _CastStepState extends State<CastStep> {
  List<ManifestationRitual>? _all;
  bool _failed = false;
  int _index = 0;
  // A fresh key per top card. Reusing one key moved the dismissed card's
  // state (off-screen, "leaving") onto the next card, which then ignored drags.
  var _topKey = GlobalKey<_SwipeCardState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await FirestoreService()
          .getRituals(widget.uid)
          .first
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _all = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _absorbed() {
    HapticFeedback.lightImpact();
    setState(() {
      _index++;
      _topKey = GlobalKey<_SwipeCardState>();
    });
    if (_index >= _all!.length) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load your intentions",
          message: 'Check your connection. You can still finish tonight\'s ritual.',
          actionLabel: 'Continue',
          onAction: widget.onDone,
        ),
      );
    }
    final all = _all;
    if (all == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }
    if (all.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'No intentions yet',
          message: 'Write a few on the Intentions tab and they\'ll appear here to read aloud.',
          actionLabel: 'Continue',
          onAction: widget.onDone,
        ),
      );
    }

    final done = _index >= all.length;
    return LayoutBuilder(builder: (context, box) {
      final cardW = math.min(340.0, box.maxWidth - 48);
      final cardH = math.min(440.0, box.maxHeight - 120).clamp(260.0, 440.0);
      final visible = <int>[
        for (var i = _index; i < math.min(_index + 3, all.length); i++) i,
      ];

      return Column(
        children: [
          const SizedBox(height: 24),
          Text(
            done ? 'All absorbed.' : 'Read it slowly, out loud if you can.',
            style: AppType.secondary,
          ),
          const Spacer(),
          SizedBox(
            width: cardW,
            height: cardH + 28,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                for (final i in visible.reversed)
                  _DeckSlot(
                    key: ValueKey(all[i].id),
                    depth: i - _index,
                    child: i == _index
                        ? _SwipeCard(
                            key: _topKey,
                            width: cardW,
                            onDismissed: _absorbed,
                            child: _IntentionCard(
                              ritual: all[i],
                              position: i + 1,
                              total: all.length,
                              width: cardW,
                              height: cardH,
                            ),
                          )
                        : _IntentionCard(
                            ritual: all[i],
                            position: i + 1,
                            total: all.length,
                            width: cardW,
                            height: cardH,
                          ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: done ? 0 : 1,
            duration: Motion.fast,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${math.min(_index + 1, all.length)} of ${all.length}',
                  style: AppType.caption.copyWith(fontFeatures: AppType.tabular),
                ),
                const SizedBox(width: 16),
                GlassIconButton(
                  icon: Icons.arrow_forward_rounded,
                  semanticLabel: 'Next intention',
                  color: AppColors.text,
                  onPressed: done ? null : () => _topKey.currentState?.flyOut(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    });
  }
}

/// Positions a card in the deck. When the top card leaves, the others
/// animate up a slot.
class _DeckSlot extends StatelessWidget {
  final int depth;
  final Widget child;
  const _DeckSlot({super.key, required this.depth, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: depth.toDouble()),
      duration: Motion.slow,
      curve: Motion.easeOut,
      builder: (context, d, child) => Transform.translate(
        offset: Offset(0, d * 14),
        child: Transform.scale(
          scale: 1 - d * 0.05,
          alignment: Alignment.topCenter,
          child: Opacity(opacity: (1 - d * 0.28).clamp(0.0, 1.0), child: child),
        ),
      ),
      child: child,
    );
  }
}

class _IntentionCard extends StatelessWidget {
  final ManifestationRitual ritual;
  final int position;
  final int total;
  final double width;
  final double height;

  const _IntentionCard({
    required this.ritual,
    required this.position,
    required this.total,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final text = ritual.title;
    final size = text.length > 140 ? 22.0 : text.length > 70 ? 26.0 : 32.0;
    return SizedBox(
      width: width,
      height: height,
      // An opaque base under the glass so the cards behind don't bleed
      // through the stack.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.inkRaised,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: const [
            BoxShadow(color: Color(0x80010308), blurRadius: 30, offset: Offset(0, 16)),
          ],
        ),
        child: Glass(
          radius: AppRadius.xl,
          fill: 0.05,
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Intention', style: AppType.caption),
                  const Spacer(),
                  Text(
                    position.toString().padLeft(2, '0'),
                    style: AppType.caption.copyWith(fontFeatures: AppType.tabular),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: AppType.title.copyWith(fontSize: size, height: 1.2),
                    ),
                  ),
                ),
              ),
              if (ritual.tags.isNotEmpty) ...[
                Center(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: ritual.tags.take(4).map(TagLabel.new).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Center(
                child: Text('Swipe to absorb', style: AppType.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drag-to-dismiss with physics: the card tracks the finger 1:1, tilts with
/// the drag, flies off on a fast flick (not just past a distance), and
/// springs home with the release velocity otherwise.
class _SwipeCard extends StatefulWidget {
  final Widget child;
  final double width;
  final VoidCallback onDismissed;

  const _SwipeCard({
    super.key,
    required this.child,
    required this.width,
    required this.onDismissed,
  });

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(vsync: this);
  double _y = 0;
  bool _leaving = false;

  // Passed in from the parent's LayoutBuilder. Reading context.size here
  // would throw when build() uses it ("Cannot get size during build").
  double get _width => widget.width;

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    if (_leaving) return;
    _x.stop(); // grab it mid-flight; continue from where it is
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_leaving) return;
    _x.value += d.delta.dx;
    setState(() => _y = (_y + d.delta.dy * 0.25).clamp(-40.0, 40.0));
  }

  void _onEnd(DragEndDetails d) {
    if (_leaving) return;
    final v = d.velocity.pixelsPerSecond.dx;
    final x = _x.value;
    final flick = v.abs() > 700 && v.sign == x.sign;
    if (x.abs() > _width * 0.32 || flick) {
      flyOut(x == 0 ? v.sign : x.sign, velocity: v);
    } else {
      _x.animateWith(SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.72),
        x,
        0,
        v,
      ));
      setState(() => _y = 0);
    }
  }

  Future<void> flyOut(double direction, {double velocity = 0}) async {
    if (_leaving) return;
    _leaving = true;
    final target = direction.sign * _width * 1.5;
    final remaining = (target - _x.value).abs();
    // Faster flicks leave faster; never slower than ~220ms.
    final ms = velocity.abs() > 0
        ? (remaining / velocity.abs() * 1000).clamp(160, 300).toInt()
        : 300;
    await _x.animateTo(target, duration: Duration(milliseconds: ms), curve: Motion.easeOut);
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: AnimatedBuilder(
        animation: _x,
        builder: (context, child) {
          final p = (_x.value / _width).clamp(-1.5, 1.5);
          return Transform.translate(
            offset: Offset(_x.value, _y),
            child: Transform.rotate(
              angle: p * 0.16,
              alignment: const Alignment(0, 1.4),
              child: Stack(
                children: [
                  child!,
                  // Warm edge glow as the card is pulled away.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: (p.abs() * 1.4).clamp(0.0, 0.8)),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
