import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/manifestation_ritual.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/shell.dart';
import '../widgets/sheets.dart';

const _suggestedTags = [
  'Abundance', 'Self-love', 'Clarity', 'Healing', 'Confidence', 'Gratitude',
  'Love', 'Career', 'Calm', 'Courage', 'Release', 'Home',
];

/// The person's intentions — the statements read aloud during "Cast".
class RitualsPage extends StatefulWidget {
  final User user;
  const RitualsPage({super.key, required this.user});

  @override
  State<RitualsPage> createState() => _RitualsPageState();
}

class _RitualsPageState extends State<RitualsPage> {
  // Held in state: creating the stream inside build() resubscribed on every
  // rebuild and flashed the loading state each time the tab changed.
  late Stream<List<ManifestationRitual>> _stream =
      FirestoreService().getRituals(widget.user.uid);

  @override
  void didUpdateWidget(RitualsPage old) {
    super.didUpdateWidget(old);
    if (old.user.uid != widget.user.uid) {
      _stream = FirestoreService().getRituals(widget.user.uid);
    }
  }

  void _openSheet([ManifestationRitual? existing]) {
    showGlassSheet(
      context,
      builder: (_) => _IntentionSheet(userId: widget.user.uid, existing: existing),
    );
  }

  Future<void> _delete(ManifestationRitual ritual) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete this intention?',
      message: 'It won\'t appear in your ritual any more.',
      confirmLabel: 'Delete intention',
    );
    if (!ok) return;
    try {
      await FirestoreService().deleteRitual(widget.user.uid, ritual.id);
    } catch (_) {
      if (mounted) showToast(context, "Couldn't delete it. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = ShellInsets.bottomOf(context);
    return StreamBuilder<List<ManifestationRitual>>(
      stream: _stream,
      builder: (context, snap) {
        final rituals = snap.data ?? const <ManifestationRitual>[];
        final loading = !snap.hasData && !snap.hasError;

        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Reveal(
                    child: PageHeader(
                      title: 'Intentions',
                      subtitle: Text(
                        rituals.isEmpty
                            ? 'What you\'ll read aloud each night.'
                            : '${rituals.length} ${rituals.length == 1 ? 'intention' : 'intentions'} · read during Cast',
                      ),
                      trailing: PillButton(label: 'New', onPressed: () => _openSheet()),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              if (snap.hasError)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Can't load intentions",
                      message: 'Check your connection. Anything you add offline will sync later.',
                    ),
                  ),
                )
              else if (loading)
                const SliverToBoxAdapter(child: _SkeletonList())
              else if (rituals.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: Center(
                      child: EmptyState(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Write your first intention',
                        message: 'Short, present tense, in your own words: "I am calm and well rested."',
                        actionLabel: 'New intention',
                        onAction: () => _openSheet(),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: rituals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => Reveal(
                      key: ValueKey(rituals[i].id),
                      delay: Reveal.stagger(i, stepMs: 45),
                      child: _IntentionCard(
                        ritual: rituals[i],
                        onEdit: () => _openSheet(rituals[i]),
                        onDelete: () => _delete(rituals[i]),
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

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: 0.5 + 0.5 * Curves.easeInOut.transform(_c.value),
          child: Column(
            children: [
              for (final h in [96.0, 120.0, 84.0]) ...[
                Glass(radius: AppRadius.lg, child: SizedBox(height: h, width: double.infinity)),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentionCard extends StatelessWidget {
  final ManifestationRitual ritual;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IntentionCard({required this.ritual, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onEdit,
      onLongPress: onDelete,
      scale: 0.985,
      semanticLabel: 'Edit intention',
      child: Glass(
        radius: AppRadius.lg,
        padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ritual.title,
                    style: AppType.heading.copyWith(fontSize: 23, height: 1.22),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ritual.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      ritual.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.secondary,
                    ),
                  ],
                  if (ritual.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ritual.tags.map(TagLabel.new).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Delete intention',
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

class _IntentionSheet extends StatefulWidget {
  final String userId;
  final ManifestationRitual? existing;

  const _IntentionSheet({required this.userId, this.existing});

  @override
  State<_IntentionSheet> createState() => _IntentionSheetState();
}

class _IntentionSheetState extends State<_IntentionSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
  final _tagCtrl = TextEditingController();
  late final List<String> _tags = List<String>.from(widget.existing?.tags ?? const []);
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
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
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    _addTag(); // a typed-but-unadded tag shouldn't be lost on save
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final svc = FirestoreService();
      final Future<void> write = _isEdit
          ? svc.updateRitual(
              widget.userId,
              widget.existing!.copyWith(title: title, tags: _tags, updatedAt: DateTime.now()),
            )
          : svc.addRitual(
              widget.userId,
              ManifestationRitual(
                title: title,
                description: '',
                tags: _tags,
                createdAt: DateTime.now(),
              ),
            );
      await write.timeout(const Duration(seconds: 12));
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
      title: _isEdit ? 'Edit intention' : 'New intention',
      subtitle: 'Write it as if it\'s already true.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _titleCtrl,
            hint: 'I am…',
            serif: true,
            maxLines: 4,
            maxLength: 220,
            autofocus: !_isEdit,
            errorText: _submitted && _titleCtrl.text.trim().isEmpty ? 'Write a few words first' : null,
            onChanged: (_) => _submitted ? setState(() {}) : null,
          ),
          const SizedBox(height: 22),
          const FieldLabel('Tags'),
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
            textInputAction: TextInputAction.done,
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
          PrimaryButton(
            label: _isEdit ? 'Save changes' : 'Add intention',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
