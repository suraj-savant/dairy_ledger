import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logger.dart';
import '../../../core/messenger.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../accounts/providers/account_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../rates/providers/rate_providers.dart';
import '../models/user_profile.dart';
import '../providers/profile_providers.dart';
import 'edit_profile_dialog.dart';

/// Shows the profile (read only, edited in a dialog), plus refresh, logout
/// and account deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your settings.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (p) => p == null
            ? const LoadingView()
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Your details', style: theme.textTheme.titleLarge)),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit details',
                        onPressed: () => _edit(context, ref, p),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ReadOnlyField(label: 'Your name', value: p.adminName, onTap: () => _edit(context, ref, p)),
                  const SizedBox(height: 16),
                  _ReadOnlyField(label: 'Dairy name', value: p.dairyName, onTap: () => _edit(context, ref, p)),
                  const SizedBox(height: 16),
                  _ReadOnlyField(
                    label: 'Billing cycle (days)',
                    value: '${p.billCycleDays}',
                    helper: 'A new cycle applies to new weeks only.',
                    onTap: () => _edit(context, ref, p),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Accounts I follow'),
                    subtitle: const Text('Records shared with you by other dairies'),
                    onTap: () => context.push('/supplier'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Refresh all data'),
                    subtitle: const Text('Clear this phone\'s copy and load everything again'),
                    onTap: () => _refreshAll(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    onTap: () => _logout(context, ref),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                    title: Text('Delete my account', style: TextStyle(color: theme.colorScheme.error)),
                    subtitle: const Text('Removes all your accounts, bills and rates'),
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, UserProfile current) async {
    final input = await showEditProfileDialog(context, current);
    if (input == null) return;
    await ref.read(profileProvider.notifier).updateSettings(
          adminName: input.adminName,
          dairyName: input.dairyName,
          billCycleDays: input.billCycleDays,
        );
    showAppSnack('Details saved.');
  }

  /// Asks before discarding changes that exist only on this phone.
  /// Returns true when it is fine to clear the local data.
  Future<bool> _okToClear(BuildContext context, WidgetRef ref, String action) async {
    final unsynced = await ref.read(sessionServiceProvider).hasUnsyncedChanges();
    if (!unsynced || !context.mounted) return true;
    return confirm(
      context,
      title: 'Changes not uploaded yet',
      message: 'Some changes were made offline and have not reached the server. '
          '$action will discard them. Connect to the internet first to keep them.',
      confirmLabel: 'Discard and continue',
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Log out?',
      message: 'Your data stays safe in the cloud. This phone\'s copy will be removed.',
      confirmLabel: 'Log out',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    if (!await _okToClear(context, ref, 'Logging out')) return;
    await ref.read(sessionServiceProvider).logout();
  }

  /// Clears the local copy and reloads everything from the server. Use it
  /// when the data on this phone no longer matches the server (for example
  /// records were deleted directly in the Firebase console).
  Future<void> _refreshAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Refresh all data?',
      message: 'This phone\'s copy is cleared and everything is loaded again from the server.',
      confirmLabel: 'Refresh',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    if (!await _okToClear(context, ref, 'Refreshing')) return;

    await ref.read(sessionServiceProvider).resetLocalData();
    ref.invalidate(profileProvider);
    ref.invalidate(ratesProvider);
    ref.invalidate(accountsProvider);
    showAppSnack('Data refreshed from the server.');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Delete your account?',
      message: 'All your accounts, weekly bills and rates will be permanently deleted. '
          'This cannot be undone.',
      confirmLabel: 'Delete everything',
    );
    if (!ok || !context.mounted) return;

    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    // Blocking progress dialog: deletion needs the network and takes a moment.
    // The navigator is captured first because signing out rebuilds the router
    // and this screen may be gone by the time the dialog must close.
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      await ref.read(accountDeletionServiceProvider).deleteAllData(uid);
      await ref.read(authRepositoryProvider).deleteCurrentUser();
      await ref.read(sessionServiceProvider).afterAccountDeleted();
      logd('AUTH', 'account deleted');
    } on FirebaseAuthException catch (e) {
      // Data is already gone; Firebase wants a fresh login to delete the user.
      logd('AUTH', 'auth user not deleted: ${e.code}');
      await ref.read(sessionServiceProvider).logout();
      showAppSnack('Your data was deleted. Log in again and delete the account once more to remove your login.');
    } catch (e) {
      logd('FIRESTORE', 'delete failed: $e');
      showAppSnack('Could not delete your account. Check your internet connection and try again.');
    } finally {
      navigator.pop();
    }
  }
}

/// A value shown like a normal text input but not editable; tapping it opens
/// the edit dialog.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value, required this.onTap, this.helper});

  final String label;
  final String value;
  final String? helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label=$value'), // re-create when the value changes
      initialValue: value,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }
}
