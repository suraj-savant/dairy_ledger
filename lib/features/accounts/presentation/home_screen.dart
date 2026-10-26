import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/widgets/state_views.dart';
import '../models/account.dart';
import '../providers/account_providers.dart';

/// Home tab: the admin's accounts as a flat list (no cards, no shadows).
/// Tap a row to open its bills.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: accounts.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your accounts.',
          onRetry: () => ref.invalidate(accountsProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.read(accountsProvider.notifier).refresh(),
          child: list.isEmpty
              ? ListView(children: [
                  SizedBox(
                    height: 420,
                    child: EmptyView(
                      icon: Icons.person_add_alt_1_outlined,
                      message: 'No accounts yet.\nTap + to add your first supplier.',
                      actionLabel: 'Add account',
                      onAction: () => context.push('/add-account'),
                    ),
                  ),
                ])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) => _AccountRow(account: list[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-account'),
        tooltip: 'Add account',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.deepPurpleContainer,
        child: Text(account.initial,
            style: const TextStyle(
                color: AppTheme.deepPurple, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      title: Text(account.name),
      subtitle: Text(account.category),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/account/${account.id}'),
    );
  }
}
