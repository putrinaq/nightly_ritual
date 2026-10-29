import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/moon_phase_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/moon_phase_icon.dart';
import '../widgets/motion.dart';
import '../widgets/playlists.dart';
import '../widgets/shell.dart';
import '../widgets/sheets.dart';
import 'reminder_sheet.dart';

class HomePage extends StatefulWidget {
  final int streakDays;
  final int totalRituals;
  final bool todayRitualCompleted;
  final String? lastRitualDate;
  final MoonPhaseInfo moonPhase;
  final NotificationService notificationService;
  final ReminderPreferences reminderPrefs;
  final User user;
  final VoidCallback onBegin;

  const HomePage({
    super.key,
    required this.streakDays,
    required this.totalRituals,
    required this.todayRitualCompleted,
    required this.lastRitualDate,
    required this.moonPhase,
    required this.notificationService,
    required this.reminderPrefs,
    required this.user,
    required this.onBegin,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still up';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _firstName {
    final n = widget.user.displayName?.trim() ?? '';
    if (n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  void _openReminder() {
    showGlassSheet(
      context,
      builder: (_) => ReminderSheet(
        notificationService: widget.notificationService,
        prefs: widget.reminderPrefs,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _firstName;
    final bottom = ShellInsets.bottomOf(context);
    final prefs = widget.reminderPrefs;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 8),
        children: [
          Reveal(
            child: Row(
              children: [
                Expanded(
                  child: Text(Dates.longDate(DateTime.now()), style: AppType.caption),
                ),
                _MoonChip(moon: widget.moonPhase),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Reveal(
            delay: Reveal.stagger(1),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: name == null ? '$_greeting.' : '$_greeting,\n'),
                if (name != null)
                  TextSpan(
                    text: '$name.',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ]),
              style: AppType.display,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 28),
          Reveal(
            delay: Reveal.stagger(2),
            child: _TonightCard(
              moon: widget.moonPhase,
              completed: widget.todayRitualCompleted,
              onTap: widget.onBegin,
            ),
          ),
          const SizedBox(height: 12),
          Reveal(
            delay: Reveal.stagger(3),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 11,
                    child: _StreakTile(
                      streak: widget.streakDays,
                      lastRitualDate: widget.lastRitualDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 8,
                    child: _StatTile(value: widget.totalRituals, label: 'rituals sealed'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Reveal(
            delay: Reveal.stagger(4),
            child: Glass(
              radius: AppRadius.lg,
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Playlists',
                    subtitle: 'Music for the listen step',
                    onTap: () => showPlaylistsSheet(context, widget.user.uid),
                  ),
                  const GlassDivider(indent: 66),
                  _SettingRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nightly reminder',
                    subtitle: prefs.isEnabled ? 'Every night at ${prefs.timeFormatted}' : 'Off',
                    trailing: AnimatedContainer(
                      duration: Motion.base,
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: prefs.isEnabled ? AppColors.accent : AppColors.white(0.15),
                        boxShadow: prefs.isEnabled
                            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 8)]
                            : null,
                      ),
                    ),
                    onTap: _openReminder,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoonChip extends StatelessWidget {
  final MoonPhaseInfo moon;
  const _MoonChip({required this.moon});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${moon.name}, ${moon.illuminationPercent} illuminated',
      excludeSemantics: true,
      child: Glass(
        radius: 999,
        fill: 0.05,
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoonPhaseIcon(cycleFraction: moon.cycleFraction, size: 16),
            const SizedBox(width: 8),
            Text(moon.name, style: AppType.caption.copyWith(color: AppColors.text)),
            const SizedBox(width: 6),
            Text(moon.illuminationPercent,
                style: AppType.caption.copyWith(fontFeatures: AppType.tabular)),
          ],
        ),
      ),
    );
  }
}

class _TonightCard extends StatelessWidget {
  final MoonPhaseInfo moon;
  final bool completed;
  final VoidCallback onTap;

  const _TonightCard({required this.moon, required this.completed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      haptic: true,
      semanticLabel: completed ? 'Repeat tonight\'s ritual' : 'Begin tonight\'s ritual',
      child: Glass(
        radius: AppRadius.xl,
        blur: 18,
        fill: 0.05,
        shadow: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              Positioned(
                right: 22,
                top: 22,
                child: MoonPhaseIcon(
                  cycleFraction: moon.cycleFraction,
                  size: 104,
                  glow: true,
                  detailed: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLine(completed: completed),
                    const SizedBox(height: 88),
                    AnimatedSwitcher(
                      duration: Motion.slow,
                      child: Text(
                        completed ? 'Sealed for\ntonight' : 'Begin tonight\'s\nritual',
                        key: ValueKey(completed),
                        style: AppType.title.copyWith(fontSize: 36),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        completed
                            ? 'Come back any time tonight to read your intentions again.'
                            : MoonPhaseService.getRitualMeaning(moon.phase),
                        style: AppType.secondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Breathe · Listen · Cast · Seal',
                            style: AppType.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: completed ? AppColors.white(0.08) : AppColors.accent,
                            border: completed ? Border.all(color: AppColors.white(0.12)) : null,
                            boxShadow: completed
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.35),
                                      blurRadius: 22,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            completed ? Icons.replay_rounded : Icons.arrow_forward_rounded,
                            color: completed ? AppColors.text : AppColors.onAccent,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final bool completed;
  const _StatusLine({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.base,
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? AppColors.textSecondary : AppColors.accent,
            boxShadow: completed
                ? null
                : [BoxShadow(color: AppColors.accent.withValues(alpha: 0.7), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          completed ? 'Done tonight' : 'Ready when you are',
          style: AppType.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StreakTile extends StatelessWidget {
  final int streak;
  final String? lastRitualDate;

  const _StreakTile({required this.streak, required this.lastRitualDate});

  @override
  Widget build(BuildContext context) {
    // A streak of N ending on the last ritual date covers exactly the last N
    // nights before it, so the week strip is derived, not stored.
    final now = DateTime.now();
    final streakDays = <String>{};
    final last = lastRitualDate;
    if (last != null && streak > 0) {
      final parts = last.split('-').map(int.parse).toList();
      final end = DateTime(parts[0], parts[1], parts[2]);
      for (var i = 0; i < streak && i < 7; i++) {
        streakDays.add(Dates.key(Dates.addDays(end, -i)));
      }
    }
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Glass(
      radius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(value: streak, style: AppType.number),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  streak == 1 ? 'night' : 'nights',
                  style: AppType.secondary,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('current streak', style: AppType.caption),
          const Spacer(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 6; i >= 0; i--)
                Builder(builder: (context) {
                  final day = Dates.addDays(now, -i);
                  final lit = streakDays.contains(Dates.key(day));
                  final today = i == 0;
                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: Motion.slow,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lit ? AppColors.accent : Colors.transparent,
                          border: Border.all(
                            color: lit
                                ? AppColors.accent
                                : today
                                    ? AppColors.white(0.4)
                                    : AppColors.white(0.12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        letters[day.weekday - 1],
                        style: AppType.caption.copyWith(
                          fontSize: 10,
                          color: today ? AppColors.text : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountUp(value: value, style: AppType.number),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption),
          const Spacer(),
          const SizedBox(height: 14),
          const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            RowIcon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    child: Text(subtitle, key: ValueKey(subtitle), style: AppType.secondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
