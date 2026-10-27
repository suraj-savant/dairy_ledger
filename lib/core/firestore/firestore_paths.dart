import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

/// Single place that knows the Firestore layout (see docs/ARCHITECTURE.md §2).
/// Everything an admin owns lives under their user document:
///
///   users/{uid}                                       admin profile (private)
///   users/{uid}/rates/{category}                      rate chart (private)
///   users/{uid}/public/profile                        the two names suppliers may see (public get)
///   users/{uid}/accounts/{accountId}                  account; its random ID is the share key
///   users/{uid}/accounts/{accountId}/bills/{billId}   one bill (all days) per document
class FsPaths {
  const FsPaths(this.db);
  final FirebaseFirestore db;

  DocumentReference<Json> user(String uid) => db.collection('users').doc(uid);

  CollectionReference<Json> rates(String uid) => user(uid).collection('rates');

  /// The only part of the profile suppliers can read: admin and dairy name.
  DocumentReference<Json> publicProfile(String uid) =>
      user(uid).collection('public').doc('profile');

  CollectionReference<Json> accounts(String uid) => user(uid).collection('accounts');

  DocumentReference<Json> account(String uid, String accountId) =>
      accounts(uid).doc(accountId);

  CollectionReference<Json> bills(String uid, String accountId) =>
      account(uid, accountId).collection('bills');
}
