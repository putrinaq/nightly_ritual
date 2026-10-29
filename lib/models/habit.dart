import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/dates.dart';

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

  static String dateString(DateTime d) => Dates.key(d);

  static String get todayString => Dates.todayKey();

  bool get isCompletedToday => completedDates.contains(todayString);

  bool isCompletedOn(DateTime date) => completedDates.contains(dateString(date));

  int get currentStreak => streakAsOf(DateTime.now());

  /// Consecutive completed days ending today, or ending yesterday when today
  /// isn't done yet (the streak is still alive until midnight).
  int streakAsOf(DateTime now) {
    if (completedDates.isEmpty) return 0;
    final done = completedDates.toSet();
    var day = Dates.dayOnly(now);
    if (!done.contains(Dates.key(day))) day = Dates.addDays(day, -1);
    var streak = 0;
    while (done.contains(Dates.key(day))) {
      streak++;
      day = Dates.addDays(day, -1);
    }
    return streak;
  }
}
