import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/flavor.dart';
import 'core/logger.dart';
import 'core/provider_observer.dart';
import 'core/providers.dart';

/// Turns the offline cache on with the largest size the plugin accepts.
///
/// Delta sync only re-reads changed documents, so a cached document that is
/// garbage-collected would silently go missing; the data of one dairy is a few
/// megabytes, far below the limit. The plugin accepts only
/// `Settings.CACHE_SIZE_UNLIMITED` or 1 MB to 100 MB (anything else fails an
/// assertion). On Android "unlimited" is applied as the 100 MB default.
/// Failing to apply the settings must never stop the app from starting, so
/// errors are only logged.
void _configureFirestoreCache() {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    logd('CACHE', 'could not apply cache settings (using defaults): $e');
  }
}

/// Shared start-up for every flavor (called from `main_dev.dart` / `main_prod.dart`).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  logd('STATE', 'starting ${flavor.name} flavor (link domain ${flavor.linkDomain})');

  await Firebase.initializeApp(options: flavor.firebaseOptions);

  _configureFirestoreCache();

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    retry: (_, _) => null, // failed loads show a retry button instead of silently retrying
    observers: const [AppProviderObserver()],
    overrides: [
      flavorProvider.overrideWithValue(flavor),
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
    child: const DairyLedgerApp(),
  ));
}
