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
