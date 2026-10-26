import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../bills/presentation/bill_view.dart';
import '../../bills/presentation/widgets/bill_pager.dart';
import '../providers/supplier_providers.dart';

/// Read-only account screen for farmers / suppliers. It reuses [BillView] with
/// `readOnly: true`, so there are no inputs, no Add week and no admin menu.
class SupplierAccountScreen extends ConsumerWidget {
  const SupplierAccountScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(supplierAccountProvider(accountId));

    return Scaffold(
      appBar: AppBar(title: const Text('Milk records')),
      body: account.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not open this account. Check your internet connection.',
          onRetry: () => ref.invalidate(supplierAccountProvider(accountId)),
        ),
        data: (a) {
          if (a == null || a.deleted) {
            return EmptyView(
              icon: Icons.link_off,
              message: 'This account is no longer available.',
              actionLabel: 'Remove from my list',
              onAction: () {
                ref.read(followedAccountsProvider.notifier).remove(accountId);
                context.pop();
              },
            );
          }
          return BillView(account: a, readOnly: true);
        },
      ),
      bottomNavigationBar: const SessionBar(),
    );
  }
}
