import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/widgets/state_views.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/auth_providers.dart';

/// Shown while the sign-in state and profile load. If the profile cannot be
/// read (for example offline on first run) it offers a retry instead of
/// guessing whether onboarding was completed.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    if (profile.hasError && !profile.isLoading) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ErrorView(
                  message: 'Could not load your profile. Check your internet connection.',
                  onRetry: () => ref.invalidate(profileProvider),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Log out'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_drink_rounded,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(AppConstants.appName.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
