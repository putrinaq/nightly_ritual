import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/manifestation_ritual.dart';
import '../models/habit.dart';
import '../models/playlist_entry.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Rituals ──────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _ritualsRef(String uid) =>
      _db.collection('users').doc(uid).collection('rituals');

  Stream<List<ManifestationRitual>> getRituals(String uid) {
    return _ritualsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ManifestationRitual.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> addRitual(String uid, ManifestationRitual ritual) async {
    try {
      await _ritualsRef(uid).add(ritual.toMap());
    } catch (e) {
      debugPrint('addRitual error: $e');
      rethrow;
    }
  }

  Future<void> updateRitual(String uid, ManifestationRitual ritual) async {
    try {
      final map = ritual.toMap();
      map['updatedAt'] = Timestamp.now();
      await _ritualsRef(uid).doc(ritual.id).update(map);
    } catch (e) {
      debugPrint('updateRitual error: $e');
      rethrow;
    }
  }

  Future<void> deleteRitual(String uid, String ritualId) async {
    try {
      await _ritualsRef(uid).doc(ritualId).delete();
    } catch (e) {
      debugPrint('deleteRitual error: $e');
      rethrow;
    }
  }

  // ── Habits ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _habitsRef(String uid) =>
      _db.collection('users').doc(uid).collection('habits');

  Stream<List<Habit>> getHabits(String uid) {
    return _habitsRef(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Habit.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addHabit(String uid, Habit habit) async {
    try {
      await _habitsRef(uid).add(habit.toMap());
    } catch (e) {
      debugPrint('addHabit error: $e');
      rethrow;
    }
  }

  Future<void> deleteHabit(String uid, String habitId) async {
    try {
      await _habitsRef(uid).doc(habitId).delete();
    } catch (e) {
      debugPrint('deleteHabit error: $e');
      rethrow;
    }
  }

  Future<void> toggleHabitDate(
      String uid, String habitId, String dateStr, bool add) async {
    try {
      await _habitsRef(uid).doc(habitId).update({
        'completedDates': add
            ? FieldValue.arrayUnion([dateStr])
            : FieldValue.arrayRemove([dateStr]),
      });
    } catch (e) {
      debugPrint('toggleHabitDate error: $e');
      rethrow;
    }
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _playlistsRef(String uid) =>
      _db.collection('users').doc(uid).collection('playlists');

  Stream<List<PlaylistEntry>> getPlaylists(String uid) {
    return _playlistsRef(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlaylistEntry.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> addPlaylist(String uid, PlaylistEntry playlist) async {
    try {
      await _playlistsRef(uid).add(playlist.toMap());
    } catch (e) {
      debugPrint('addPlaylist error: $e');
      rethrow;
    }
  }

  Future<void> deletePlaylist(String uid, String playlistId) async {
    try {
      await _playlistsRef(uid).doc(playlistId).delete();
    } catch (e) {
      debugPrint('deletePlaylist error: $e');
      rethrow;
    }
  }
}
