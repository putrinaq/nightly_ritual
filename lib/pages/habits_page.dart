import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../services/firestore_service.dart';

const _emojiOptions = [
  '✨', '🌙', '💜', '🌹', '💫', '🔮', '🌿', '🕯️',
  '👑', '🦋', '💎', '🌊', '🔥', '🌸', '⚡', '🙏',
  '📿', '🌺', '🍃', '🌟', '💆', '🧘', '📖', '💧',
  '🏃', '💪', '🥗', '😴', '🎯', '📝', '🎨', '🎵',
];

const _habitSuggestedTags = [
  '🌙 Evening', '🌅 Morning', '💜 Self-care', '🧘 Mindfulness',
  '💪 Fitness', '📖 Learning', '🌿 Wellness', '💫 Spiritual',
  '🥗 Nutrition', '😴 Sleep',
];

class HabitsPage extends StatelessWidget {
  final User user;
  const HabitsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Habit>>(
      stream: FirestoreService().getHabits(user.uid),
      builder: (context, snapshot) {
        final habits = snapshot.data ?? [];
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;
        final doneCount = habits.where((h) => h.isCompletedToday).length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Habits',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          if (habits.isNotEmpty)
                            Text(
                              '$doneCount / ${habits.length} done today',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showAddHabit(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add,
                                  color: Color(0xFF22C55E), size: 16),
                              SizedBox(width: 4),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF22C55E),
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (habits.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF22C55E),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No habits yet',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap New to start tracking a habit',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Pending habits
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final pending = habits
                            .where((h) => !h.isCompletedToday)
                            .toList();
                        return _HabitTodoItem(
                          habit: pending[index],
                          userId: user.uid,
                          onDelete: () =>
                              _confirmDelete(context, pending[index]),
                        );
                      },
                      childCount: habits
                          .where((h) => !h.isCompletedToday)
                          .length,
                    ),
                  ),
                ),
                // Completed section
                if (habits.any((h) => h.isCompletedToday)) ...[
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final done = habits
                              .where((h) => h.isCompletedToday)
                              .toList();
                          return _HabitTodoItem(
                            habit: done[index],
                            userId: user.uid,
                            onDelete: () =>
                                _confirmDelete(context, done[index]),
                          );
                        },
                        childCount: habits
                            .where((h) => h.isCompletedToday)
                            .length,
                      ),
                    ),
                  ),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Habit habit) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Remove "${habit.name}"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService().deleteHabit(user.uid, habit.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddHabit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddHabitSheet(userId: user.uid),
    );
  }
}

// ── Habit Todo Item ───────────────────────────────────────────────────────────

class _HabitTodoItem extends StatelessWidget {
  final Habit habit;
  final String userId;
  final VoidCallback onDelete;

  const _HabitTodoItem({
    required this.habit,
    required this.userId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = habit.isCompletedToday;

    return GestureDetector(
      onTap: () => FirestoreService().toggleHabitDate(
        userId,
        habit.id,
        Habit.todayString,
        !done,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done
                ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFF22C55E)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done
                      ? const Color(0xFF22C55E)
                      : Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            // Emoji
            Text(habit.emoji,
                style: TextStyle(
                    fontSize: 20,
                    color: done
                        ? Colors.white.withValues(alpha: 0.4)
                        : null)),
            const SizedBox(width: 10),
            // Name + streak + tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      color: done
                          ? Colors.grey[600]
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey[700],
                    ),
                  ),
                  if (habit.currentStreak > 0 && !done) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🔥 ${habit.currentStreak} day streak',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                  if (habit.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: habit.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.05),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(t,
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            // Delete
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close,
                    color: Colors.grey[700], size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Habit Sheet ───────────────────────────────────────────────────────────

class _AddHabitSheet extends StatefulWidget {
  final String userId;
  const _AddHabitSheet({required this.userId});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  String _selectedEmoji = '✨';
  final List<String> _tags = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirestoreService().addHabit(
        widget.userId,
        Habit(
          name: name,
          emoji: _selectedEmoji,
          tags: _tags,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: Color(0xFF22C55E), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'New Habit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _label('EMOJI'),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _emojiOptions.length,
                itemBuilder: (context, i) {
                  final emoji = _emojiOptions[i];
                  final selected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF22C55E)
                                .withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF22C55E)
                                  .withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _label('HABIT NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Meditate, Journal, Walk...',
                hintStyle:
                    TextStyle(color: Colors.grey[600], fontSize: 14),
                prefixText: '$_selectedEmoji  ',
                prefixStyle: const TextStyle(fontSize: 16),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF22C55E)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            _label('TAGS (OPTIONAL)'),
            const SizedBox(height: 8),
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map((t) => GestureDetector(
                          onTap: () => setState(() => _tags.remove(t)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t,
                                    style: const TextStyle(
                                        color: Color(0xFF86EFAC),
                                        fontSize: 11)),
                                const SizedBox(width: 4),
                                const Icon(Icons.close,
                                    color: Color(0xFF86EFAC), size: 12),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    onSubmitted: _addTag,
                    decoration: InputDecoration(
                      hintText: 'Add tag...',
                      hintStyle: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF22C55E)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addTag(_tagCtrl.text),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add,
                        color: Color(0xFF22C55E), size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _habitSuggestedTags.map((tag) {
                final sel = _tags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(
                      () => sel ? _tags.remove(tag) : _tags.add(tag)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF22C55E)
                              .withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF22C55E)
                                .withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFF86EFAC)
                            : Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                onPressed: _saving ? null : _save,
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Add Habit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Colors.grey[600],
      ),
    );
  }
}
