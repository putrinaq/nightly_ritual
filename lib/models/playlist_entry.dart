import 'package:cloud_firestore/cloud_firestore.dart';

class PlaylistEntry {
  final String? id;
  final String name;
  final String url;
  final String platform; // 'spotify', 'youtube', 'other'
  final DateTime createdAt;

  const PlaylistEntry({
    this.id,
    required this.name,
    required this.url,
    required this.platform,
    required this.createdAt,
  });

  static String detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('spotify.com') || lower.startsWith('spotify:')) {
      return 'spotify';
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'youtube';
    }
    return 'other';
  }

  /// Parses a pasted link into something launchable. People paste
  /// "open.spotify.com/…" without a scheme, which `Uri.parse` treats as a
  /// relative path, so a missing scheme defaults to https.
  static Uri? parseLink(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('spotify:')) return Uri.tryParse(text);
    final withScheme = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  Uri? get uri => parseLink(url);

  /// `spotify:playlist:…` for Spotify links (also albums, artists, shows),
  /// so playback can be started through the Web API. Null for other links.
  String? get spotifyContextUri => spotifyContextUriFor(url);

  static String? spotifyContextUriFor(String link) {
    final text = link.trim();
    final direct = RegExp(r'^spotify:(playlist|album|artist|show):([A-Za-z0-9]+)$').firstMatch(text);
    if (direct != null) return 'spotify:${direct[1]}:${direct[2]}';
    final u = parseLink(text);
    if (u == null || !u.host.endsWith('spotify.com')) return null;
    // Paths look like /playlist/ID or /intl-xx/playlist/ID.
    final segs = u.pathSegments.where((s) => !s.startsWith('intl-')).toList();
    if (segs.length < 2) return null;
    const kinds = {'playlist', 'album', 'artist', 'show'};
    if (!kinds.contains(segs[0])) return null;
    return 'spotify:${segs[0]}:${segs[1]}';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'platform': platform,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PlaylistEntry.fromMap(Map<String, dynamic> map, String id) {
    return PlaylistEntry(
      id: id,
      name: map['name'] as String? ?? '',
      url: map['url'] as String? ?? '',
      platform: map['platform'] as String? ?? 'other',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
