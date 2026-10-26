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

/// Shared start-up for every flavor (called from `main_dev.dart` / `main_prod.dart`).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  logd('STATE', 'starting ${flavor.name} flavor (link domain ${flavor.linkDomain})');

  await Firebase.initializeApp(options: flavor.firebaseOptions);

  // Offline cache on, no size limit: history stays on the device, and
  // screens read from it instead of paying for repeated server reads.
  // FirebaseFirestore.instance.settings = const Settings(
  //   persistenceEnabled: true,
  //   cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  // );

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
