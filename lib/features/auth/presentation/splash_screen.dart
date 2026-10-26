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
                onPressed: () => ref.read(sessionServiceProvider).logout(),
                child: const Text('Log out'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    // White to match the native launch screen, so there is no flash between them.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/DairyLedger.png', width: 240, semanticLabel: AppConstants.appName),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
