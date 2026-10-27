import 'package:flutter/foundation.dart';

/// Debug-only logging. Every Firestore read/write, cache access, auth call and
/// provider state change goes through here so one `[TAG]` filter in the
/// console shows exactly what the app is doing. Nothing is printed in release
/// builds.
///
/// Tags (full explanation and example traces in docs/CACHING.md):
///  * `AUTH`      phone sign-in / sign-out
///  * `FIRESTORE` traffic with the **server**: reads that reached it (billed),
///                write acknowledgements and rejections
///  * `CACHE`     the **local on-device cache**: reads served from it, writes
///                applied to it immediately, documents stored by a server
///                fetch, and the cache being cleared
///  * `SYNC`      delta-sync decisions: cursors, throttling, initial load vs
///                changes only
///  * `STATE`     Riverpod provider changes (see [AppProviderObserver]) and
///                local settings such as the followed-accounts list
///  * `ROUTER`    redirects and shared links being opened
void logd(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}
