import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/logger.dart';

/// Thin wrapper over Firebase phone authentication. All sign-in logging
/// (tag `AUTH`) lives here; the phone number is masked in the logs.
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Starts phone verification and sends the SMS.
  ///
  /// * [onCodeSent]  SMS sent: show the OTP screen.
  /// * [onAutoVerified] Android verified the number instantly / read the SMS.
  /// * [onFailed]    invalid number, quota exceeded, app not authorized, ...
  Future<void> verifyPhone({
    required String phoneNumber,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required Future<void> Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
  }) {
    logd('AUTH', 'verifyPhoneNumber ${_mask(phoneNumber)} (resend=${resendToken != null})');
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,
      verificationCompleted: (credential) {
        logd('AUTH', 'auto-verified');
        onAutoVerified(credential);
      },
      verificationFailed: (e) {
        logd('AUTH', 'verification failed: ${e.code} ${e.message}');
        onFailed(e);
      },
      codeSent: (id, token) {
        logd('AUTH', 'code sent');
        onCodeSent(id, token);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> signInWithCredential(PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    logd('AUTH', 'signed in uid=${result.user?.uid}');
  }

  Future<void> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    logd('AUTH', 'verifying OTP');
    return signInWithCredential(PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    ));
  }

  Future<void> signOut() async {
    logd('AUTH', 'sign out');
    await _auth.signOut();
  }

  Future<void> deleteCurrentUser() async {
    logd('AUTH', 'delete auth user');
    await _auth.currentUser?.delete();
  }

  static String _mask(String phone) => phone.length > 4
      ? '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}'
      : phone;
}
