import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../../core/firestore/firestore_reads.dart';
import '../../../core/firestore/sync_state.dart';
import '../../../core/firestore/write_tracker.dart';
import '../../../core/logger.dart';
import '../models/public_profile.dart';
import '../models/user_profile.dart';

/// Reads and writes the admin profile (`users/{uid}`) and its public part
/// (`users/{uid}/public/profile`, the two names suppliers can see).
class ProfileRepository {
  ProfileRepository(this._paths, this._throttle);
  final FsPaths _paths;
  final SyncThrottle _throttle;

  /// Loads the profile (cache first). A user who signs in for the first time
  /// has no document yet, so one is created with `onboardingCompleted: false`.
  Future<UserProfile> fetchOrCreate(String uid) async {
    final ref = _paths.user(uid);
    final snap = await getDocCacheFirst(ref);
    if (snap.exists) {
      final profile = UserProfile.fromMap(snap.data()!);
      // Best effort and not awaited, so it never delays or breaks loading.
      if (profile.onboardingCompleted) unawaited(_ensurePublicProfile(uid, profile));
      return profile;
    }

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

  /// Saves the profile fields (used by onboarding and settings). Once
  /// onboarding is complete the public names are written with it.
  void save(String uid, UserProfile profile) {
    final ref = _paths.user(uid);
    trackWrite(
      'update ${ref.path} (onboarded=${profile.onboardingCompleted}, cycle=${profile.billCycleDays})',
      ref.set(
        {...profile.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      ),
    );
    if (profile.onboardingCompleted) _writePublicProfile(uid, profile);
  }

  void _writePublicProfile(String uid, UserProfile profile) {
    final ref = _paths.publicProfile(uid);
    trackWrite(
      'set ${ref.path} (${profile.dairyName})',
      ref.set({
        'adminName': profile.adminName,
        'dairyName': profile.dairyName,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Creates the public document for admins who finished onboarding before it
  /// existed. Costs one read the first time (a cache miss), then none.
  Future<void> _ensurePublicProfile(String uid, UserProfile profile) async {
    try {
      final snap = await getDocCacheFirst(_paths.publicProfile(uid));
      if (!snap.exists) {
        logd('FIRESTORE', 'public profile missing for $uid, creating');
        _writePublicProfile(uid, profile);
      }
    } catch (e) {
      logd('FIRESTORE', 'public profile check skipped: $e');
    }
  }

  /// A supplier reads the owner's names. Null when the document does not exist.
  ///
  /// Cache first. With [refresh] the server is asked at most once every few
  /// hours, so a renamed dairy shows up without a read on every screen.
  Future<PublicProfile?> fetchPublic(String ownerUid, {bool refresh = false}) async {
    final ref = _paths.publicProfile(ownerUid);
    if (refresh && _throttle.take('public.$ownerUid', window: const Duration(hours: 6))) {
      try {
        final fresh = await ref.get(const GetOptions(source: Source.server));
        logd('FIRESTORE', 'READ  ${ref.path} (server, refresh, exists=${fresh.exists})');
        return fresh.exists ? PublicProfile.fromMap(fresh.data()!) : null;
      } on FirebaseException catch (e) {
        logd('FIRESTORE', 'refresh of ${ref.path} skipped (${e.code})');
      }
    }
    final snap = await getDocCacheFirst(ref);
    return snap.exists ? PublicProfile.fromMap(snap.data()!) : null;
  }
}
