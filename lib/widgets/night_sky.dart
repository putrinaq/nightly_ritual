import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// The ambient backdrop behind every screen: an ink gradient, a slow moon
/// glow for the glass surfaces to refract, twinkling stars, the odd shooting
/// star, and a fine grain so the dark never reads as flat digital black.
///
/// It repaints through a listenable (no widget rebuilds). Twinkling is slow,
/// so frames are throttled to ~24fps unless a shooting star is crossing;
/// every repaint here also re-runs the blurs layered above it.
class NightSky extends StatefulWidget {
  const NightSky({super.key});

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  final _random = math.Random(7);
  late final List<_Star> _stars;
  _Shooting? _shooting;
  double _nextShootingAt = 6;
  double _lastPaint = -1;
  double _base = 0; // sky time carried across ticker restarts
  ui.Image? _grain;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stars = List.generate(150, (_) {
      final bright = _random.nextDouble() < 0.08;
      return _Star(
        x: _random.nextDouble(),
        y: math.pow(_random.nextDouble(), 1.4).toDouble(), // denser up high
        radius: bright ? 1.3 + _random.nextDouble() * 0.6 : 0.4 + _random.nextDouble() * 0.8,
        base: bright ? 0.75 : 0.18 + _random.nextDouble() * 0.45,
        speed: 0.25 + _random.nextDouble() * 0.9,
        phase: _random.nextDouble() * math.pi * 2,
      );
    });
    _ticker = createTicker(_onTick);
    _makeGrain();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = Motion.reduced(context);
    if (reduced && _ticker.isActive) _stop();
    if (!reduced && !_ticker.isActive) _ticker.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't burn battery animating a sky nobody can see.
    if (state == AppLifecycleState.resumed) {
      if (!Motion.reduced(context) && !_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _stop();
    }
  }

  void _onTick(Duration elapsed) {
    final t = _base + elapsed.inMicroseconds / 1e6;

    if (_shooting == null && t >= _nextShootingAt) {
      _shooting = _Shooting(
        start: t,
        x: 0.25 + _random.nextDouble() * 0.7,
        y: 0.04 + _random.nextDouble() * 0.28,
        angle: math.pi * (0.78 + _random.nextDouble() * 0.1),
        length: 0.22 + _random.nextDouble() * 0.12,
      );
    }
    if (_shooting != null && t - _shooting!.start > _Shooting.duration) {
      _shooting = null;
      _nextShootingAt = t + 7 + _random.nextDouble() * 10;
    }

    final fast = _shooting != null;
    if (fast || t - _lastPaint >= 1 / 24) {
      _lastPaint = t;
      _clock.value = t;
    }
  }

  // Ticker time resets on restart; keep the sky continuous across pauses.
  void _stop() {
    _base = _clock.value;
    _ticker.stop();
  }

  void _makeGrain() {
    const size = 128;
    final pixels = Uint8List(size * size * 4);
    final rnd = math.Random(11);
    for (var i = 0; i < size * size; i++) {
      final v = rnd.nextInt(256);
      pixels[i * 4] = v;
      pixels[i * 4 + 1] = v;
      pixels[i * 4 + 2] = v;
      pixels[i * 4 + 3] = 255;
    }
    ui.decodeImageFromPixels(pixels, size, size, ui.PixelFormat.rgba8888, (img) {
      if (mounted) {
        setState(() => _grain = img);
      } else {
        img.dispose();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    _grain?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SkyPainter(
          clock: _clock,
          stars: _stars,
          shooting: () => _shooting,
          grain: _grain,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Star {
  final double x, y, radius, base, speed, phase;
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.base,
    required this.speed,
    required this.phase,
  });
}

class _Shooting {
  static const duration = 1.1;
  final double start, x, y, angle, length;
  const _Shooting({
    required this.start,
    required this.x,
    required this.y,
    required this.angle,
    required this.length,
  });
}

class _SkyPainter extends CustomPainter {
  final ValueNotifier<double> clock;
  final List<_Star> stars;
  final _Shooting? Function() shooting;
  final ui.Image? grain;

  _SkyPainter({
    required this.clock,
    required this.stars,
    required this.shooting,
    required this.grain,
  }) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C0F19), Color(0xFF080A10), AppColors.ink],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    // Moon glow, drifting a few pixels over ~90s. Slow enough to be felt,
    // not watched.
    final drift = Offset(math.sin(t / 14) * 18, math.cos(t / 18) * 12);
    final glowCenter = Offset(w * 0.86, h * 0.06) + drift;
    final glowRadius = math.max(w, h) * 0.62;
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.moonlight.withValues(alpha: 0.16),
            AppColors.moonlight.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0, 0.38, 1],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // A low, warm ember near the horizon — the candle to the moon's light.
    final emberCenter = Offset(w * 0.08, h * 1.02) - drift * 0.5;
    final emberRadius = math.max(w, h) * 0.55;
    canvas.drawCircle(
      emberCenter,
      emberRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.accent.withValues(alpha: 0.075), Colors.transparent],
        ).createShader(Rect.fromCircle(center: emberCenter, radius: emberRadius)),
    );

    final starPaint = Paint();
    for (final s in stars) {
      final twinkle = math.sin(t * s.speed + s.phase) * 0.22;
      final a = (s.base + twinkle * s.base).clamp(0.05, 1.0);
      // Fade stars toward the bottom where dense UI sits, so they don't
      // read as specks through the glass rows.
      final fade = 1.0 - 0.8 * Curves.easeInOut.transform(((s.y - 0.22) / 0.5).clamp(0.0, 1.0));
      starPaint.color = Colors.white.withValues(alpha: a * fade);
      canvas.drawCircle(Offset(s.x * w, s.y * h), s.radius, starPaint);
    }

    final sh = shooting();
    if (sh != null) {
      final p = ((t - sh.start) / _Shooting.duration).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(p);
      final travel = sh.length * w * 1.6;
      final dir = Offset(math.cos(sh.angle), math.sin(sh.angle));
      final head = Offset(sh.x * w, sh.y * h) + dir * travel * eased;
      final tail = head - dir * (sh.length * w) * (0.35 + 0.65 * (1 - p));
      final alpha = p < 0.15 ? p / 0.15 : (1 - p) / 0.85;
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, head, [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.85 * alpha),
          ]),
      );
    }

    final g = grain;
    if (g != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(g, TileMode.repeated, TileMode.repeated,
              Matrix4.identity().storage, filterQuality: FilterQuality.none)
          ..color = Colors.white.withValues(alpha: 0.035)
          ..blendMode = BlendMode.softLight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.grain != grain || old.stars != stars;
}
