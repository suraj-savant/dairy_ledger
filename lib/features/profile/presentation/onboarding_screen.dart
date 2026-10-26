import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../providers/profile_providers.dart';
import 'profile_fields.dart';

/// Asks for name, dairy name and bill cycle right after the first login.
///
/// It cannot be skipped: the router redirects here until the profile's
/// `onboardingCompleted` flag is true, even after the app was closed.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dairy = TextEditingController();
  final _cycle = TextEditingController(text: '${AppConstants.defaultBillCycleDays}');

  @override
  void dispose() {
    _name.dispose();
    _dairy.dispose();
    _cycle.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref.read(profileProvider.notifier).completeOnboarding(
          adminName: _name.text,
          dairyName: _dairy.text,
          billCycleDays: int.parse(_cycle.text.trim()),
        );
  }

  @override
  Widget build(BuildContext context) {
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppConstants.appName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text('Tell us about your dairy',
                          textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 32),
                      ProfileFields(name: _name, dairy: _dairy, cycle: _cycle, onSubmitted: _submit),
                      const SizedBox(height: 32),
                      ElevatedButton(onPressed: _submit, child: const Text('CONTINUE')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
