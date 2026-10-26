import 'package:cloud_firestore/cloud_firestore.dart';

import '../logger.dart';
import 'firestore_paths.dart';

/// Reads a document from the local cache first and only goes to the server
/// when the cache does not have it. Keeps normal screens free of billed reads.
Future<DocumentSnapshot<Json>> getDocCacheFirst(
  DocumentReference<Json> ref,
) async {
  try {
    final cached = await ref.get(const GetOptions(source: Source.cache));
    if (cached.exists) {
      logd('FIRESTORE', 'READ  ${ref.path} (cache)');
      return cached;
    }
  } on FirebaseException {
    // Not in the cache: fall through to the server.
  }
  final snap = await ref.get(); // server, falls back to cache when offline
  logd('FIRESTORE',
      'READ  ${ref.path} (${snap.metadata.isFromCache ? 'cache/offline' : 'server'}, exists=${snap.exists})');
  return snap;
}

/// Runs [query] against the local cache only (no billed reads).
Future<QuerySnapshot<Json>> getQueryFromCache(
  Query<Json> query, {
  required String label,
}) async {
  try {
    final snap = await query.get(const GetOptions(source: Source.cache));
    logd('FIRESTORE', 'QUERY $label (cache) -> ${snap.docs.length} docs');
    return snap;
  } on FirebaseException catch (e) {
    logd('FIRESTORE', 'QUERY $label (cache) failed: ${e.code}');
    rethrow;
  }
}

/// Runs [query] on the server (billed: one read per returned document).
/// Falls back to the cache when the device is offline.
Future<QuerySnapshot<Json>> getQueryFromServer(
  Query<Json> query, {
  required String label,
}) async {
  final snap = await query.get(const GetOptions(source: Source.serverAndCache));
  logd('FIRESTORE',
      'QUERY $label (${snap.metadata.isFromCache ? 'cache/offline' : 'server'}) -> ${snap.docs.length} docs');
  return snap;
}
