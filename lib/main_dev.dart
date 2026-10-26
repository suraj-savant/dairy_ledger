import 'app/flavor.dart';
import 'firebase_options_dev.dart';
import 'main_common.dart';

/// Development flavor: `flutter run --flavor dev -t lib/main_dev.dart`
Future<void> main() => bootstrap(
      Flavor(
        name: 'dev',
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
        linkDomain: 'dev-dairyledger.web.app',
      ),
    );
