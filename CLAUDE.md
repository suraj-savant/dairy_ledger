# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Dairy Ledger v2 (milk ledger for dairy collectors) is implemented as an MVP: phone login, onboarding, rates, accounts, weekly bills with inline editing, and read-only supplier screens reached by a shared link / QR code. It replaces an existing production app already on the Play Store, so the application ID and signing key must stay identical to that app. Only Android is configured; ios/web/desktop folders exist but have no Firebase config.

Open work, blockers and the device test checklist are tracked in `docs/TODO.md` (keep it updated when a task is finished). Not built yet: migration of the v1 SQLite data, PDF report, analytics (the tab is a placeholder), and the production Hosting setup. Design and rationale: `docs/ARCHITECTURE.md` (read it before changing data or sync code); screen wireframes: `docs/screen.md`; Firebase and flavor setup: `docs/FIREBASE_SETUP.md`.

## Commands

Flutter is at `/home/suraj/dev/flutter/bin` (on PATH). Dart SDK constraint is `^3.13.7`.

```bash
flutter pub get
flutter run --flavor dev  -t lib/main_dev.dart      # dev Firebase project
flutter run --flavor prod -t lib/main_prod.dart     # prod Firebase project
flutter build appbundle --flavor prod -t lib/main_prod.dart   # Play Store build (signed with release keystore)
flutter analyze                                     # lint (flutter_lints); build/ and all platform dirs are excluded
flutter test                                        # all tests
flutter test test/features/bill_test.dart           # single file
flutter test --plain-name "missing rate"             # single test by name (substring)
```

Always pass `--flavor` and `-t`: the Android project defines flavors. `lib/main.dart` only forwards to the dev entry point so a stray `flutter run` can never touch production data. In Cursor/VS Code use the `Dev (debug)` launch configuration in `.vscode/launch.json`.

The first Gradle build is slow (the first dev build took about 14 minutes).

## Architecture

Flutter + Riverpod (`flutter_riverpod`, hand-written `Notifier`/`AsyncNotifier`, no codegen) + go_router + Firestore with offline persistence. Feature-first layout under `lib/features/<feature>/{data,models,providers,presentation}`; shared code in `lib/core`, app wiring in `lib/app`.

Big picture (spans many files):
- **Layers:** screens watch providers, providers call repositories, only repositories touch Firestore. `core/firestore/firestore_paths.dart` is the single place that knows the collection layout (`users/{uid}`, `users/{uid}/rates/{category}`, top-level `accounts/{id}`, `accounts/{id}/bills/{startDate}`).
- **Roles:** admins sign in with phone OTP. Suppliers never sign in: an account's random document ID is the share key, carried by `https://<domain>/a/<accountId>` links and QR codes. `firestore.rules` allows `get` of an account and read of its bills to anyone, but `list` of accounts only for the owner.
- **Routing/guards:** `lib/app/router.dart` redirect decides everything: signed out -> login (or the supplier list if the phone follows accounts); signed in with `users/{uid}.onboardingCompleted != true` -> onboarding (cannot be skipped); `/a/...` links are always allowed.
- **Admin vs supplier screens:** `BillView` (`features/bills/presentation/bill_view.dart`) is shared; `AccountScreen` passes `readOnly: false` (inline `EditableBillRow`, Add week), `SupplierAccountScreen` passes `readOnly: true`. Both use `billsProvider(accountId)`.
- **Bill model:** a bill is one Firestore document holding all days of a billing cycle (`days.{yyyy-MM-dd}.{M|E}.{milk,fat,rate,rateManual?}`) plus stored totals. Dates are `yyyy-MM-dd` strings. `startDate`/`endDate`/`cycleDays` never change after creation (enforced in rules). A slot's `rate` is stored on the slot; a typed rate sets `rateManual` and survives fat edits; a missing rate is saved as 0 and only highlighted/reported, never blocking.
- **Cost model (keep it when editing sync code):** no real-time listeners; screens read the cache; `runDeltaSync` fetches only documents whose `updatedAt` is newer than a per-collection cursor (`Source.server`, so offline leaves the cursor alone); older bill pages always come from the server because a cache-only page could have gaps; deletes are soft (`deleted: true`) so delta sync can see them.
- **Writes are never awaited** (a Firestore write future only completes on server ack, which never happens offline). Use `trackWrite` in `core/firestore/write_tracker.dart`; it logs the outcome and shows a snack bar on rejection. `FieldPath` is required for map keys containing `.` or `-` (fat keys like "3.5", date keys).
- **Debug logging:** `logd(tag, msg)` (`core/logger.dart`, debug builds only) with tags `AUTH`, `FIRESTORE`, `SYNC`, `STATE` (every provider change via `AppProviderObserver`), `ROUTER`. Add a log line for any new Firestore read/write or state change.
- **Theme:** `lib/app/theme.dart` (deep purple `#4527A0`, amber accents, milk-white background). Rules it encodes: tap targets at least 56dp, body text at least 16sp, layouts must fit at 130% font scale.

Firebase config in the repo: `firestore.rules`, `firestore.indexes.json`, `hosting/` (fallback page for links when the app is not installed + `assetlinks.json`, see `hosting/README.md`). They are deployed manually per project; the prod `assetlinks.json` still contains placeholder SHA-256 values.

## Firebase / flavor configuration

Two Flutter flavors (`dev`, `prod`), each tied to its own Firebase project on a different Google account:

| Flavor | Firebase project ID | Google account | Android applicationId | Firebase Android app ID |
|---|---|---|---|---|
| dev | `dev-dairyledger` | surajsavant9990@gmail.com | `com.dairyledger.app.dev` | `1:311040172978:android:d2fb6af9a151c28d7efaab` |
| prod | `dairyledgerapp` | surajsavant089@gmail.com | `com.dairyledger.app` | `1:188869188951:android:4e06df101f766835073212` |

How it fits together (spans several files):
- `android/app/build.gradle.kts` defines `productFlavors` `dev` (adds `applicationIdSuffix = ".dev"`) and `prod`, each with manifest placeholders `appName` and `linkHost` (the Hosting domain of account links, used by the App Links intent filter in `AndroidManifest.xml`). Base `applicationId` is `com.dairyledger.app` (copied from the production app). `namespace` is still the scaffold value `com.example.dairy_ledger` and is unrelated to Firebase.
- The Google Services Gradle plugin picks the per-flavor config: `android/app/src/dev/google-services.json` and `android/app/src/prod/google-services.json`. There is intentionally no `android/app/google-services.json`.
- `lib/firebase_options_dev.dart` and `lib/firebase_options_prod.dart` are generated by FlutterFire (Android only).
- Entry points: `lib/main_dev.dart` / `lib/main_prod.dart` build a `Flavor` (Firebase options + link domain) and call `bootstrap()` in `lib/main_common.dart`, which initializes Firebase, turns on unlimited Firestore persistence and starts the `ProviderScope`.
- `firebase.json` is written by FlutterFire. Its `fileOutput` points at `android/app/google-services.json`, which no longer exists after the files were moved into flavor folders.

The dev Firebase project also contains an older Android app, `com.app.dairyledger`, which this project does not use.

### Phone authentication

Phone sign-in is enabled in both Firebase projects, and the debug/release/Play signing SHA-1 and SHA-256 fingerprints were registered in each (done in the Firebase Console, not in code). The flow is `features/auth` (`LoginScreen`, `OtpScreen` with six digit boxes, `LoginController`); `+91` is the fixed country code.

Testing:
- Dev: add numbers under Authentication > Sign-in method > Phone > "Phone numbers for testing" in `dev-dairyledger` to avoid real SMS.
- Prod: a Play-distributed build is signed by the Play App Signing key, so that key's SHA must be in `dairyledgerapp`. Local prod builds only work with the upload key's SHA registered.
- If prod SMS is unreliable, check the Play Integrity API is enabled in the Google Cloud project, the SMS region policy allows the country, and the billing/quota plan.

Common errors: `app-not-authorized` or a reCAPTCHA fallback means a missing SHA or stale `google-services.json`; `too-many-requests` means the SMS quota or throttling was hit.

### Deploying rules and hosting

`firebase deploy --only firestore --project <id>` deploys `firestore.rules` and `firestore.indexes.json`; `firebase deploy --only hosting --project <id>` deploys `hosting/public`. Run `firebase login:use <account>` first. The app cannot read or write until the rules are deployed to that project.

### Regenerating configs

Both Google accounts are logged in to the Firebase CLI. `flutterfire configure` writes `android/app/google-services.json`, so move it into the flavor folder afterwards.

```bash
export PATH="$HOME/.npm-global/bin:$HOME/.pub-cache/bin:$PATH"
flutterfire configure -y --account=surajsavant9990@gmail.com --project=dev-dairyledger \
  --platforms=android --android-package-name=com.dairyledger.app.dev --out=lib/firebase_options_dev.dart
mv android/app/google-services.json android/app/src/dev/google-services.json

flutterfire configure -y --account=surajsavant089@gmail.com --project=dairyledgerapp \
  --platforms=android --android-package-name=com.dairyledger.app --out=lib/firebase_options_prod.dart
mv android/app/google-services.json android/app/src/prod/google-services.json
```

### Release signing

Release builds (both flavors) are signed with the same upload keystore as the published Play Store app.
- Keystore: `/home/suraj/Documents/DeploymentSecretes/dairylegerkeystore/upload-keystore.jks`, key alias `upload`. It lives outside the repo and is not copied here.
- `android/key.properties` (copied from the production app; contains the passwords) is read by `build.gradle.kts` and is gitignored. Never commit it or print its contents.
- Debug builds use the normal debug key, so Google sign-in or other SHA-based Firebase features need the debug and release SHA-1/SHA-256 fingerprints registered in the matching Firebase project.

## Tooling notes

- Firebase CLI is installed via npm with a user-level prefix (`~/.npm-global`), so `firebase` should come from `~/.npm-global/bin`. `flutterfire` is in `~/.pub-cache/bin`.
- `firebase login` needs a real interactive terminal; it fails with "non-interactive mode" when run through Claude Code's `!` prefix.
