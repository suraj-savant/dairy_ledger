import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/account_repository.dart';
import '../models/account.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(fsPathsProvider),
    ref.watch(syncCursorStoreProvider),
    ref.watch(syncThrottleProvider),
  ),
  name: 'accountRepositoryProvider',
);

/// The admin's accounts (home screen).
class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return [];
    return ref.watch(accountRepositoryProvider).loadOwned(user.uid);
  }

  String get _uid => ref.read(authRepositoryProvider).currentUser!.uid;
  List<Account> get _accounts => state.value ?? [];

  /// Pull-to-refresh: fetches accounts changed on the server.
  Future<void> refresh() async {
    state = AsyncData(
      await ref.read(accountRepositoryProvider).loadOwned(_uid, force: true),
    );
  }

  /// True when the admin already has an account with this name.
  bool exists(String name) =>
      _accounts.any((a) => a.name == name.trim().toUpperCase());

  /// Creates an account (name stored in upper case).
  Account create({required String name, required String category}) {
    final account = ref.read(accountRepositoryProvider).create(
          uid: _uid,
          name: name.trim().toUpperCase(),
          category: category,
        );
    state = AsyncData([..._accounts, account]..sort((a, b) => a.name.compareTo(b.name)));
    return account;
  }

  void delete(Account account) {
    ref.read(accountRepositoryProvider).softDelete(account.ref);
    state = AsyncData(_accounts.where((a) => a.id != account.id).toList());
  }
}

final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
  name: 'accountsProvider',
);

/// One account by ID for the admin screens (taken from the loaded list).
final accountByIdProvider = Provider.autoDispose.family<Account?, String>(
  (ref, id) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  },
  name: 'accountByIdProvider',
);
