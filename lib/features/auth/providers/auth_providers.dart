import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
  name: 'authRepositoryProvider',
);

/// Current Firebase user (null = signed out). The router listens to this.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
  name: 'authStateProvider',
);

/// State of the login / OTP flow, shared by the login and OTP screens.
class LoginState {
  const LoginState({
    this.phone = '',
    this.verificationId,
    this.resendToken,
    this.busy = false,
    this.error,
    this.resendAvailableAt,
  });

  final String phone; // 10 digits, without country code
  final String? verificationId; // set once the SMS was sent
  final int? resendToken;
  final bool busy;
  final String? error;
  final DateTime? resendAvailableAt;

  LoginState copyWith({
    String? phone,
    String? verificationId,
    int? resendToken,
    bool? busy,
    String? error,
    bool clearError = false,
    DateTime? resendAvailableAt,
  }) =>
      LoginState(
        phone: phone ?? this.phone,
        verificationId: verificationId ?? this.verificationId,
        resendToken: resendToken ?? this.resendToken,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      );

  @override
  String toString() =>
      'LoginState(codeSent=${verificationId != null}, busy=$busy, error=$error)';
}

/// Drives phone sign-in: send OTP, resend, verify.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() {
    // Once signed in, forget the flow so a later logout starts clean.
    ref.listen(authStateProvider, (_, next) {
      if (next.value != null) state = const LoginState();
    });
    return const LoginState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Sends the OTP SMS to [phone] (10 digits). Also used to resend.
  Future<void> sendOtp(String phone, {bool resend = false}) async {
    state = state.copyWith(phone: phone, busy: true, clearError: true);
    await _repo.verifyPhone(
      phoneNumber: '${AppConstants.countryCode}$phone',
      resendToken: resend ? state.resendToken : null,
      onCodeSent: (id, token) => state = state.copyWith(
        busy: false,
        verificationId: id,
        resendToken: token,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 30)),
      ),
      onAutoVerified: (credential) async {
        try {
          await _repo.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          _fail(e);
        }
      },
      onFailed: _fail,
    );
  }

  /// Verifies the 6-digit [code]. Success is observed through [authStateProvider].
  Future<void> verifyOtp(String code) async {
    final id = state.verificationId;
    if (id == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.signInWithSmsCode(verificationId: id, smsCode: code);
      state = state.copyWith(busy: false);
    } on FirebaseAuthException catch (e) {
      _fail(e);
    }
  }

  /// Back to the phone number step.
  void reset() => state = const LoginState();

  void _fail(FirebaseAuthException e) {
    state = state.copyWith(busy: false, error: authErrorMessage(e));
  }
}

final loginProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
  name: 'loginProvider',
);

/// Friendly text for common phone-auth errors.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-phone-number':
      return 'Enter a valid phone number.';
    case 'invalid-verification-code':
      return 'That code is not correct. Please try again.';
    case 'session-expired':
    case 'code-expired':
      return 'The code has expired. Please request a new one.';
    case 'too-many-requests':
    case 'quota-exceeded':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection.';
    default:
      return e.message ?? 'Something went wrong. Please try again.';
  }
}
