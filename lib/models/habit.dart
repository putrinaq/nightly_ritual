import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String name;
  final String emoji;
  final List<String> tags;
  final List<String> completedDates; // 'yyyy-MM-dd' format
  final DateTime createdAt;

  Habit({
    this.id = '',
    required this.name,
    this.emoji = '✨',
    this.tags = const [],
    this.completedDates = const [],
    required this.createdAt,
  });

  factory Habit.fromMap(Map<String, dynamic> map, String id) {
    return Habit(
      id: id,
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '✨',
      tags: List<String>.from(map['tags'] as List? ?? []),
      completedDates: List<String>.from(map['completedDates'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'emoji': emoji,
      'tags': tags,
      'completedDates': completedDates,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static String dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String get todayString => dateString(DateTime.now());

  bool get isCompletedToday => completedDates.contains(todayString);

  bool isCompletedOn(DateTime date) => completedDates.contains(dateString(date));

  int get currentStreak {
    if (completedDates.isEmpty) return 0;
    final today = dateString(DateTime.now());
    final yesterday = dateString(DateTime.now().subtract(const Duration(days: 1)));
    if (!completedDates.contains(today) && !completedDates.contains(yesterday)) {
      return 0;
    }
    int streak = 0;
    DateTime date = completedDates.contains(today)
        ? DateTime.now()
        : DateTime.now().subtract(const Duration(days: 1));
    while (completedDates.contains(dateString(date))) {
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
