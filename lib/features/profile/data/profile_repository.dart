import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../../core/firestore/firestore_reads.dart';
import '../../../core/firestore/write_tracker.dart';
import '../../../core/logger.dart';
import '../models/user_profile.dart';

/// Reads and writes the admin profile (`users/{uid}`).
class ProfileRepository {
  ProfileRepository(this._paths);
  final FsPaths _paths;

  /// Loads the profile (cache first). A user who signs in for the first time
  /// has no document yet, so one is created with `onboardingCompleted: false`.
  Future<UserProfile> fetchOrCreate(String uid) async {
    final ref = _paths.user(uid);
    final snap = await getDocCacheFirst(ref);
    if (snap.exists) return UserProfile.fromMap(snap.data()!);

    logd('FIRESTORE', 'profile missing for $uid, creating (onboarding pending)');
    trackWrite(
      'create ${ref.path}',
      ref.set({
        ...UserProfile.fresh.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return UserProfile.fresh;
  }

  /// Saves the profile fields (used by onboarding and settings).
  void save(String uid, UserProfile profile) {
    final ref = _paths.user(uid);
    trackWrite(
      'update ${ref.path} (onboarded=${profile.onboardingCompleted}, cycle=${profile.billCycleDays})',
      ref.set(
        {...profile.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      ),
    );
  }
}
