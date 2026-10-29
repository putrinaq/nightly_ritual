import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/shell.dart';
import '../widgets/sheets.dart';

const _emojiOptions = [
  '✨', '🌙', '🕯️', '🌿', '💧', '📖', '📝', '🧘',
  '🛁', '🍵', '🌸', '🎵', '😴', '🏃', '💪', '🥗',
  '🙏', '🌊', '🔥', '🎨', '🧴', '☕', '🚶', '📵',
];

const _suggestedTags = [
  'Evening', 'Morning', 'Self-care', 'Mindfulness', 'Movement',
  'Learning', 'Sleep', 'Nutrition',
];

class HabitsPage extends StatefulWidget {
  final User user;
  const HabitsPage({super.key, required this.user});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  late Stream<List<Habit>> _stream = FirestoreService().getHabits(widget.user.uid);

  @override
  void didUpdateWidget(HabitsPage old) {
    super.didUpdateWidget(old);
    if (old.user.uid != widget.user.uid) {
      _stream = FirestoreService().getHabits(widget.user.uid);
    }
  }

  Future<void> _toggle(Habit habit) async {
    final done = habit.isCompletedToday;
    if (!done) HapticFeedback.lightImpact();
    try {
      await FirestoreService()
          .toggleHabitDate(widget.user.uid, habit.id, Habit.todayString, !done);
    } catch (_) {
      if (mounted) showToast(context, "Couldn't update ${habit.name}. Try again.");
    }
  }

  Future<void> _delete(Habit habit) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete "${habit.name}"?',
      message: 'Its streak and history go with it. This can\'t be undone.',
      confirmLabel: 'Delete habit',
    );
    if (!ok) return;
    try {
      await FirestoreService().deleteHabit(widget.user.uid, habit.id);
    } catch (_) {
      if (mounted) showToast(context, "Couldn't delete it. Try again.");
    }
  }

  void _add() => showGlassSheet(context, builder: (_) => _AddHabitSheet(userId: widget.user.uid));

  @override
  Widget build(BuildContext context) {
    final bottom = ShellInsets.bottomOf(context);
    return StreamBuilder<List<Habit>>(
      stream: _stream,
      builder: (context, snap) {
        final habits = snap.data ?? const <Habit>[];
        final loading = !snap.hasData && !snap.hasError;
        final doneCount = habits.where((h) => h.isCompletedToday).length;

        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Reveal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          title: 'Habits',
                          subtitle: Text(
                            habits.isEmpty
                                ? 'Small things, every day.'
                                : doneCount == habits.length
                                    ? 'All ${habits.length} done today.'
                                    : '$doneCount of ${habits.length} done today',
                          ),
                          trailing: PillButton(label: 'New', onPressed: _add),
                        ),
                        if (habits.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _ProgressBar(value: doneCount / habits.length),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (snap.hasError)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Can't load habits",
                      message: 'Check your connection and come back to this tab.',
                    ),
                  ),
                )
              else if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    ),
                  ),
                )
              else if (habits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: Center(
                      child: EmptyState(
                        icon: Icons.check_rounded,
                        title: 'Start with one',
                        message: 'Something small you can do tonight: tea instead of scrolling, ten pages, a warm shower.',
                        actionLabel: 'New habit',
                        onAction: _add,
                      ),
                    ),
                  ),
                )
              else
                // One list in a stable order. Completed habits stay in place
                // and dim, instead of jumping to another section on tap.
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: habits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => Reveal(
                      key: ValueKey(habits[i].id),
                      delay: Reveal.stagger(i, stepMs: 45),
                      child: _HabitRow(
                        habit: habits[i],
                        onToggle: () => _toggle(habits[i]),
                        onDelete: () => _delete(habits[i]),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottom + 8)),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.hairline)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: Motion.slow,
              curve: Motion.easeOut,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accentDeep, AppColors.accent]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _HabitRow({required this.habit, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final done = habit.isCompletedToday;
    final streak = habit.currentStreak;
    final today = DateTime.now();

    return Pressable(
      onTap: onToggle,
      onLongPress: onDelete,
      scale: 0.985,
      semanticLabel: '${habit.name}, ${done ? 'done' : 'not done'} today',
      child: Glass(
        radius: AppRadius.lg,
        fill: done ? 0.03 : 0.045,
        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        child: Row(
          children: [
            _CheckOrb(done: done),
            const SizedBox(width: 14),
            AnimatedOpacity(
              duration: Motion.base,
              opacity: done ? 0.55 : 1,
              child: Text(habit.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedOpacity(
                duration: Motion.base,
                opacity: done ? 0.55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: AppType.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        for (var i = 6; i >= 0; i--) ...[
                          _DayDot(
                            done: habit.isCompletedOn(Dates.addDays(today, -i)),
                            today: i == 0,
                          ),
                          const SizedBox(width: 4),
                        ],
                        const SizedBox(width: 6),
                        if (streak > 1)
                          Flexible(
                            child: Text(
                              '$streak-day streak',
                              style: AppType.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    if (habit.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: habit.tags.take(3).map(TagLabel.new).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Delete ${habit.name}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool done;
  final bool today;
  const _DayDot({required this.done, required this.today});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.base,
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.accent : AppColors.white(today ? 0.0 : 0.1),
        border: today && !done ? Border.all(color: AppColors.white(0.35)) : null,
      ),
    );
  }
}

/// The check. Fills with candlelight and pops slightly when completed;
/// unchecking just fades back — undoing shouldn't celebrate.
class _CheckOrb extends StatelessWidget {
  final bool done;
  const _CheckOrb({required this.done});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(done),
      tween: Tween(begin: done && !reduced ? 0.78 : 1, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.easeOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: done ? AppColors.accent : AppColors.white(0.25),
            width: 1.5,
          ),
          boxShadow: done
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 14)]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: done
              ? const Icon(Icons.check_rounded, key: ValueKey(true), size: 17, color: AppColors.onAccent)
              : const SizedBox(key: ValueKey(false)),
        ),
      ),
    );
  }
}

class _AddHabitSheet extends StatefulWidget {
  final String userId;
  const _AddHabitSheet({required this.userId});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  String _emoji = _emojiOptions.first;
  final List<String> _tags = [];
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag([String? raw]) {
    final tag = (raw ?? _tagCtrl.text).trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tagCtrl.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    _addTag();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirestoreService()
          .addHabit(
            widget.userId,
            Habit(name: name, emoji: _emoji, tags: _tags, createdAt: DateTime.now()),
          )
          .timeout(const Duration(seconds: 12));
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      if (mounted) Navigator.pop(context); // queued offline; syncs later
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save. Check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = _tags.where((t) => !_suggestedTags.contains(t)).toList();
    return GlassSheet(
      title: 'New habit',
      subtitle: 'Pick something you can do in a few minutes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Name'),
          AppTextField(
            controller: _nameCtrl,
            hint: 'Read ten pages',
            maxLength: 60,
            autofocus: true,
            textInputAction: TextInputAction.done,
            errorText: _submitted && _nameCtrl.text.trim().isEmpty ? 'Give it a name' : null,
            onChanged: (_) => _submitted ? setState(() {}) : null,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Text(_emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Icon'),
          SizedBox(
            height: 104,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _emojiOptions.length,
              itemBuilder: (context, i) {
                final e = _emojiOptions[i];
                final selected = e == _emoji;
                return Pressable(
                  onTap: () => setState(() => _emoji = e),
                  scale: 0.9,
                  semanticLabel: 'Use $e',
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accentTint(0.16) : AppColors.white(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.accent.withValues(alpha: 0.6) : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Tags', trailing: 'Optional'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in custom)
                ChoiceChipX(
                  label: t,
                  selected: true,
                  trailingIcon: Icons.close_rounded,
                  onTap: () => setState(() => _tags.remove(t)),
                ),
              for (final t in _suggestedTags)
                ChoiceChipX(
                  label: t,
                  selected: _tags.contains(t),
                  onTap: () => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _tagCtrl,
            hint: 'Add your own tag',
            maxLength: 24,
            onSubmitted: _addTag,
            prefix: const Icon(Icons.add_rounded, size: 18, color: AppColors.textTertiary),
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.easeOut,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_error!, style: AppType.secondary.copyWith(color: AppColors.danger)),
                  ),
          ),
          const SizedBox(height: 26),
          PrimaryButton(label: 'Add habit', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
