import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../bills/providers/bill_providers.dart';
import '../models/followed_account.dart';
import '../providers/supplier_providers.dart';

/// Home of a farmer / supplier: the accounts they follow. Opens straight to
/// this list on later launches, with no link needed.
class SupplierHomeScreen extends ConsumerWidget {
  const SupplierHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedAccountsProvider);
    final signedIn = ref.watch(authStateProvider).value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My milk records'),
        // Admins reach this screen from Settings and can go back; farmers
        // have no other screen, so they get a login shortcut instead.
        actions: [
          if (!signedIn)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => context.go('/login'),
              child: const Text('Dairy login'),
            ),
        ],
      ),
      body: followed.isEmpty
          ? const EmptyView(
              icon: Icons.qr_code_2,
              message: 'No accounts yet.\n\n'
                  'Ask your dairy to share your account link or QR code, then open it on this phone.',
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Pull-to-refresh: sync every followed account now.
                final repo = ref.read(billRepositoryProvider);
                await Future.wait([for (final f in followed) repo.sync(f.accountId, force: true)]);
                for (final f in followed) {
                  ref.invalidate(latestBillProvider(f.accountId));
                }
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: followed.length,
                itemBuilder: (_, i) => _FollowedTile(account: followed[i]),
              ),
            ),
    );
  }
}

class _FollowedTile extends ConsumerWidget {
  const _FollowedTile({required this.account});
  final FollowedAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestBillProvider(account.accountId));
    final theme = Theme.of(context);

    final subtitle = [
      if (account.dairyName.isNotEmpty) account.dairyName,
      latest.when(
        data: (bill) => bill == null
            ? 'No bills yet'
            : 'Latest ${Fmt.shortDate(bill.startDate)}: ₹ ${Fmt.money(bill.totalAmount)}',
        loading: () => 'Updating…',
        error: (_, _) => 'Offline',
      ),
    ].join('\n');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.deepPurpleContainer,
          child: Text(
            account.accountName.isEmpty ? '?' : account.accountName.substring(0, 1),
            style: const TextStyle(color: AppTheme.deepPurple, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        title: Text(account.accountName),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
        isThreeLine: account.dairyName.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (_) async {
            final ok = await confirm(
              context,
              title: 'Stop following?',
              message: '${account.accountName} will be removed from this phone. '
                  'You can add it again by opening the link.',
              confirmLabel: 'Remove',
            );
            if (ok) ref.read(followedAccountsProvider.notifier).remove(account.accountId);
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Stop following'))],
        ),
        onTap: () => context.push('/supplier/account/${account.accountId}'),
      ),
    );
  }
}
