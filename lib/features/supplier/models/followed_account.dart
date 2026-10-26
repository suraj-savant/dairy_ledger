import 'dart:convert';

/// An account a supplier follows, remembered on the supplier's device so the
/// app opens straight to it next time (no link needed).
class FollowedAccount {
  const FollowedAccount({
    required this.accountId,
    required this.accountName,
    required this.dairyName,
    required this.adminName,
  });

  final String accountId;
  final String accountName;
  final String dairyName;
  final String adminName;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'accountName': accountName,
        'dairyName': dairyName,
        'adminName': adminName,
      };

  factory FollowedAccount.fromJson(Map<String, dynamic> j) => FollowedAccount(
        accountId: j['accountId'] as String,
        accountName: (j['accountName'] as String?) ?? '',
        dairyName: (j['dairyName'] as String?) ?? '',
        adminName: (j['adminName'] as String?) ?? '',
      );

  static String encodeList(List<FollowedAccount> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<FollowedAccount> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => FollowedAccount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
