import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-flavor settings (dev / prod). Created in `main_dev.dart` / `main_prod.dart`
/// and exposed through [flavorProvider]; nothing else in the app checks the
/// flavor by name.
class Flavor {
  const Flavor({
    required this.name,
    required this.firebaseOptions,
    required this.linkDomain,
  });

  final String name;
  final FirebaseOptions firebaseOptions;

  /// Firebase Hosting domain used for account links and QR codes.
  final String linkDomain;

  bool get isDev => name == 'dev';

  /// Link a supplier opens (or scans) to follow an account.
  String accountLink(String accountId) => 'https://$linkDomain/a/$accountId';
}

/// Overridden at start-up; reading it before that is a programming error.
final flavorProvider = Provider<Flavor>(
  (ref) => throw UnimplementedError('flavorProvider must be overridden in main'),
);
