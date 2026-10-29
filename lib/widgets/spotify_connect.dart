import 'package:flutter/material.dart';

import '../services/spotify_service.dart';
import '../theme/app_theme.dart';
import 'controls.dart';
import 'glass.dart';
import 'motion.dart';

const spotifyGreen = Color(0xFF1ED760);

/// Connection status and action for the person's own Spotify account.
class SpotifyConnectCard extends StatefulWidget {
  const SpotifyConnectCard({super.key});

  @override
  State<SpotifyConnectCard> createState() => _SpotifyConnectCardState();
}

class _SpotifyConnectCardState extends State<SpotifyConnectCard> {
  final _spotify = SpotifyService();
  String? _error;

  Future<void> _connect() async {
    setState(() => _error = null);
    try {
      await _spotify.connect();
    } on SpotifyAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _spotify,
      builder: (context, _) {
        final status = _spotify.status;
        final (title, subtitle) = switch (status) {
          SpotifyStatus.notConfigured => (
              'Spotify',
              'Not set up. Add SPOTIFY_CLIENT_ID to .env to connect your account.',
            ),
          SpotifyStatus.disconnected => (
              'Connect Spotify',
              'Play your playlists from inside the ritual. Playback needs Premium.',
            ),
          SpotifyStatus.connecting => ('Connecting…', 'Finish signing in on the Spotify page.'),
          SpotifyStatus.connected => (
              'Spotify connected',
              _spotify.displayName == null ? 'Ready to play' : 'Signed in as ${_spotify.displayName}',
            ),
        };

        final Widget action = switch (status) {
          SpotifyStatus.notConfigured => const SizedBox.shrink(),
          SpotifyStatus.connecting => const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: spotifyGreen),
              ),
            ),
          SpotifyStatus.disconnected =>
            TextAction(label: 'Connect', color: AppColors.accent, onPressed: _connect),
          SpotifyStatus.connected =>
            TextAction(label: 'Disconnect', onPressed: () => _spotify.disconnect()),
        };

        return Glass(
          radius: AppRadius.lg,
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SpotifyBadge(active: status == SpotifyStatus.connected),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppType.bodyStrong),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppType.secondary),
                        if (status == SpotifyStatus.disconnected) ...[
                          const SizedBox(height: 6),
                          // The exact value Spotify must have under "Redirect
                          // URIs"; a mismatch fails with "redirect_uri: Not
                          // matching configuration".
                          SelectableText(
                            'Redirect URI: ${_spotify.config.redirectUri}',
                            style: AppType.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(duration: Motion.fast, child: KeyedSubtree(key: ValueKey(status), child: action)),
                ],
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.easeOut,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12, right: 10),
                        child: Text(_error!, style: AppType.secondary.copyWith(color: AppColors.danger)),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpotifyBadge extends StatelessWidget {
  final bool active;
  const _SpotifyBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.base,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active ? spotifyGreen.withValues(alpha: 0.14) : AppColors.white(0.05),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: 18,
        color: active ? spotifyGreen : AppColors.textSecondary,
      ),
    );
  }
}

/// Starts a Spotify playlist through the Web API. Falls back to opening the
/// link when there's no device to play on or the account isn't Premium.
class SpotifyPlayButton extends StatefulWidget {
  final String contextUri;
  final String name;
  final Future<void> Function() openFallback;
  final void Function(String message) onMessage;

  const SpotifyPlayButton({
    super.key,
    required this.contextUri,
    required this.name,
    required this.openFallback,
    required this.onMessage,
  });

  @override
  State<SpotifyPlayButton> createState() => _SpotifyPlayButtonState();
}

class _SpotifyPlayButtonState extends State<SpotifyPlayButton> {
  bool _busy = false;
  bool _playing = false;

  Future<void> _press() async {
    if (_busy) return;
    if (_playing) {
      setState(() => _busy = true);
      final ok = await SpotifyService().pause();
      if (mounted) {
        setState(() {
          _busy = false;
          if (ok) _playing = false;
        });
      }
      return;
    }
    setState(() => _busy = true);
    final result = await SpotifyService().play(widget.contextUri);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _playing = result == PlaybackResult.playing;
    });
    switch (result) {
      case PlaybackResult.playing:
        widget.onMessage('Playing ${widget.name}');
      case PlaybackResult.noDevice:
        widget.onMessage('No active Spotify device. Opening the app so you can start it there.');
        await widget.openFallback();
      case PlaybackResult.premiumRequired:
        widget.onMessage('Playback control needs Spotify Premium. Opening the app instead.');
        await widget.openFallback();
      case PlaybackResult.notConnected:
        widget.onMessage('Spotify disconnected. Connect again from your profile.');
      case PlaybackResult.failed:
        widget.onMessage("Couldn't start playback. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _playing ? 'Pause ${widget.name}' : 'Play ${widget.name} on Spotify',
      child: Pressable(
        onTap: _press,
        scale: 0.9,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _playing ? spotifyGreen : spotifyGreen.withValues(alpha: 0.14),
          ),
          alignment: Alignment.center,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _playing ? AppColors.ink : spotifyGreen,
                  ),
                )
              : Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 22,
                  color: _playing ? AppColors.ink : spotifyGreen,
                ),
        ),
      ),
    );
  }
}

/// The person's own Spotify playlists, to pick one instead of pasting a link.
class SpotifyPlaylistPicker extends StatefulWidget {
  final ValueChanged<SpotifyPlaylist> onPick;
  const SpotifyPlaylistPicker({super.key, required this.onPick});

  @override
  State<SpotifyPlaylistPicker> createState() => _SpotifyPlaylistPickerState();
}

class _SpotifyPlaylistPickerState extends State<SpotifyPlaylistPicker> {
  late final Future<List<SpotifyPlaylist>> _future = SpotifyService().myPlaylists();
  String? _picked;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SpotifyPlaylist>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 64,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: spotifyGreen),
              ),
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Text('No playlists found on your Spotify account.', style: AppType.secondary);
        }
        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = items[i];
              final selected = _picked == p.uri;
              return Pressable(
                onTap: () {
                  setState(() => _picked = p.uri);
                  widget.onPick(p);
                },
                scale: 0.95,
                semanticLabel: 'Use ${p.name}',
                child: SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: Motion.fast,
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.white(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? AppColors.accent : AppColors.white(0.08),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: p.imageUrl == null
                            ? const Icon(Icons.graphic_eq_rounded, color: AppColors.textTertiary)
                            : Image.network(
                                p.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.graphic_eq_rounded, color: AppColors.textTertiary),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(
                          color: selected ? AppColors.text : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
