import '../../../core/local_data_service.dart';
import '../../../core/logger.dart';
import 'auth_repository.dart';

/// Start and end of a signed-in session. Whatever ends a session (logout,
/// deleting the account, "refresh all data") also wipes the local copy of the
/// data, so nothing of one user is ever visible to the next and nothing stale
/// is left behind.
class SessionService {
  SessionService(this._auth, this._local);
  final AuthRepository _auth;
  final LocalDataService _local;

  /// True when changes made offline have not reached the server yet. Clearing
  /// the cache now would discard them, so callers ask the user first.
  Future<bool> hasUnsyncedChanges() async => !(await _local.flushPendingWrites());

  /// Logout: wipe cached records and sync cursors, then sign out.
  Future<void> logout() async {
    logd('AUTH', 'logout: clearing local data first');
    await _local.clear();
    await _auth.signOut();
  }

  /// After the account and its data were deleted on the server.
  Future<void> afterAccountDeleted() => _local.clear();

  /// Drops the cache and cursors but stays signed in. The app reloads
  /// everything from the server afterwards.
  Future<void> resetLocalData() => _local.clear();
}
