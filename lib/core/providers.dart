import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore/firestore_paths.dart';
import 'firestore/sync_state.dart';

/// Low-level singletons shared by repositories. Tests override these.

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Overridden in `bootstrap()` once SharedPreferences has loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final fsPathsProvider =
    Provider<FsPaths>((ref) => FsPaths(ref.watch(firestoreProvider)));

final syncCursorStoreProvider = Provider<SyncCursorStore>(
    (ref) => SyncCursorStore(ref.watch(sharedPrefsProvider)));

final syncThrottleProvider = Provider<SyncThrottle>((ref) => SyncThrottle());
