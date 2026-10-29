import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/shell.dart';
import '../widgets/sheets.dart';
import '../widgets/spotify_connect.dart';

class ProfilePage extends StatelessWidget {
  final User user;
  final int streakDays;
  final int totalRituals;

  const ProfilePage({
    super.key,
    required this.user,
    required this.streakDays,
    required this.totalRituals,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      title: 'Sign out?',
      message: 'Your intentions and habits stay saved to your account.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    try {
      await AuthService().signOut();
    } catch (_) {
      if (context.mounted) showToast(context, "Couldn't sign out. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : 'Night owl';
    final email = user.email ?? '';
    final since = user.metadata.creationTime;
    final bottom = ShellInsets.bottomOf(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 8),
        children: [
          const Reveal(child: Text('Profile', style: AppType.title)),
          const SizedBox(height: 28),
          Reveal(
            delay: Reveal.stagger(1),
            child: Row(
              children: [
                _Avatar(photoUrl: user.photoURL, name: name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppType.heading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (since != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Here since ${_months[since.month - 1]} ${since.year}',
                          style: AppType.secondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Reveal(
            delay: Reveal.stagger(2),
            child: Glass(
              radius: AppRadius.lg,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(child: _Stat(value: streakDays, label: 'night streak')),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.hairline),
                    Expanded(child: _Stat(value: totalRituals, label: 'rituals sealed')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Reveal(
            delay: Reveal.stagger(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Account'),
                Glass(
                  radius: AppRadius.lg,
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.person_outline_rounded, title: 'Name', value: name),
                      const GlassDivider(indent: 66),
                      _InfoRow(
                        icon: Icons.alternate_email_rounded,
                        title: 'Email',
                        value: email.isEmpty ? 'Not shared' : email,
                      ),
                      const GlassDivider(indent: 66),
                      const _InfoRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Signed in with',
                        value: 'Google',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const FieldLabel('Music'),
                const SpotifyConnectCard(),
                const SizedBox(height: 28),
                Pressable(
                  onTap: () => _signOut(context),
                  scale: 0.985,
                  child: const Glass(
                    radius: AppRadius.lg,
                    padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Row(
                      children: [
                        RowIcon(Icons.logout_rounded, color: AppColors.danger),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Sign out',
                            style: TextStyle(
                              fontFamily: AppType.sans,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CountUp(value: value, style: AppType.number),
        const SizedBox(height: 4),
        Text(label, style: AppType.caption),
      ],
    );
  }
}

/// Rounded-square avatar (not another circle), with initials as fallback.
class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _Avatar({this.photoUrl, required this.name});

  String get _initials {
    // Split on any whitespace and drop empties: "Ana  Lima" used to yield an
    // empty middle part and crash on parts[1][0].
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(_initials, style: AppType.heading.copyWith(color: AppColors.accent)),
    );
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.accentTint(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.white(0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null
          ? fallback
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null && !sync ? 0 : 1,
                duration: Motion.base,
                child: child,
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        children: [
          RowIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppType.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
