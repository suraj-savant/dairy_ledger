import 'package:cloud_firestore/cloud_firestore.dart';

import '../logger.dart';
import 'firestore_paths.dart';

/// Marks results that include writes still waiting to be uploaded.
String _pending(SnapshotMetadata m) =>
    m.hasPendingWrites ? ' (includes unsynced local writes)' : '';

/// Reads a document from the local cache first and only goes to the server
/// when the cache does not have it. Keeps normal screens free of billed reads.
///
/// Log tags: `CACHE` for the cache lookup (hit or miss), `FIRESTORE` when the
/// server had to be asked.
Future<DocumentSnapshot<Json>> getDocCacheFirst(
  DocumentReference<Json> ref,
) async {
  try {
    final cached = await ref.get(const GetOptions(source: Source.cache));
    if (cached.exists) {
      logd('CACHE', 'READ  ${ref.path} -> hit${_pending(cached.metadata)}');
      return cached;
    }
  } on FirebaseException {
    // A document that was never cached makes a cache-only read fail.
  }
  logd('CACHE', 'READ  ${ref.path} -> miss, asking the server');

  final snap = await ref.get(); // server; falls back to the cache when offline
  logd(
    'FIRESTORE',
    'READ  ${ref.path} from ${snap.metadata.isFromCache ? 'cache (server unreachable)' : 'server'}, exists=${snap.exists}',
  );
  return snap;
}

/// Runs [query] against the local cache only (no billed reads).
Future<QuerySnapshot<Json>> getQueryFromCache(
  Query<Json> query, {
  required String label,
}) async {
  try {
    final snap = await query.get(const GetOptions(source: Source.cache));
    logd('CACHE', 'QUERY $label -> ${snap.docs.length} docs${_pending(snap.metadata)}');
    return snap;
  } on FirebaseException catch (e) {
    logd('CACHE', 'QUERY $label failed: ${e.code}');
    rethrow;
  }
}

/// Runs [query] on the server (billed: one read per returned document, at
/// least one). Falls back to the cache when the device is offline. The SDK
/// stores the returned documents in the cache.
Future<QuerySnapshot<Json>> getQueryFromServer(
  Query<Json> query, {
  required String label,
}) async {
  final snap = await query.get(const GetOptions(source: Source.serverAndCache));
  final fromCache = snap.metadata.isFromCache;
  logd(
    'FIRESTORE',
    'QUERY $label from ${fromCache ? 'cache (server unreachable)' : 'server'} -> ${snap.docs.length} docs'
    '${fromCache ? '' : ', billed ${snap.docs.isEmpty ? 1 : snap.docs.length} read(s)'}',
  );
  if (!fromCache && snap.docs.isNotEmpty) {
    logd('CACHE', 'STORE ${snap.docs.length} docs from $label');
  }
  return snap;
}
