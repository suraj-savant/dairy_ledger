import 'dart:convert';

import '../../accounts/models/account.dart';

/// An account a supplier follows, remembered on the supplier's device so the
/// app opens straight to it next time (no link needed).
class FollowedAccount {
  const FollowedAccount({
    required this.ownerUid,
    required this.accountId,
    required this.accountName,
    required this.dairyName,
    required this.adminName,
  });

  final String ownerUid;
  final String accountId;
  final String accountName;
  final String dairyName;
  final String adminName;

  AccountRef get ref => (ownerUid: ownerUid, accountId: accountId);

  Map<String, dynamic> toJson() => {
        'ownerUid': ownerUid,
        'accountId': accountId,
        'accountName': accountName,
        'dairyName': dairyName,
        'adminName': adminName,
      };

  factory FollowedAccount.fromJson(Map<String, dynamic> j) => FollowedAccount(
        ownerUid: j['ownerUid'] as String,
        accountId: j['accountId'] as String,
        accountName: (j['accountName'] as String?) ?? '',
        dairyName: (j['dairyName'] as String?) ?? '',
        adminName: (j['adminName'] as String?) ?? '',
      );

  static String encodeList(List<FollowedAccount> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<FollowedAccount> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List;
    return [
      for (final e in decoded)
        // Entries saved before the owner ID existed cannot be opened: skip them.
        if ((e as Map)['ownerUid'] != null)
          FollowedAccount.fromJson(Map<String, dynamic>.from(e)),
    ];
  }
}
