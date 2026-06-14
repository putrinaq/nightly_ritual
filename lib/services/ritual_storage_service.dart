import 'package:shared_preferences/shared_preferences.dart';

class RitualStorageService {
  static const String _streakKey = 'streak_days';
  static const String _lastRitualDateKey = 'last_ritual_date';
  static const String _totalRitualsKey = 'total_rituals';
  static const String _customAffirmationsKey = 'custom_affirmations';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Streak Management
  int getStreakDays() {
    return _prefs.getInt(_streakKey) ?? 0;
  }

  Future<void> setStreakDays(int days) async {
    await _prefs.setInt(_streakKey, days);
  }

  String? getLastRitualDate() {
    return _prefs.getString(_lastRitualDateKey);
  }

  Future<void> setLastRitualDate(String date) async {
    await _prefs.setString(_lastRitualDateKey, date);
  }

  // Total Rituals (Spells Cast)
  int getTotalRituals() {
    return _prefs.getInt(_totalRitualsKey) ?? 0;
  }

  Future<void> incrementTotalRituals() async {
    final current = getTotalRituals();
    await _prefs.setInt(_totalRitualsKey, current + 1);
  }

  // Check if ritual was completed today
  bool isRitualCompletedToday() {
    final lastDate = getLastRitualDate();
    if (lastDate == null) return false;
    final today = _formatDate(DateTime.now());
    return lastDate == today;
  }

  // Complete a ritual and update streak
  Future<void> completeRitual() async {
    final today = _formatDate(DateTime.now());
    final lastDate = getLastRitualDate();
    final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));

    int currentStreak = getStreakDays();

    if (lastDate == null) {
      // First ritual ever
      currentStreak = 1;
    } else if (lastDate == yesterday) {
      // Consecutive day - increment streak
      currentStreak++;
    } else if (lastDate != today) {
      // Streak broken - reset to 1
      currentStreak = 1;
    }
    // If lastDate == today, don't change streak (already completed today)

    await setStreakDays(currentStreak);
    await setLastRitualDate(today);
    await incrementTotalRituals();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Custom Affirmations (stored as "text\tcat" per entry)
  List<Map<String, String>> getCustomAffirmations() {
    final list = _prefs.getStringList(_customAffirmationsKey) ?? [];
    return list.map((item) {
      final tabIdx = item.indexOf('\t');
      if (tabIdx < 0) return {'text': item, 'cat': 'Custom'};
      return {
        'text': item.substring(0, tabIdx),
        'cat': item.substring(tabIdx + 1),
      };
    }).toList();
  }

  Future<void> saveCustomAffirmations(
      List<Map<String, String>> affirmations) async {
    final list =
        affirmations.map((a) => '${a['text']}\t${a['cat']}').toList();
    await _prefs.setStringList(_customAffirmationsKey, list);
  }
}
