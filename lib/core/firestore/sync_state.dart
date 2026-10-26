import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../logger.dart';

/// Remembers, per collection, the newest server `updatedAt` already fetched.
/// The next sync asks the server only for documents newer than this cursor,
/// so unchanged records are never read again.
///
/// The cursor is the *server* timestamp stored in the documents (never the
/// phone clock), stored as `seconds:nanos` so no precision is lost.
class SyncCursorStore {
  SyncCursorStore(this._prefs);
  final SharedPreferences _prefs;

  static String _k(String key) => 'sync_cursor.$key';

  Timestamp? read(String key) {
    final raw = _prefs.getString(_k(key));
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final n = int.tryParse(parts[1]);
    if (s == null || n == null) return null;
    return Timestamp(s, n);
  }

  /// Moves the cursor forward (never backwards).
  Future<void> advance(String key, Timestamp candidate) async {
    final current = read(key);
    if (current != null && current.compareTo(candidate) >= 0) return;
    logd('SYNC', 'cursor[$key] -> ${candidate.toDate().toIso8601String()}');
    await _prefs.setString(
        _k(key), '${candidate.seconds}:${candidate.nanoseconds}');
  }

  Future<void> clear(String key) async {
    logd('SYNC', 'cursor[$key] cleared');
    await _prefs.remove(_k(key));
  }
}

/// In-memory throttle so screens that open repeatedly do not re-sync every time.
class SyncThrottle {
  final Map<String, DateTime> _last = {};

  /// True when [key] has not been synced within [window] (default
  /// [AppConstants.syncThrottle]) or [force] is set. Marks it as synced now
  /// when returning true.
  bool take(String key, {bool force = false, Duration? window}) {
    final now = DateTime.now();
    final last = _last[key];
    if (!force &&
        last != null &&
        now.difference(last) < (window ?? AppConstants.syncThrottle)) {
      logd('SYNC', 'skip $key (synced ${now.difference(last).inSeconds}s ago)');
      return false;
    }
    _last[key] = now;
    return true;
  }
}
