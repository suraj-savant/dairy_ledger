# Firebase Setup and Running the App

Dairy Ledger uses two Flutter flavors, each connected to its own Firebase project on a different Google account. Only Android is configured.

| Flavor | Firebase project ID | Google account | Android applicationId | Firebase Android app ID |
|---|---|---|---|---|
| dev | `dev-dairyledger` | surajsavant9990@gmail.com | `com.dairyledger.app.dev` | `1:311040172978:android:d2fb6af9a151c28d7efaab` |
| prod | `dairyledgerapp` | surajsavant089@gmail.com | `com.dairyledger.app` | `1:188869188951:android:4e06df101f766835073212` |

This app replaces an app already published on the Play Store. The prod application ID and the signing keystore are the same as the published app, so updates install over it.

## Running the app

Always pass both `--flavor` and `-t`.

```bash
# Debug against the dev Firebase project (use this day to day)
flutter run --flavor dev -t lib/main_dev.dart

# Against the production Firebase project (writes real data)
flutter run --flavor prod -t lib/main_prod.dart

# Build a signed Play Store bundle
flutter build appbundle --flavor prod -t lib/main_prod.dart

# Build a dev APK
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

`lib/main.dart` only forwards to the dev entry point, so a plain `flutter run` cannot touch production. Always start `main_dev.dart` or `main_prod.dart`.

The first Gradle build is slow (the initial dev build took about 14 minutes). Later builds are much faster.

### IDE setup

**VS Code**: add to `.vscode/launch.json`:
```json
{
  "name": "Dev (debug)",
  "request": "launch",
  "type": "dart",
  "program": "lib/main_dev.dart",
  "args": ["--flavor", "dev"]
}
```

**Android Studio**: Run > Edit Configurations. Set *Dart entrypoint* to `lib/main_dev.dart` and *Build flavor* to `dev`.

## What was changed to enable Firebase

1. **Tooling**
   - Firebase CLI installed with npm using a user-level prefix (`~/.npm-global`) to avoid `EACCES` errors from the root-owned `/usr/local`. A PATH line was added to `~/.bashrc`.
   - FlutterFire CLI: `dart pub global activate flutterfire_cli` (binary in `~/.pub-cache/bin`).
   - Both Google accounts are logged in to the Firebase CLI (`firebase login`, then `firebase login:add`). Check with `firebase login:list`.
2. **Dependency**: `firebase_core` added to `pubspec.yaml`.
3. **Firebase configs** generated with `flutterfire configure` for each project (see "Regenerating configs"). It registered a new Android app in each Firebase project and generated:
   - `lib/firebase_options_dev.dart`, `lib/firebase_options_prod.dart`
   - `android/app/src/dev/google-services.json`, `android/app/src/prod/google-services.json`
4. **Android Gradle** (`android/app/build.gradle.kts`, `android/settings.gradle.kts`)
   - Google Services plugin applied (added by FlutterFire).
   - `applicationId` set to `com.dairyledger.app`, copied from the production app.
   - Product flavors `dev` (adds `.dev` suffix) and `prod` in an `env` dimension.
   - A `release` signing config read from `android/key.properties`, used by the release build type.
5. **Dart entry points**
   - `lib/main_dev.dart` and `lib/main_prod.dart` pass the matching `DefaultFirebaseOptions` to `bootstrap()`.
   - `lib/main_common.dart` runs `Firebase.initializeApp(options: ...)`, enables unlimited Firestore persistence and starts the Riverpod `ProviderScope` with `DairyLedgerApp`.
   - The app itself is described in `ARCHITECTURE.md`.

The Google Services plugin picks the matching `google-services.json` by flavor from `src/<flavor>/`. There is deliberately no `android/app/google-services.json`.

## Release signing

- Keystore: `/home/suraj/Documents/DeploymentSecretes/dairylegerkeystore/upload-keystore.jks`, key alias `upload`. It lives outside the repo.
- `android/key.properties` holds the keystore path, alias and passwords. It was copied from the production app and is gitignored. Never commit it or share it.
- Both flavors' release builds use this keystore. Debug builds use the standard Android debug key.

## Regenerating configs

Run from the project root. FlutterFire writes `android/app/google-services.json`, so move it into the flavor folder afterwards.

```bash
export PATH="$HOME/.npm-global/bin:$HOME/.pub-cache/bin:$PATH"

flutterfire configure -y --account=surajsavant9990@gmail.com --project=dev-dairyledger \
  --platforms=android --android-package-name=com.dairyledger.app.dev \
  --out=lib/firebase_options_dev.dart
mv android/app/google-services.json android/app/src/dev/google-services.json

flutterfire configure -y --account=surajsavant089@gmail.com --project=dairyledgerapp \
  --platforms=android --android-package-name=com.dairyledger.app \
  --out=lib/firebase_options_prod.dart
mv android/app/google-services.json android/app/src/prod/google-services.json
```

`firebase login` needs a real interactive terminal. It fails with "non-interactive mode" when run through Claude Code's `!` prefix.

## Phone authentication

Phone sign-in is enabled in both Firebase projects, and the debug/release/Play signing SHA-1 and SHA-256 fingerprints were registered in each (done in the Firebase Console, not in code).

- `firebase_auth` is a dependency.
- `lib/features/auth`: `LoginScreen` (fixed `+91`, 10 digits), `OtpScreen` (6 digit boxes, Android auto-fill, resend timer, change number) and `LoginController`. The router (`lib/app/router.dart`) moves on by itself after sign-in: to onboarding or home.
- Both `google-services.json` files were regenerated after adding the SHA keys.

Testing:
- Dev: add numbers under Authentication > Sign-in method > Phone > "Phone numbers for testing" in `dev-dairyledger` to avoid real SMS.
- Prod: a Play-distributed build is signed by the Play App Signing key, so that key's SHA must be in `dairyledgerapp`. Local prod builds only work with the upload key's SHA registered.
- If prod SMS is unreliable, check the Play Integrity API is enabled in the Google Cloud project, the SMS region policy allows the country, and the billing/quota plan.

Common errors: `app-not-authorized` or a reCAPTCHA fallback means a missing SHA or stale `google-services.json`; `too-many-requests` means the SMS quota or throttling was hit.

## Known notes and to-dos

- The prod release build has not been tested yet. Run `flutter build appbundle --flavor prod -t lib/main_prod.dart` to verify signing.
- If you use Google sign-in or phone auth, register the debug and release SHA-1 and SHA-256 fingerprints in the matching Firebase project. Get the release fingerprints by running `keytool -list -v -keystore <path> -alias upload` yourself.
- `firebase.json` (written by FlutterFire) still lists `android/app/google-services.json` as its output path, which no longer exists. It does not affect builds.
- The dev Firebase project already contained an older Android app, `com.app.dairyledger`, which this project does not use.
- The Android `namespace` is still the scaffold value `com.example.dairy_ledger`. It is unrelated to Firebase and the application ID.
- iOS, web and desktop have no Firebase configuration.

## Firestore rules, indexes and hosting

The app needs `firestore.rules` and `firestore.indexes.json` deployed to each Firebase project (the old test-mode rules have expired, so every read and write is denied until then). Hosting serves the account-link fallback page and `assetlinks.json` (see `hosting/README.md`).

```bash
firebase login:use surajsavant9990@gmail.com
firebase deploy --only firestore,hosting --project dev-dairyledger

firebase login:use surajsavant089@gmail.com      # only after replacing the SHA-256 placeholders
firebase deploy --only firestore,hosting --project dairyledgerapp
```

Firestore must already be created in each project (Firebase Console > Firestore Database > Create database).
