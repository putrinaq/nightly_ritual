import 'package:flutter_test/flutter_test.dart';
import 'package:nightly_ritual/models/habit.dart';
import 'package:nightly_ritual/models/playlist_entry.dart';
import 'package:nightly_ritual/services/moon_phase_service.dart';
import 'package:nightly_ritual/services/ritual_storage_service.dart';
import 'package:nightly_ritual/utils/dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Dates', () {
    test('addDays steps calendar days, not 24h blocks', () {
      // Crosses a month boundary and a typical DST weekend.
      expect(Dates.key(Dates.addDays(DateTime(2026, 3, 1, 0, 30), -1)), '2026-02-28');
      expect(Dates.key(Dates.addDays(DateTime(2026, 3, 30, 0, 30), -1)), '2026-03-29');
      expect(Dates.key(Dates.addDays(DateTime(2026, 10, 26, 23, 30), 1)), '2026-10-27');
    });

    test('time formats 12-hour clock', () {
      expect(Dates.time(0, 5), '12:05 AM');
      expect(Dates.time(12, 0), '12:00 PM');
      expect(Dates.time(21, 30), '9:30 PM');
    });
  });

  group('Habit streak', () {
    Habit habit(List<String> days) =>
        Habit(name: 'Read', completedDates: days, createdAt: DateTime(2026));

    final now = DateTime(2026, 10, 17, 22);

    test('counts back from today', () {
      final h = habit(['2026-10-17', '2026-10-16', '2026-10-15', '2026-10-13']);
      expect(h.streakAsOf(now), 3);
    });

    test('stays alive through today when yesterday was done', () {
      expect(habit(['2026-10-16', '2026-10-15']).streakAsOf(now), 2);
    });

    test('is zero once a day is missed', () {
      expect(habit(['2026-10-15', '2026-10-14']).streakAsOf(now), 0);
    });
  });

  group('RitualStorageService', () {
    Future<RitualStorageService> make(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      final s = RitualStorageService();
      await s.init();
      return s;
    }

    test('streak builds on consecutive nights and repeats do not inflate it', () async {
      final s = await make({});
      await s.useAccount('a');
      await s.completeRitual(DateTime(2026, 10, 15, 22));
      await s.completeRitual(DateTime(2026, 10, 16, 22));
      await s.completeRitual(DateTime(2026, 10, 16, 23));
      expect(s.getStreakDays(DateTime(2026, 10, 16, 23)), 2);
      expect(s.getTotalRituals(), 3);
    });

    test('a broken streak reads as zero before the next ritual', () async {
      final s = await make({});
      await s.useAccount('a');
      await s.completeRitual(DateTime(2026, 10, 10, 22));
      expect(s.getStreakDays(DateTime(2026, 10, 11, 9)), 1);
      expect(s.getStreakDays(DateTime(2026, 10, 13, 9)), 0);
      await s.completeRitual(DateTime(2026, 10, 13, 22));
      expect(s.getStreakDays(DateTime(2026, 10, 13, 22)), 1);
    });

    test('progress is per account, and legacy progress migrates once', () async {
      final s = await make({
        'streak_days': 4,
        'last_ritual_date': Dates.todayKey(),
        'total_rituals': 9,
      });
      await s.useAccount('first');
      expect(s.getTotalRituals(), 9);
      expect(s.getStreakDays(), 4);

      await s.useAccount('second');
      expect(s.getTotalRituals(), 0);
      expect(s.getStreakDays(), 0);
    });
  });

  group('Moon phase', () {
    test('matches known full and new moons', () {
      final full = MoonPhaseService.getMoonPhaseForDate(DateTime.utc(2024, 4, 23, 23, 49));
      expect(full.phase, MoonPhaseType.fullMoon);
      expect(full.illumination, greaterThan(0.97));

      final newMoon = MoonPhaseService.getMoonPhaseForDate(DateTime.utc(2024, 4, 8, 18, 21));
      expect(newMoon.phase, MoonPhaseType.newMoon);
      expect(newMoon.illumination, lessThan(0.03));
    });

    test('cycle fraction is waxing before full, waning after', () {
      final waxing = MoonPhaseService.getMoonPhaseForDate(DateTime.utc(2024, 4, 15, 19, 13));
      expect(waxing.phase, MoonPhaseType.firstQuarter);
      expect(waxing.cycleFraction, inInclusiveRange(0.2, 0.3));
    });
  });

  group('Playlist links', () {
    test('adds a missing scheme', () {
      expect(PlaylistEntry.parseLink('open.spotify.com/playlist/abc').toString(),
          'https://open.spotify.com/playlist/abc');
    });

    test('accepts spotify URIs and rejects junk', () {
      expect(PlaylistEntry.parseLink('spotify:playlist:abc'), isNotNull);
      expect(PlaylistEntry.parseLink('not a link'), isNull);
      expect(PlaylistEntry.parseLink(''), isNull);
      expect(PlaylistEntry.parseLink('javascript:alert(1)'), isNull);
    });

    test('maps Spotify links to playback URIs', () {
      expect(PlaylistEntry.spotifyContextUriFor('https://open.spotify.com/playlist/3U6Qv1uK?si=x'),
          'spotify:playlist:3U6Qv1uK');
      expect(PlaylistEntry.spotifyContextUriFor('open.spotify.com/intl-id/album/AbC123'),
          'spotify:album:AbC123');
      expect(PlaylistEntry.spotifyContextUriFor('spotify:playlist:abc'), 'spotify:playlist:abc');
      expect(PlaylistEntry.spotifyContextUriFor('https://open.spotify.com/track/abc'), isNull);
      expect(PlaylistEntry.spotifyContextUriFor('https://youtu.be/x'), isNull);
    });

    test('detects platform', () {
      expect(PlaylistEntry.detectPlatform('https://youtu.be/x'), 'youtube');
      expect(PlaylistEntry.detectPlatform('https://open.spotify.com/x'), 'spotify');
      expect(PlaylistEntry.detectPlatform('https://example.com'), 'other');
    });
  });
}
