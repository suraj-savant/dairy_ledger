import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger.dart';
import '../../../core/providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/account_deletion_service.dart';
import '../data/profile_repository.dart';
import '../models/public_profile.dart';
import '../models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(fsPathsProvider), ref.watch(syncThrottleProvider)),
  name: 'profileRepositoryProvider',
);

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(ref.watch(fsPathsProvider)),
  name: 'accountDeletionServiceProvider',
);

/// The signed-in admin's profile; `null` while signed out.
///
/// The router reads `onboardingCompleted` from here to decide whether the
/// onboarding screen must be shown.
class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return null;
    return ref.watch(profileRepositoryProvider).fetchOrCreate(user.uid);
  }

  String get _uid => ref.read(authRepositoryProvider).currentUser!.uid;

  /// Finishes onboarding: saves the answers and sets the completion flag.
  void completeOnboarding({
    required String adminName,
    required String dairyName,
    required int billCycleDays,
  }) {
    final profile = UserProfile(
      onboardingCompleted: true,
      adminName: adminName.trim(),
      dairyName: dairyName.trim(),
      billCycleDays: billCycleDays,
    );
    logd('STATE', 'onboarding completed');
    ref.read(profileRepositoryProvider).save(_uid, profile);
    state = AsyncData(profile);
  }

  /// Settings edit. A cycle change only affects bills created afterwards.
  /// The two names are also written to the public profile that suppliers read,
  /// so renaming the dairy is one small write, not one per account.
  void updateSettings({
    required String adminName,
    required String dairyName,
    required int billCycleDays,
  }) {
    final old = state.value ?? UserProfile.fresh;
    final profile = old.copyWith(
      adminName: adminName.trim(),
      dairyName: dairyName.trim(),
      billCycleDays: billCycleDays,
    );
    ref.read(profileRepositoryProvider).save(_uid, profile);
    state = AsyncData(profile);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
  name: 'profileProvider',
);

/// The names of a dairy owner as suppliers see them (`users/{uid}/public/profile`).
/// Keyed by the owner's uid, so every account of one dairy shares one read.
final ownerProfileProvider = FutureProvider.autoDispose.family<PublicProfile?, String>(
  (ref, ownerUid) =>
      ref.watch(profileRepositoryProvider).fetchPublic(ownerUid, refresh: true),
  name: 'ownerProfileProvider',
);
