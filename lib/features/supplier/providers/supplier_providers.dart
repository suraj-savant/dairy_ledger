import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../accounts/models/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../../bills/models/bill.dart';
import '../../bills/providers/bill_providers.dart';
import '../data/followed_store.dart';
import '../models/followed_account.dart';

final followedStoreProvider = Provider<FollowedStore>(
  (ref) => FollowedStore(ref.watch(sharedPrefsProvider)),
  name: 'followedStoreProvider',
);

/// Accounts this device follows as a supplier (persisted locally).
class FollowedAccountsNotifier extends Notifier<List<FollowedAccount>> {
  @override
  List<FollowedAccount> build() => ref.watch(followedStoreProvider).read();

  /// Adds (or refreshes) a followed account from a shared link.
  void follow(Account account) {
    final entry = FollowedAccount(
      ownerUid: account.ownerUid,
      accountId: account.id,
      accountName: account.name,
    );
    final next = [
      for (final f in state)
        if (f.accountId != account.id) f,
      entry,
    ];
    state = next;
    ref.read(followedStoreProvider).write(next);
  }

  void remove(String accountId) {
    final next = state.where((f) => f.accountId != accountId).toList();
    state = next;
    ref.read(followedStoreProvider).write(next);
  }
}

final followedAccountsProvider =
    NotifierProvider<FollowedAccountsNotifier, List<FollowedAccount>>(
  FollowedAccountsNotifier.new,
  name: 'followedAccountsProvider',
);

/// Loads an account for the supplier screens; refreshes from the server at
/// most every few hours so a deleted or renamed account is noticed.
final supplierAccountProvider = FutureProvider.autoDispose.family<Account?, AccountRef>(
  (ref, account) =>
      ref.watch(accountRepositoryProvider).fetchPublic(account, refresh: true),
  name: 'supplierAccountProvider',
);

/// Newest bill of a followed account (shown on the supplier home tile).
/// Syncs first, so it costs about one read plus any changed bill.
final latestBillProvider = FutureProvider.autoDispose.family<Bill?, AccountRef>(
  (ref, account) async {
    final repo = ref.watch(billRepositoryProvider);
    await repo.sync(account);
    final page = await repo.loadLatest(account, limit: 1);
    return page.bills.firstOrNull;
  },
  name: 'latestBillProvider',
);
