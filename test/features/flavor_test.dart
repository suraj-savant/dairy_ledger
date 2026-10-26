import 'package:dairy_ledger/app/flavor.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account links carry the owner and the account ID', () {
    const flavor = Flavor(
      name: 'dev',
      firebaseOptions: FirebaseOptions(apiKey: 'k', appId: 'a', messagingSenderId: 'm', projectId: 'p'),
      linkDomain: 'dev-dairyledger.web.app',
    );
    expect(flavor.accountLink('uid1', 'acc1'), 'https://dev-dairyledger.web.app/a/uid1/acc1');
    expect(flavor.isDev, isTrue);
  });
}
