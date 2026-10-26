# Dairy Ledger v2: Progress and TODO

Last updated: 2026-10-25. Update this file whenever a task is finished or a new one appears.
Legend: `[x]` done, `[ ]` open, `[!]` blocked on a decision or input.

Related docs: `ARCHITECTURE.md` (design and implementation notes), `FIREBASE_SETUP.md` (flavors, Firebase projects, signing, deploys), `screen.md` (wireframes), `../hosting/README.md` (links).

## Verified so far

- [x] `flutter analyze`: no issues
- [x] `flutter test`: 25 tests pass (utils, bill model, rate chart, editable row behaviour, OTP input)
- [x] `flutter build apk --debug --flavor dev -t lib/main_dev.dart` builds; merged manifest has the dev link host and app name
- [ ] **Nothing has been run on a phone yet** (blocked on the items below)

## Blocked: needs you

- [!] **Create the Firestore database** in both Firebase consoles (`dev-dairyledger`, `dairyledgerapp`) if not already created.
- [!] **Deploy rules and indexes** to dev, then prod. Until then every read and write is denied.
`firebase login:use <account>` then `firebase deploy --only firestore --project <id>` (details in `FIREBASE_SETUP.md`). Waiting for your go-ahead.
- [!] **Deploy hosting to dev** (`firebase deploy --only hosting --project dev-dairyledger`) so links and QR codes can open the dev app.
- [!] **Prod fingerprints:** send the Play App Signing SHA-256 and the upload key SHA-256. They replace the two placeholders for `com.dairyledger.app` in `hosting/public/.well-known/assetlinks.json`.
- [!] **Add a Firebase test phone number** in `dev-dairyledger` (Authentication > Sign-in method > Phone) to log in without SMS.

## First run on a device (dev flavor)

- [ ] `flutter run --flavor dev -t lib/main_dev.dart` (or the **Dev (debug)** launch configuration)
- [ ] Login with the test number, OTP, onboarding appears and cannot be skipped
- [ ] Close the app during onboarding, reopen: onboarding appears again
- [ ] Create a rate category, edit a rate, add a custom fat (for example 10.5)
- [ ] Add an account, open it, add a week (range shows start to end, no overlap with an existing week)
- [ ] Enter milk and fat: rate fills in, total updates, row saves when focus leaves; try a fat with no rate (message, rate 0), then a manual rate override
- [ ] Morning/Evening bar, Previous week / Next / Add week label
- [ ] QR code dialog and share link
- [ ] Open the link on a second phone (or `adb shell am start -a android.intent.action.VIEW -d https://dev-dairyledger.web.app/a/<id>`): account opens read-only, appears in the followed list, still there after reopening the app
- [ ] Admin edits an entry, supplier pulls to refresh and sees it
- [ ] Offline: enter data, reconnect, check the console for `[FIRESTORE] WRITE ... acknowledged`
- [ ] Settings: change bill cycle (new weeks only), change names (supplier sees new names), log out
- [ ] Settings > Delete my account on a throwaway user
- [ ] Check the Firestore usage tab against the cost estimates in `ARCHITECTURE.md` section 6

## Before the first Play Store release

- [ ] Prod build: `flutter build appbundle --flavor prod -t lib/main_prod.dart` (release signing is untested)
- [ ] Prod `assetlinks.json` filled in, hosting deployed to `dairyledgerapp`
- [ ] Confirm `adb shell pm get-app-links com.dairyledger.app` shows the domain as `verified`
- [ ] Test the prod flavor from a Play internal testing track (Play App Signing SHA registered in the prod Firebase project)
- [ ] Check whether the Play Console data-deletion declaration points at the old `/delete-account` page of `dairyledgerapp.web.app`; keep a page there (the v1 link will otherwise stop working)
- [ ] Plan for the Blaze billing plan (SMS volume for phone auth)
- [ ] Android app label/icon/splash for the real brand (icon and splash are still the Flutter defaults)

## Next features

- [ ] **Migration from v1** (design in `ARCHITECTURE.md` section 7): find `dl_*.db`, ask to import, write accounts/bills/rates in batches, resumable via `legacyId`, set `migratedFromV1`. Needs `sqflite` and a sample v1 database for testing in dev.
- [ ] **PDF report** of a bill (share through the system share sheet)
- [ ] **Analytics** tab (cost analysis says it is cheap; Pro or free is a product decision). Needs a collection-group index on `bills` by `ownerUid`.

## Later / ideas

- [ ] Mark bills as paid, balances
- [ ] Supplier phone login (so the followed list survives a phone change)
- [ ] Deferred deep link through the Play install referrer (the fallback page already passes `referrer=account=<id>`)
- [ ] Firebase App Check to harden the public read of shared accounts
- [ ] Rotate / revoke a share link (needs moving the account to a new ID)
- [ ] Multi-language labels (Marathi, Hindi), push notifications, multiple staff per dairy
- [ ] Month-aligned bill cycles (1st to 15th, 16th to month end)
- [ ] "Recalculate this bill with the current rate chart" action

## Known limitations and decisions to revisit

- Admin home tiles show no latest bill total (saves a read per account).
- Add week shows the range as a label above a calendar; the calendar does not highlight the whole range.
- After a pull-to-refresh, bills loaded beyond the first page are dropped and the list restarts at the newest.
- Supplier tiles keep the dairy/admin names from when the link was first opened (the account screen itself refreshes them).
- A leaked account link cannot be revoked without moving the account.
- Followed accounts live on the supplier's device only.
- The dev Firebase project also has an older Android app, `com.app.dairyledger`, which is unused.[I have deleted the app]
- Android only: no Firebase config for iOS, web or desktop. [No need only focus on Android]
- Build warning: `firebase_auth` and `firebase_core` still use the Kotlin Gradle plugin; a future Flutter version may require plugin updates.

## Done log

| Date | What |
|---|---|
| 2026-10-25 | Firebase set up for dev and prod flavors, phone auth enabled, signing, docs |
| 2026-10-25 | Architecture designed (3 revisions) and written to `ARCHITECTURE.md` |
| 2026-10-25 | MVP implemented: auth, onboarding, rates, accounts, bills, supplier flow, rules, hosting files, tests |
