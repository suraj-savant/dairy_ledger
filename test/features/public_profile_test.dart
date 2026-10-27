import 'package:dairy_ledger/features/profile/models/public_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public profile reads both names and tolerates missing fields', () {
    final p = PublicProfile.fromMap({'adminName': 'Suraj', 'dairyName': 'Shree Dairy'});
    expect(p.dairyName, 'Shree Dairy');
    expect(p.adminName, 'Suraj');

    final empty = PublicProfile.fromMap({});
    expect(empty.dairyName, isEmpty);
    expect(empty.adminName, isEmpty);
  });
}
