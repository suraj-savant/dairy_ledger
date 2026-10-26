import 'main_dev.dart' as dev;

/// Not used for real runs: always start a flavor entry point
/// (`lib/main_dev.dart` or `lib/main_prod.dart`, see docs/FIREBASE_SETUP.md).
/// This default points at dev so a plain `flutter run` never touches production data.
Future<void> main() => dev.main();
