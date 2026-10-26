import 'app/flavor.dart';
import 'firebase_options_prod.dart';
import 'main_common.dart';

/// Production flavor: `flutter run --flavor prod -t lib/main_prod.dart`
Future<void> main() => bootstrap(
      Flavor(
        name: 'prod',
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
        linkDomain: 'dairyledgerapp.web.app',
      ),
    );
