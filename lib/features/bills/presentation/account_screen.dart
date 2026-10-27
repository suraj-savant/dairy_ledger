import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/flavor.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../accounts/models/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/bill_providers.dart';
import 'bill_view.dart';
import 'qr_dialog.dart';

enum _HeaderMenu { qr, deleteWeek }

/// Admin screen of one account: weekly bills, edited row by row in a dialog.
/// The supplier's read-only twin is `SupplierAccountScreen`.
///
/// Menus: the top-right menu deletes the account; the dropdown next to the
/// account name shows the QR code or deletes the week on screen.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountByIdProvider(accountId));

    if (account == null) {
      final loading = ref.watch(accountsProvider).isLoading;
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: loading
            ? const LoadingView()
            : const EmptyView(icon: Icons.search_off, message: 'This account was not found.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Account options',
            onSelected: (_) => _deleteAccount(context, ref, account),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete account')),
            ],
          ),
        ],
      ),
      body: BillView(
        account: account,
        readOnly: false,
        headerMenu: PopupMenuButton<_HeaderMenu>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'QR code and week options',
          onSelected: (item) => _onHeaderMenu(context, ref, account, item),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _HeaderMenu.qr, child: Text('Show QR code')),
            PopupMenuItem(value: _HeaderMenu.deleteWeek, child: Text('Delete this week')),
          ],
        ),
      ),
    );
  }

  Future<void> _onHeaderMenu(
    BuildContext context,
    WidgetRef ref,
    Account account,
    _HeaderMenu item,
  ) async {
    switch (item) {
      case _HeaderMenu.qr:
        await showAccountQrDialog(
          context,
          account: account,
          link: ref.read(flavorProvider).accountLink(account.ownerUid, account.id),
          dairyName: ref.read(profileProvider).value?.dairyName ?? '',
        );
      case _HeaderMenu.deleteWeek:
        final notifier = ref.read(billsProvider(account.ref).notifier);
        if (ref.read(billsProvider(account.ref)).value?.current == null) return;
        final ok = await confirm(
          context,
          title: 'Delete this week?',
          message: 'All entries of this week will be removed, for you and for ${account.name}.',
        );
        if (ok) notifier.deleteCurrent();
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref, Account account) async {
    final ok = await confirm(
      context,
      title: 'Delete ${account.name}?',
      message: 'The account and all its weeks will no longer be available, '
          'also to the farmer who follows it.',
    );
    if (ok && context.mounted) {
      ref.read(accountsProvider.notifier).delete(account);
      context.pop();
    }
  }
}
