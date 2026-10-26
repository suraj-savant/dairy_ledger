import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../models/user_profile.dart';
import '../providers/profile_providers.dart';
import 'profile_form.dart';

/// Asks for name, dairy name and bill cycle right after the first login.
///
/// It cannot be skipped: the router redirects here until the profile's
/// `onboardingCompleted` flag is true, even after the app was closed.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppConstants.appName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about your dairy',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    ProfileForm(
                      initial: UserProfile.fresh,
                      submitLabel: 'CONTINUE',
                      onSubmit: (name, dairy, cycle) =>
                          ref.read(profileProvider.notifier).completeOnboarding(
                                adminName: name,
                                dairyName: dairy,
                                billCycleDays: cycle,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
