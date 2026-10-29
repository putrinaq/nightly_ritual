import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/moon_phase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/moon_phase_icon.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _error;
  final _moon = MoonPhaseService.getCurrentMoonPhase();

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().signInWithGoogle();
      // The auth listener in MainScreen takes it from here.
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't sign in. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    child: Row(
                      children: [
                        MoonPhaseIcon(cycleFraction: _moon.cycleFraction, size: 18),
                        const SizedBox(width: 10),
                        Text('${_moon.name} tonight', style: AppType.caption),
                      ],
                    ),
                  ),
                  SizedBox(height: box.maxHeight * 0.12),
                  Reveal(
                    delay: Reveal.stagger(1, stepMs: 90),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: MoonPhaseIcon(
                        cycleFraction: _moon.cycleFraction,
                        size: 132,
                        glow: true,
                        detailed: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Reveal(
                    delay: Reveal.stagger(2, stepMs: 90),
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Nightly\n'),
                        TextSpan(
                          text: 'ritual',
                          style: AppType.display.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.accent,
                          ),
                        ),
                      ]),
                      style: AppType.display.copyWith(fontSize: 64, height: 0.95),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Reveal(
                    delay: Reveal.stagger(3, stepMs: 90),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        'Ten quiet minutes at the end of the day. Breathe, put on something slow, '
                        'read your intentions, and seal the night.',
                        style: AppType.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  SizedBox(height: box.maxHeight * 0.08),
                  Reveal(
                    delay: Reveal.stagger(4, stepMs: 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GoogleButton(loading: _loading, onPressed: _signIn),
                        AnimatedSize(
                          duration: Motion.base,
                          curve: Motion.easeOut,
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    _error!,
                                    style: AppType.secondary.copyWith(color: AppColors.danger),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your intentions and habits sync to your Google account.',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: loading ? null : onPressed,
      haptic: true,
      semanticLabel: 'Continue with Google',
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.moonlight.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: Motion.fast,
          child: loading
              ? const SizedBox(
                  key: ValueKey('l'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                )
              : Row(
                  key: const ValueKey('b'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleMark(size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: AppType.bodyStrong.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The four-colour "G", drawn rather than faked with a blue letter.
class _GoogleMark extends StatelessWidget {
  final double size;
  const _GoogleMark({required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleMarkPainter());
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159265 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, -230 * deg, -95 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, -325 * deg, -45 * deg, false, p(const Color(0xFF4285F4)));
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.5 - stroke / 2, s * 0.5 - stroke * 0.1, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
