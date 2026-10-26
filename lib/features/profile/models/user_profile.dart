import '../../../core/constants.dart';
import '../../../core/firestore/firestore_paths.dart';

/// The admin's profile (`users/{uid}`), filled in by the onboarding screen.
///
/// [onboardingCompleted] is created `false` at first sign-in and set to `true`
/// only when onboarding is submitted. The router keeps sending the user to the
/// onboarding screen until it is `true`, even after the app is closed and
/// reopened.
class UserProfile {
  const UserProfile({
    required this.onboardingCompleted,
    this.adminName = '',
    this.dairyName = '',
    this.billCycleDays = AppConstants.defaultBillCycleDays,
  });

  final bool onboardingCompleted;
  final String adminName;
  final String dairyName;
  final int billCycleDays;

  /// Profile of a user who has just signed in for the first time.
  static const UserProfile fresh = UserProfile(onboardingCompleted: false);

  factory UserProfile.fromMap(Json m) => UserProfile(
        onboardingCompleted: m['onboardingCompleted'] == true,
        adminName: (m['adminName'] as String?) ?? '',
        dairyName: (m['dairyName'] as String?) ?? '',
        billCycleDays: (m['billCycleDays'] as num?)?.toInt() ??
            AppConstants.defaultBillCycleDays,
      );

  Json toMap() => {
        'onboardingCompleted': onboardingCompleted,
        'adminName': adminName,
        'dairyName': dairyName,
        'billCycleDays': billCycleDays,
      };

  UserProfile copyWith({
    bool? onboardingCompleted,
    String? adminName,
    String? dairyName,
    int? billCycleDays,
  }) =>
      UserProfile(
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        adminName: adminName ?? this.adminName,
        dairyName: dairyName ?? this.dairyName,
        billCycleDays: billCycleDays ?? this.billCycleDays,
      );

  @override
  String toString() =>
      'UserProfile(onboarded=$onboardingCompleted, cycle=$billCycleDays)';
}
