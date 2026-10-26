import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/delta_sync.dart';
import '../../../core/firestore/firestore_paths.dart';
import '../../../core/firestore/firestore_reads.dart';
import '../../../core/firestore/sync_state.dart';
import '../../../core/firestore/write_tracker.dart';
import '../../../core/logger.dart';
import '../models/account.dart';

/// Reads and writes `users/{ownerUid}/accounts/{accountId}`.
class AccountRepository {
  AccountRepository(this._paths, this._cursors, this._throttle);
  final FsPaths _paths;
  final SyncCursorStore _cursors;
  final SyncThrottle _throttle;

  /// The admin's accounts (deleted ones hidden), sorted by name.
  /// Fetches only changed accounts from the server, then reads the cache.
  Future<List<Account>> loadOwned(String uid, {bool force = false}) async {
    final key = 'accounts.$uid';
    final col = _paths.accounts(uid);
    if (_throttle.take(key, force: force)) {
      await runDeltaSync(
        cursorKey: key,
        cursors: _cursors,
        buildQuery: (cursor) =>
            cursor == null ? col : col.where('updatedAt', isGreaterThan: cursor).orderBy('updatedAt'),
      );
    }

    final snap = await getQueryFromCache(col, label: col.path);
    return snap.docs.map(Account.fromDoc).where((a) => !a.deleted).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Creates an account. The ID is generated locally, so the returned account
  /// can be used immediately even while offline.
  Account create({
    required String uid,
    required String name,
    required String category,
    required String adminName,
    required String dairyName,
  }) {
    final ref = _paths.accounts(uid).doc(); // random 20-char ID = share key
    final account = Account(
      id: ref.id,
      ownerUid: uid,
      name: name,
      category: category,
      adminName: adminName,
      dairyName: dairyName,
    );
    trackWrite(
      'create ${ref.path}',
      ref.set({
        'name': name,
        'category': category,
        'adminName': adminName,
        'dairyName': dairyName,
        'deleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return account;
  }

  /// Soft delete: the document stays (with `deleted: true`) so suppliers'
  /// delta sync sees the change and can show "no longer available".
  void softDelete(AccountRef account) {
    final ref = _paths.account(account.ownerUid, account.accountId);
    trackWrite(
      'soft-delete ${ref.path}',
      ref.update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  /// Public read used by suppliers. Null when the account does not exist.
  ///
  /// Cache first. With [refresh] the server is asked at most once every few
  /// hours so a supplier notices an account the admin deleted or renamed.
  Future<Account?> fetchPublic(AccountRef account, {bool refresh = false}) async {
    final ref = _paths.account(account.ownerUid, account.accountId);
    if (refresh && _throttle.take('account.${account.accountId}', window: const Duration(hours: 6))) {
      try {
        final fresh = await ref.get(const GetOptions(source: Source.server));
        logd('FIRESTORE', 'READ  ${ref.path} (server, refresh, exists=${fresh.exists})');
        return fresh.exists ? Account.fromDoc(fresh) : null;
      } on FirebaseException catch (e) {
        logd('FIRESTORE', 'refresh of ${ref.path} skipped (${e.code})');
      }
    }
    final snap = await getDocCacheFirst(ref);
    return snap.exists ? Account.fromDoc(snap) : null;
  }

  /// Copies new profile names onto every account of the admin (settings edit).
  Future<void> propagateProfile(
    String uid, {
    required String adminName,
    required String dairyName,
  }) async {
    final col = _paths.accounts(uid);
    final snap = await getQueryFromCache(col, label: '${col.path} (propagate names)');
    // Firestore batches hold at most 500 writes.
    for (var i = 0; i < snap.docs.length; i += 400) {
      final chunk = snap.docs.skip(i).take(400).toList();
      final batch = _paths.db.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'adminName': adminName,
          'dairyName': dairyName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      trackWrite('batch update names on ${chunk.length} accounts', batch.commit());
    }
    logd('FIRESTORE', 'propagated profile names to ${snap.docs.length} accounts');
  }
}
