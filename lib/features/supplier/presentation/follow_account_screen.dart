import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logger.dart';
import '../../../core/widgets/state_views.dart';
import '../../accounts/providers/account_providers.dart';
import '../providers/supplier_providers.dart';

/// Entry point of a shared link or QR code (`https://<domain>/a/{accountId}`).
///
/// Reads the account once, remembers it in the followed list on this device,
/// then opens the supplier list with the account on top. Works without login.
class FollowAccountScreen extends ConsumerStatefulWidget {
  const FollowAccountScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<FollowAccountScreen> createState() => _FollowAccountScreenState();
}

class _FollowAccountScreenState extends ConsumerState<FollowAccountScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  Future<void> _follow() async {
    setState(() => _error = null);
    logd('ROUTER', 'opening shared account ${widget.accountId}');
    try {
      final account = await ref.read(accountRepositoryProvider).fetchPublic(widget.accountId);
      if (!mounted) return;
      if (account == null || account.deleted) {
        setState(() => _error = 'This link is no longer valid.');
        return;
      }
      ref.read(followedAccountsProvider.notifier).follow(account);
      // List first, then the account on top, so Back lands on the list.
      context.go('/supplier');
      context.push('/supplier/account/${account.id}');
    } catch (e) {
      logd('FIRESTORE', 'could not open shared account: $e');
      if (mounted) {
        setState(() => _error = 'Could not open this link. Check your internet connection.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Milk records')),
      body: _error == null
          ? const LoadingView()
          : ErrorView(message: _error!, onRetry: _follow),
    );
  }
}
