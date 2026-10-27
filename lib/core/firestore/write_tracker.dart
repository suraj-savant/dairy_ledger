import 'package:cloud_firestore/cloud_firestore.dart';

import '../logger.dart';
import '../messenger.dart';

/// Issues a Firestore write without waiting for the server.
///
/// Firestore applies a write to the local cache immediately but the returned
/// future only completes once the *server* acknowledges it, which never
/// happens while the phone is offline. Awaiting it would freeze the UI, so
/// callers continue straight away (the UI reads the updated cache) and this
/// helper logs the outcome in two steps: `CACHE` when the change is applied to
/// the local cache (immediately), `FIRESTORE` when the server accepts or
/// rejects it. A rejected write (for example a security rule) is reported
/// with a snack bar.
void trackWrite(String label, Future<void> write) {
  logd('CACHE', 'WRITE $label -> applied to local cache, upload queued');
  write.then((_) {
    logd('FIRESTORE', 'WRITE $label -> acknowledged by server, billed 1 write');
  }).catchError((Object e) {
    final code = e is FirebaseException ? e.code : e.toString();
    logd('FIRESTORE', 'WRITE $label -> REJECTED by server ($code), local change rolled back');
    showAppSnack('Could not save changes ($code). Please try again.');
  });
}
