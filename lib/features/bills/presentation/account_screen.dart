import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/flavor.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../accounts/providers/account_providers.dart';
import '../providers/bill_providers.dart';
import 'bill_view.dart';
import 'qr_dialog.dart';
import 'widgets/bill_pager.dart';

enum _Menu { qr, deleteWeek, deleteAccount }

/// Admin screen of one account: weekly bills with inline editing.
/// The supplier's read-only twin is `SupplierAccountScreen`.
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
          PopupMenuButton<_Menu>(
            onSelected: (item) => _onMenu(context, ref, item),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Menu.qr, child: Text('Show QR code')),
              PopupMenuItem(value: _Menu.deleteWeek, child: Text('Delete this week')),
              PopupMenuItem(value: _Menu.deleteAccount, child: Text('Delete account')),
            ],
          ),
        ],
      ),
      body: BillView(account: account, readOnly: false),
      bottomNavigationBar: const SessionBar(),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, _Menu item) async {
    final account = ref.read(accountByIdProvider(accountId));
    if (account == null) return;

    switch (item) {
      case _Menu.qr:
        await showAccountQrDialog(
          context,
          account: account,
          link: ref.read(flavorProvider).accountLink(account.id),
        );
      case _Menu.deleteWeek:
        final notifier = ref.read(billsProvider(accountId).notifier);
        if (ref.read(billsProvider(accountId)).value?.current == null) return;
        final ok = await confirm(
          context,
          title: 'Delete this week?',
          message: 'All entries of this week will be removed, for you and for ${account.name}.',
        );
        if (ok) notifier.deleteCurrent();
      case _Menu.deleteAccount:
        final ok = await confirm(
          context,
          title: 'Delete ${account.name}?',
          message: 'The account and all its weeks will no longer be available, '
              'also to the farmer who follows it.',
        );
        if (ok && context.mounted) {
          ref.read(accountsProvider.notifier).delete(accountId);
          context.pop();
        }
    }
  }
}
