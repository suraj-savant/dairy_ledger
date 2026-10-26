import 'package:dairy_ledger/features/supplier/models/followed_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('followed accounts round-trip through JSON with the owner ID', () {
    const list = [
      FollowedAccount(
        ownerUid: 'u1',
        accountId: 'a1',
        accountName: 'RAMESH',
        dairyName: 'Shree Dairy',
        adminName: 'Suraj',
      ),
    ];
    final decoded = FollowedAccount.decodeList(FollowedAccount.encodeList(list));
    expect(decoded.single.ref, (ownerUid: 'u1', accountId: 'a1'));
    expect(decoded.single.dairyName, 'Shree Dairy');
  });

  test('entries saved before the owner ID existed are skipped, not crashed on', () {
    const old = '[{"accountId":"a1","accountName":"X","dairyName":"","adminName":""}]';
    expect(FollowedAccount.decodeList(old), isEmpty);
  });
}
