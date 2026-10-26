import 'package:cloud_firestore/cloud_firestore.dart';

import '../logger.dart';
import '../messenger.dart';

/// Issues a Firestore write without waiting for the server.
///
/// Firestore applies a write to the local cache immediately but the returned
/// future only completes once the *server* acknowledges it, which never
/// happens while the phone is offline. Awaiting it would freeze the UI, so
/// callers continue straight away (the UI reads the updated cache) and this
/// helper logs the outcome. A rejected write (for example a security rule)
/// is reported with a snack bar.
void trackWrite(String label, Future<void> write) {
  logd('FIRESTORE', 'WRITE $label (queued)');
  write.then((_) {
    logd('FIRESTORE', 'WRITE $label (acknowledged by server)');
  }).catchError((Object e) {
    final code = e is FirebaseException ? e.code : e.toString();
    logd('FIRESTORE', 'WRITE $label FAILED: $code');
    showAppSnack('Could not save changes ($code). Please try again.');
  });
}
