import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger.dart';
import '../models/followed_account.dart';

/// Persists the accounts a supplier follows on the device (device-local, no
/// sign-in). Reopening the app shows them without scanning the link again.
class FollowedStore {
  FollowedStore(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'followed_accounts';

  List<FollowedAccount> read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return FollowedAccount.decodeList(raw);
    } catch (e) {
      logd('STATE', 'followed list unreadable, resetting: $e');
      return [];
    }
  }

  Future<void> write(List<FollowedAccount> list) {
    logd('STATE', 'followed accounts saved (${list.length})');
    return _prefs.setString(_key, FollowedAccount.encodeList(list));
  }
}
