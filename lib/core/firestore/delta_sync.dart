import 'package:cloud_firestore/cloud_firestore.dart';

import '../logger.dart';
import 'firestore_paths.dart';
import 'sync_state.dart';

/// Fetches only what changed since the last sync.
///
/// [buildQuery] receives the saved cursor: `null` on the very first sync
/// (return a bounded "initial load" query) or the newest `updatedAt` already
/// fetched (return `updatedAt > cursor`). Results are stored in the Firestore
/// cache by the SDK, so screens then read them for free. Each query costs at
/// least one read, plus one per changed document.
///
/// Queries use [Source.server] on purpose: when the phone is offline the call
/// throws and the cursor is left untouched, so nothing is skipped later.
Future<void> runDeltaSync({
  required String cursorKey,
  required SyncCursorStore cursors,
  required Query<Json> Function(Timestamp? cursor) buildQuery,
}) async {
  final cursor = cursors.read(cursorKey);
  final query = buildQuery(cursor);
  try {
    final snap = await query.get(const GetOptions(source: Source.server));
    logd('SYNC',
        '$cursorKey: ${cursor == null ? 'initial load' : 'delta'} -> ${snap.docs.length} docs from server');

    Timestamp? newest;
    for (final doc in snap.docs) {
      final ts = doc.data()['updatedAt'];
      if (ts is Timestamp && (newest == null || ts.compareTo(newest) > 0)) {
        newest = ts;
      }
    }
    if (newest != null) await cursors.advance(cursorKey, newest);
  } on FirebaseException catch (e) {
    // Offline or temporarily unavailable: keep using the cache.
    logd('SYNC', '$cursorKey: sync skipped (${e.code})');
  }
}
