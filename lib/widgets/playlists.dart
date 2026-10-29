import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/playlist_entry.dart';
import '../services/firestore_service.dart';
import '../services/spotify_service.dart';
import '../theme/app_theme.dart';
import 'controls.dart';
import 'glass.dart';
import 'motion.dart';
import 'sheets.dart';
import 'spotify_connect.dart';

/// Opens a playlist in its app (or the browser). Reports failure instead of
/// silently doing nothing.
Future<void> openPlaylist(BuildContext context, PlaylistEntry playlist) async {
  final uri = playlist.uri;
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    showToast(context, "Couldn't open that link. Check that it's a full URL.");
  }
}

/// The signed-in person's playlists, live from Firestore.
///
/// Holds its stream in state so rebuilds don't resubscribe (which flashed a
/// loading state on every parent rebuild).
class PlaylistList extends StatefulWidget {
  final String uid;
  final ScrollController? controller;
  final EdgeInsets padding;

  const PlaylistList({
    super.key,
    required this.uid,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<PlaylistList> createState() => _PlaylistListState();
}

class _PlaylistListState extends State<PlaylistList> {
  late Stream<List<PlaylistEntry>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirestoreService().getPlaylists(widget.uid);
  }

  @override
  void didUpdateWidget(PlaylistList old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _stream = FirestoreService().getPlaylists(widget.uid);
  }

  Future<void> _delete(PlaylistEntry p) async {
    try {
      await FirestoreService().deletePlaylist(widget.uid, p.id!);
      if (!mounted) return;
      showToast(
        context,
        'Removed "${p.name}"',
        actionLabel: 'Undo',
        onAction: () => FirestoreService().addPlaylist(widget.uid, p),
      );
    } catch (_) {
      if (mounted) showToast(context, "Couldn't remove that playlist. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlaylistEntry>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Can't load playlists",
              message: 'Check your connection and reopen this screen.',
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
          );
        }
        final playlists = snap.data!;
        if (playlists.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: EmptyState(
                icon: Icons.graphic_eq_rounded,
                title: 'Nothing to play yet',
                message: 'Save a Spotify or YouTube playlist to open it during your ritual.',
                actionLabel: 'Add playlist',
                onAction: () => showAddPlaylistSheet(context, widget.uid),
              ),
            ),
          );
        }
        return ListView.separated(
          controller: widget.controller,
          padding: widget.padding,
          itemCount: playlists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => Reveal(
            delay: Reveal.stagger(i, stepMs: 40),
            offset: 10,
            child: PlaylistTile(
              key: ValueKey(playlists[i].id),
              playlist: playlists[i],
              onOpen: () => openPlaylist(context, playlists[i]),
              onDelete: () => _delete(playlists[i]),
            ),
          ),
        );
      },
    );
  }
}

class PlaylistTile extends StatelessWidget {
  final PlaylistEntry playlist;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const PlaylistTile({
    super.key,
    required this.playlist,
    required this.onOpen,
    required this.onDelete,
  });

  (String, Color, IconData) get _platform => switch (playlist.platform) {
        'spotify' => ('Spotify', const Color(0xFF1ED760), Icons.graphic_eq_rounded),
        'youtube' => ('YouTube', const Color(0xFFFF5A5A), Icons.play_arrow_rounded),
        _ => ('Link', AppColors.textSecondary, Icons.link_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _platform;
    return Pressable(
      onTap: onOpen,
      semanticLabel: 'Open ${playlist.name} in $label',
      child: Glass(
        radius: AppRadius.md + 2,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            RowIcon(icon, color: AppColors.text),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: AppType.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Brand colour only as a small marker, never as chrome.
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(label, style: AppType.caption),
                    ],
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: SpotifyService(),
              builder: (context, _) {
                final contextUri = playlist.spotifyContextUri;
                if (contextUri != null && SpotifyService().isConnected) {
                  return SpotifyPlayButton(
                    contextUri: contextUri,
                    name: playlist.name,
                    openFallback: () => openPlaylist(context, playlist),
                    onMessage: (m) => showToast(context, m),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.north_east_rounded, size: 16, color: AppColors.textTertiary),
                );
              },
            ),
            Semantics(
              button: true,
              label: 'Remove ${playlist.name}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPlaylistsSheet(BuildContext context, String uid) {
  return showGlassSheet(
    context,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.72,
      child: GlassSheet(
        scrollable: false,
        child: Expanded(
          child: Column(
            children: [
              PageHeader(
                title: 'Playlists',
                subtitle: const Text('Music for the second step of your ritual.'),
                trailing: PillButton(
                  label: 'Add',
                  onPressed: () => showAddPlaylistSheet(ctx, uid),
                ),
              ),
              const SizedBox(height: 20),
              const SpotifyConnectCard(),
              const SizedBox(height: 12),
              Expanded(child: PlaylistList(uid: uid)),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showAddPlaylistSheet(BuildContext context, String uid) {
  return showGlassSheet(context, builder: (_) => _AddPlaylistSheet(uid: uid));
}

class _AddPlaylistSheet extends StatefulWidget {
  final String uid;
  const _AddPlaylistSheet({required this.uid});

  @override
  State<_AddPlaylistSheet> createState() => _AddPlaylistSheetState();
}

class _AddPlaylistSheetState extends State<_AddPlaylistSheet> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  String? get _nameError =>
      _submitted && _nameCtrl.text.trim().isEmpty ? 'Give it a name' : null;

  String? get _urlError {
    if (!_submitted) return null;
    if (_urlCtrl.text.trim().isEmpty) return 'Paste a link';
    if (PlaylistEntry.parseLink(_urlCtrl.text) == null) {
      return "That doesn't look like a link";
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_nameError != null || _urlError != null) return;
    final url = _urlCtrl.text.trim();
    setState(() => _saving = true);
    try {
      await FirestoreService().addPlaylist(
        widget.uid,
        PlaylistEntry(
          name: _nameCtrl.text.trim(),
          url: url,
          platform: PlaylistEntry.detectPlatform(url),
          createdAt: DateTime.now(),
        ),
      ).timeout(const Duration(seconds: 12));
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      // Firestore queues the write offline; it will sync later.
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, "Couldn't save the playlist. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = PlaylistEntry.detectPlatform(_urlCtrl.text);
    return GlassSheet(
      title: 'Add a playlist',
      subtitle: 'Spotify, YouTube, or any link that plays music.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (SpotifyService().isConnected) ...[
            const FieldLabel('From your Spotify'),
            SpotifyPlaylistPicker(
              onPick: (p) => setState(() {
                _nameCtrl.text = p.name;
                _urlCtrl.text = p.url.isNotEmpty ? p.url : p.uri;
              }),
            ),
            const SizedBox(height: 20),
          ],
          const FieldLabel('Name'),
          AppTextField(
            controller: _nameCtrl,
            hint: 'Slow piano for winding down',
            maxLength: 60,
            errorText: _nameError,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _submitted ? setState(() {}) : null,
          ),
          const SizedBox(height: 18),
          FieldLabel(
            'Link',
            trailing: _urlCtrl.text.isEmpty
                ? null
                : switch (platform) {
                    'spotify' => 'Spotify',
                    'youtube' => 'YouTube',
                    _ => 'Web link',
                  },
          ),
          AppTextField(
            controller: _urlCtrl,
            hint: 'open.spotify.com/playlist/…',
            keyboardType: TextInputType.url,
            errorText: _urlError,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: 'Save playlist', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
