import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

/// Single place that knows the Firestore layout (see docs/ARCHITECTURE.md §2):
///
///   users/{uid}                          admin profile (private)
///   users/{uid}/rates/{category}         rate chart (private)
///   accounts/{accountId}                 account; the random ID is the share key
///   accounts/{accountId}/bills/{billId}  one bill (all days) per document
class FsPaths {
  const FsPaths(this.db);
  final FirebaseFirestore db;

  DocumentReference<Json> user(String uid) => db.collection('users').doc(uid);

  CollectionReference<Json> rates(String uid) => user(uid).collection('rates');

  CollectionReference<Json> get accounts => db.collection('accounts');

  DocumentReference<Json> account(String accountId) =>
      accounts.doc(accountId);

  CollectionReference<Json> bills(String accountId) =>
      account(accountId).collection('bills');
}
