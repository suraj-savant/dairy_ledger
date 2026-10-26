import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logger.dart';
import '../../../core/messenger.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import 'profile_form.dart';

/// Edit the onboarding answers, log out, or delete the account.
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
                  ProfileForm(
                    initial: p,
                    submitLabel: 'SAVE CHANGES',
                    onSubmit: (name, dairy, cycle) async {
                      await ref.read(profileProvider.notifier).updateSettings(
                            adminName: name,
                            dairyName: dairy,
                            billCycleDays: cycle,
                          );
                      showAppSnack('Settings saved. A new billing cycle applies to new weeks only.');
                    },
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
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    onTap: () async {
                      final ok = await confirm(
                        context,
                        title: 'Log out?',
                        message: 'Your data stays safe in the cloud.',
                        confirmLabel: 'Log out',
                        destructive: false,
                      );
                      if (ok) await ref.read(authRepositoryProvider).signOut();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                    title: Text('Delete my account',
                        style: TextStyle(color: theme.colorScheme.error)),
                    subtitle: const Text('Removes all your accounts, bills and rates'),
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Delete your account?',
      message:
          'All your accounts, weekly bills and rates will be permanently deleted. '
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
      logd('AUTH', 'account deleted');
    } on FirebaseAuthException catch (e) {
      // Data is already gone; Firebase wants a fresh login to delete the user.
      logd('AUTH', 'auth user not deleted: ${e.code}');
      await ref.read(authRepositoryProvider).signOut();
      showAppSnack('Your data was deleted. Log in again and delete the account once more to remove your login.');
    } catch (e) {
      logd('FIRESTORE', 'delete failed: $e');
      showAppSnack('Could not delete your account. Check your internet connection and try again.');
    } finally {
      navigator.pop();
    }
  }
}
