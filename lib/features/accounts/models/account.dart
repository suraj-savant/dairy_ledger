import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_paths.dart';

/// Identifies one account: the admin who owns it and its random ID.
/// Both are in the share link (`/a/{ownerUid}/{accountId}`) and are needed to
/// build the Firestore path `users/{ownerUid}/accounts/{accountId}`.
typedef AccountRef = ({String ownerUid, String accountId});

/// A supplier / customer of the dairy (`users/{ownerUid}/accounts/{accountId}`).
///
/// The random document ID is the share key: anyone with the account link or
/// QR code can read the account and its bills (read-only). [adminName] and
/// [dairyName] are copies of the owner's profile so the supplier screens can
/// show them without reading the private profile.
class Account {
  const Account({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.category,
    required this.adminName,
    required this.dairyName,
    this.deleted = false,
  });

  final String id;
  final String ownerUid;
  final String name;
  final String category;
  final String adminName;
  final String dairyName;
  final bool deleted;

  AccountRef get ref => (ownerUid: ownerUid, accountId: id);

  factory Account.fromDoc(DocumentSnapshot<Json> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return Account(
      id: doc.id,
      // users/{ownerUid}/accounts/{id}: the owner is two levels up.
      ownerUid: doc.reference.parent.parent?.id ?? '',
      name: (m['name'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      adminName: (m['adminName'] as String?) ?? '',
      dairyName: (m['dairyName'] as String?) ?? '',
      deleted: m['deleted'] == true,
    );
  }

  /// First letter for avatars.
  String get initial => name.isEmpty ? '?' : name.substring(0, 1);

  @override
  String toString() => 'Account($id, $name, $category)';
}
