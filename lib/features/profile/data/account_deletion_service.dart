import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../../core/logger.dart';

/// Permanently removes everything the admin owns (Google Play requires an
/// in-app way to delete an account). Needs a network connection, so every
/// step is awaited, unlike normal writes.
class AccountDeletionService {
  AccountDeletionService(this._paths);
  final FsPaths _paths;

  Future<void> deleteAllData(String uid) async {
    logd('FIRESTORE', 'DELETE all data of $uid');

    final accounts = await _paths.accounts.where('ownerUid', isEqualTo: uid).get();
    for (final account in accounts.docs) {
      final bills = await account.reference.collection('bills').get();
      await _deleteAll(bills.docs.map((d) => d.reference).toList());
      await account.reference.delete();
      logd('FIRESTORE', 'DELETED account ${account.id} with ${bills.docs.length} bills');
    }

    final rates = await _paths.rates(uid).get();
    await _deleteAll(rates.docs.map((d) => d.reference).toList());

    await _paths.user(uid).delete();
    logd('FIRESTORE', 'DELETED profile and ${rates.docs.length} rate charts');
  }

  Future<void> _deleteAll(List<DocumentReference<Json>> refs) async {
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _paths.db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
