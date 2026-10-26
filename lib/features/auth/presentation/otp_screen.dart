import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../providers/auth_providers.dart';
import 'otp_input.dart';

/// Step 2 of admin sign-in: enter the 6-digit code from the SMS.
/// On success the router moves on by itself (onboarding or home).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpKey = GlobalKey<OtpInputState>();
  String _code = '';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Re-render every second for the resend countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _verify() {
    if (_code.length != AppConstants.otpLength) return;
    ref.read(loginProvider.notifier).verifyOtp(_code);
  }

  void _changeNumber() {
    ref.read(loginProvider.notifier).reset();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final theme = Theme.of(context);

    // A wrong code empties the boxes so it can be typed again.
    ref.listen(loginProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        _otpKey.currentState?.clear();
      }
    });

    final wait = state.resendAvailableAt?.difference(DateTime.now()).inSeconds ?? 0;
    final canResend = wait <= 0 && !state.busy;

    return PopScope(
      // Leaving with the back button goes back to the number step.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(loginProvider.notifier).reset();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Verify number'), automaticallyImplyLeading: false),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the ${AppConstants.otpLength}-digit code sent to\n'
                  '${AppConstants.countryCode} ${state.phone}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                OtpInput(
                  key: _otpKey,
                  enabled: !state.busy,
                  onChanged: (code) => _code = code,
                  onCompleted: (code) {
                    _code = code;
                    _verify();
                  },
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: state.busy ? null : _verify,
                  child: state.busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('AUTHORISE OTP'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: canResend
                      ? () => ref
                          .read(loginProvider.notifier)
                          .sendOtp(state.phone, resend: true)
                      : null,
                  child: Text(canResend ? 'Resend code' : 'Resend code in ${wait}s'),
                ),
                TextButton(onPressed: _changeNumber, child: const Text('Change number')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
