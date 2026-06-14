import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/manifestation_ritual.dart';
import '../services/firestore_service.dart';

const _suggestedTags = [
  '🌙 Moon Work',
  '✨ Manifestation',
  '💜 Self-love',
  '🔮 Intuition',
  '🌹 Attraction',
  '💫 Abundance',
  '🌿 Healing',
  '🕯️ Ritual',
  '👑 Power',
  '🦋 Transformation',
  '💎 Clarity',
  '🌊 Flow',
  '🔥 Passion',
  '🌸 Beauty',
  '⚡ Energy',
  '🙏 Gratitude',
];

class RitualsPage extends StatelessWidget {
  final User user;
  const RitualsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ManifestationRitual>>(
      stream: FirestoreService().getRituals(user.uid),
      builder: (context, snapshot) {
        final rituals = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

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
                      const Text(
                        'Manifestations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showRitualSheet(context, null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add,
                                  color: Color(0xFFA855F7), size: 16),
                              SizedBox(width: 4),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: Color(0xFFA855F7),
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFA855F7),
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (rituals.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_outlined,
                            color: Color(0xFFA855F7),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No manifestations yet',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap New to write your first intention',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ritual = rituals[index];
                        return _RitualCard(
                          ritual: ritual,
                          onEdit: () => _showRitualSheet(context, ritual),
                          onDelete: () =>
                              _confirmDelete(context, ritual),
                        );
                      },
                      childCount: rituals.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ManifestationRitual ritual) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Manifestation'),
        content: Text('Remove "${ritual.title}"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService().deleteRitual(user.uid, ritual.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRitualSheet(BuildContext context, ManifestationRitual? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RitualSheet(
        userId: user.uid,
        existing: existing,
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _RitualCard extends StatelessWidget {
  final ManifestationRitual ritual;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RitualCard({
    required this.ritual,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ritual.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
            if (ritual.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ritual.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            if (ritual.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ritual.tags.map((tag) => _TagChip(tag: tag)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFA855F7).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFA855F7).withValues(alpha: 0.2)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Color(0xFFD8B4FE),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────

class _RitualSheet extends StatefulWidget {
  final String userId;
  final ManifestationRitual? existing;

  const _RitualSheet({required this.userId, this.existing});

  @override
  State<_RitualSheet> createState() => _RitualSheetState();
}

class _RitualSheetState extends State<_RitualSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _tagCtrl;
  late List<String> _tags;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _tagCtrl = TextEditingController();
    _tags = List<String>.from(e?.tags ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    try {
      final svc = FirestoreService();
      if (widget.existing == null) {
        await svc.addRitual(
          widget.userId,
          ManifestationRitual(
            title: title,
            description: '',
            tags: _tags,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await svc.updateRitual(
          widget.userId,
          widget.existing!.copyWith(
            title: title,
            tags: _tags,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
            // Handle
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Color(0xFFA855F7), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'Edit Manifestation' : 'New Manifestation',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Title
            _sheetLabel('INTENTION'),
            const SizedBox(height: 8),
            _sheetField(
              controller: _titleCtrl,
              hint: 'I am...',
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            // Selected tags
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map((tag) => _RemovableTag(
                          tag: tag,
                          onRemove: () => setState(() => _tags.remove(tag)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Custom tag input
            Row(
              children: [
                Expanded(
                  child: _sheetField(
                    controller: _tagCtrl,
                    hint: 'Type a custom tag...',
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addTag,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: Color(0xFFD8B4FE),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sheetLabel('QUICK TAGS'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedTags.map((tag) {
                final selected = _tags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _tags.remove(tag);
                      } else {
                        _tags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFA855F7).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFA855F7).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFD8B4FE)
                            : Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                onPressed: _saving ? null : _save,
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
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
                        : Text(
                            isEdit ? 'Save Changes' : 'Add Manifestation',
                            style: const TextStyle(
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

  Widget _sheetLabel(String text) {
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

  Widget _sheetField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA855F7)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _RemovableTag extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;

  const _RemovableTag({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFA855F7).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(
                color: Color(0xFFD8B4FE),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                color: Color(0xFFD8B4FE), size: 14),
          ),
        ],
      ),
    );
  }
}
