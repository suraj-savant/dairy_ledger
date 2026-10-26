import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../providers/auth_providers.dart';

/// Step 1 of admin sign-in: enter the phone number, receive an OTP.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => _phone.text.length == AppConstants.phoneLength;

  void _submit() {
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    ref.read(loginProvider.notifier).sendOtp(_phone.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final theme = Theme.of(context);

    // Go to the OTP screen as soon as the SMS has been sent. Only when this
    // screen is on top, so a "resend" from the OTP screen does not push twice.
    ref.listen(loginProvider, (prev, next) {
      final sent = prev?.verificationId != next.verificationId &&
          next.verificationId != null;
      if (sent && (ModalRoute.of(context)?.isCurrent ?? false)) {
        context.push('/otp');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.local_drink_rounded, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with your phone number',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(AppConstants.phoneLength),
                    ],
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '${AppConstants.countryCode}  ',
                      errorText: state.error,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_valid && !state.busy) ? _submit : null,
                    child: state.busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('LOGIN'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => _showSupplierHelp(context),
                    child: const Text("I'm a farmer / supplier"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Suppliers do not log in: they open the link or QR code shared by the dairy.
  void _showSupplierHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Farmers and suppliers'),
        content: const Text(
          'You do not need to log in.\n\n'
          'Ask your dairy to share your account link or QR code. Open the link '
          '(or scan the QR code with your phone camera) and your milk records '
          'will open here. Next time the app opens straight to them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}
