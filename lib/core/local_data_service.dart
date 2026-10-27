import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore/sync_state.dart';
import 'logger.dart';

/// Owns the on-device copy of Firestore data (the offline cache) and the sync
/// cursors that describe what is in it.
///
/// The cache and the cursors must always be cleared together: a cursor that
/// outlives an emptied cache would make delta sync skip records, and a cache
/// that outlives its cursors would keep records the server no longer has.
class LocalDataService {
  LocalDataService(this._db, this._cursors, this._throttle);
  final FirebaseFirestore _db;
  final SyncCursorStore _cursors;
  final SyncThrottle _throttle;

  /// True when every queued write reached the server within [timeout].
  /// False means some changes are still only on this phone (offline).
  Future<bool> flushPendingWrites({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await _db.waitForPendingWrites().timeout(timeout);
      logd('FIRESTORE', 'no pending writes');
      return true;
    } catch (e) {
      logd('FIRESTORE', 'writes still pending ($e)');
      return false;
    }
  }

  /// Removes every cached record and sync cursor. Used on logout, after
  /// account deletion and by "Refresh all data". The Firestore instance is
  /// terminated first (required by `clearPersistence`) and is recreated
  /// automatically by the next read or write.
  Future<void> clear() async {
    logd('CACHE', 'CLEAR everything (terminate + clearPersistence)');
    try {
      await _db.terminate();
      await _db.clearPersistence();
      logd('CACHE', 'CLEAR done');
    } catch (e) {
      // Do not block logout if the cache cannot be cleared; cursors are still
      // reset below so the next session starts with a full sync.
      logd('CACHE', 'CLEAR failed: $e');
    }
    await _cursors.clearAll();
    _throttle.clear();
  }
}
