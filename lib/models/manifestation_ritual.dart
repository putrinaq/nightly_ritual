import 'package:cloud_firestore/cloud_firestore.dart';

class ManifestationRitual {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ManifestationRitual({
    this.id = '',
    required this.title,
    required this.description,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory ManifestationRitual.fromMap(Map<String, dynamic> map, String id) {
    return ManifestationRitual(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  ManifestationRitual copyWith({
    String? title,
    String? description,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return ManifestationRitual(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? List<String>.from(this.tags),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
