import 'package:shared_preferences/shared_preferences.dart';

import '../utils/dates.dart';

/// Local ritual progress (streak, last ritual date, total count).
///
/// Values are scoped per signed-in account so two people sharing a device
/// don't share a streak. Progress saved before scoping existed (unprefixed
/// keys) is handed to the first account that signs in, then removed.
class RitualStorageService {
  static const String _streakKey = 'streak_days';
  static const String _lastRitualDateKey = 'last_ritual_date';
  static const String _totalRitualsKey = 'total_rituals';
  static const String _legacyAffirmationsKey = 'custom_affirmations';

  late SharedPreferences _prefs;
  String _scope = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Custom affirmations were replaced by Firestore intentions.
    await _prefs.remove(_legacyAffirmationsKey);
  }

  /// Points storage at [uid]'s progress, migrating legacy progress once.
  Future<void> useAccount(String uid) async {
    _scope = 'u:$uid:';
    final hasLegacy = _prefs.containsKey(_lastRitualDateKey) ||
        _prefs.containsKey(_totalRitualsKey);
    final hasScoped = _prefs.containsKey(_k(_lastRitualDateKey)) ||
        _prefs.containsKey(_k(_totalRitualsKey));
    if (hasLegacy && !hasScoped) {
      final streak = _prefs.getInt(_streakKey);
      final last = _prefs.getString(_lastRitualDateKey);
      final total = _prefs.getInt(_totalRitualsKey);
      if (streak != null) await _prefs.setInt(_k(_streakKey), streak);
      if (last != null) await _prefs.setString(_k(_lastRitualDateKey), last);
      if (total != null) await _prefs.setInt(_k(_totalRitualsKey), total);
    }
    if (hasLegacy) {
      await _prefs.remove(_streakKey);
      await _prefs.remove(_lastRitualDateKey);
      await _prefs.remove(_totalRitualsKey);
    }
  }

  String _k(String key) => '$_scope$key';

  /// The live streak. The stored count only stays valid while the last ritual
  /// was today or yesterday; after a missed night it reads as 0.
  int getStreakDays([DateTime? now]) {
    final last = getLastRitualDate();
    if (last == null) return 0;
    if (last != Dates.todayKey(now) && last != Dates.yesterdayKey(now)) {
      return 0;
    }
    return _prefs.getInt(_k(_streakKey)) ?? 0;
  }

  String? getLastRitualDate() => _prefs.getString(_k(_lastRitualDateKey));

  int getTotalRituals() => _prefs.getInt(_k(_totalRitualsKey)) ?? 0;

  bool isRitualCompletedToday([DateTime? now]) =>
      getLastRitualDate() == Dates.todayKey(now);

  /// Records a completed ritual. Repeating on the same night counts toward
  /// the total but doesn't extend the streak.
  Future<void> completeRitual([DateTime? now]) async {
    final today = Dates.todayKey(now);
    final last = getLastRitualDate();
    var streak = _prefs.getInt(_k(_streakKey)) ?? 0;

    if (last == today) {
      streak = streak == 0 ? 1 : streak;
    } else if (last == Dates.yesterdayKey(now)) {
      streak++;
    } else {
      streak = 1;
    }

    await _prefs.setInt(_k(_streakKey), streak);
    await _prefs.setString(_k(_lastRitualDateKey), today);
    await _prefs.setInt(_k(_totalRitualsKey), getTotalRituals() + 1);
  }
}
