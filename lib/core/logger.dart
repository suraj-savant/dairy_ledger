import 'package:flutter/foundation.dart';

/// Debug-only logging. Every Firestore read/write, auth call and provider
/// state change goes through here so one `[TAG]` filter in the console
/// shows exactly what the app is doing. Nothing is printed in release builds.
///
/// Tags used across the app:
///  * `AUTH`      phone sign-in / sign-out
///  * `FIRESTORE` document reads and writes (with cache/server source)
///  * `SYNC`      delta sync cursors
///  * `STATE`     Riverpod provider changes (see [AppProviderObserver])
///  * `ROUTER`    redirects
void logd(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}
