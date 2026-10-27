import '../../../core/firestore/firestore_paths.dart';

/// The part of an admin's profile that suppliers may read
/// (`users/{uid}/public/profile`): who runs the dairy. Kept apart from the
/// private profile so nothing else (bill cycle, onboarding state, future
/// private fields) is ever exposed.
class PublicProfile {
  const PublicProfile({required this.adminName, required this.dairyName});

  final String adminName;
  final String dairyName;

  factory PublicProfile.fromMap(Json m) => PublicProfile(
        adminName: (m['adminName'] as String?) ?? '',
        dairyName: (m['dairyName'] as String?) ?? '',
      );

  @override
  String toString() => 'PublicProfile($dairyName)';
}
