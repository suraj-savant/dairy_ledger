# Dairy Ledger v2: Architecture, Data Model, Screens and Features

Status: design (revision 3). The MVP described here is implemented (see section 12 for what was built and where it differs from the design); migration from v1, PDF and analytics are not built yet. It describes the planned replacement for the existing Play Store app ("DairyLedger" v1.0.6: on-device SQLite + Firebase Storage snapshots + email auth), which keeps the same application ID `com.dairyledger.app`.

Related files: `docs/screen.md` (screen wireframes), `docs/FIREBASE_SETUP.md` (flavors, Firebase projects, signing), and `../dairy_ledger_achieve/lib/app/theme.dart` (theme source).

## 0. Decisions and requirements

### Revision 2 (still apply)

| # | Requirement | How the design answers it |
|---|---|---|
| 1 | Suppliers see data as soon as the admin adds or updates it; a refresh or app open is enough | Admin writes go to the single source of truth in Firestore. Suppliers read that same data (no snapshot copy) and fetch changes on app open and pull-to-refresh. |
| 2 | Supplier view = admin account view, read-only, old records, multiple accounts, no re-clicking the link | The account screen is reused with a `readOnly` flag. A followed-accounts list is stored on the supplier's device. Old bills load on demand. |
| 3 | Onboarding: admin name, dairy name, bill cycle days (default 7); days grouped by cycle for totals | `users/{uid}` profile created by an onboarding screen. A "bill" (shown as a "week" in the UI) is one cycle of N days and totals are per bill. |
| 4 | Settings can edit the onboarding answers later | Settings screen edits the profile. Name changes propagate to accounts; cycle changes apply to new bills only. |
| 6 | Cost effective: cache, load only what changed | A whole bill in one document, cache-first reads, delta sync by `updatedAt`, no real-time listeners (section 6). |
| 7 | Fat range 3.0 to 10.0 plus manual extra fat values | Rate chart seeded 3.0 to 10.0 in 0.1 steps. Any other fat can be added with its own rate. |
| 9 | Analytics: check cost, make Pro if expensive | Cost analysis in section 6. Analytics is not part of the MVP. |
| 10 | MVP = rates, accounts, bills, bills visible to suppliers | Build order in section 10. |

### Revision 3 (new in this version)

| # | Requirement | How the design answers it |
|---|---|---|
| 1 | Theme from `theme.dart` | Adopt that `AppTheme` as is (section 3). |
| 2 | Missing rate: show a message to add it, treat the rate as 0, never force the admin | Non-blocking message with an optional "Add rate" action. The entry is saved with rate 0 (section 5, "Bills"). |
| 3 | Admin can override the rate in billing, not strict | The RATE cell is editable. A manual rate is flagged and not overwritten by later fat edits. |
| 4 | Days stay within the bill range; dates not editable; range-based date selection when creating a bill | Fixed-length range picker on create. Rows in a bill are fixed dates within the range. |
| 5 | Screens per `docs/screen.md` | Section 4 specifies every screen from the wireframes, plus the few screens the wireframes do not show. |
| 6 | Onboarding must reappear if the user created an account and closed the app before finishing; keep a completion flag | `users/{uid}.onboardingCompleted`, enforced by a router guard (section 5, "Auth and onboarding"). |
| 7 | Riverpod for state | `flutter_riverpod`, no code generation (section 8). |

Carried over from revision 1:
- Data: Firestore with offline persistence (replaces local SQLite).
- Auth: phone number (OTP) only, for admins. Suppliers do not sign in.
- Migration of v1 data is included (section 7).

## 1. Big picture

```
┌──────────────────────── Phone (Flutter app) ─────────────────────────┐
│                                                                      │
│  Screens ──► Riverpod providers ──► Repositories     Local stores    │
│  Admin: login, onboarding, home,     AuthRepo        (shared_prefs)  │
│    rates, account/bills, settings    ProfileRepo       followed list │
│  Supplier: followed list,            RateRepo          sync cursors  │
│    read-only account/bills           AccountRepo                     │
│                                      BillRepo ◄── SyncService        │
│                                          │                           │
│                     Firestore SDK + persistent local cache           │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ one-shot reads, only changed docs
       ┌─────────────────────────┴──────────────────────────────┐
       │              Firebase (dev OR prod project)            │
       │  Auth (phone OTP)   Firestore (data + rules + indexes) │
       │  Hosting (link domain, assetlinks.json, web fallback)  │
       └────────────────────────────────────────────────────────┘
```

- **Admin:** the milk collector. Signs in with a phone number and does all data entry.
- **Supplier:** no account and no sign-in. The admin shares a link or QR code. Opening it adds that account to the supplier's followed list on their device.
- Screens never talk to Firestore. They watch providers, and providers use repositories, so storage details stay in one layer and tests can swap in fakes.
- `SyncService` owns the "fetch only what changed" logic and the sync cursors.
- The `dev` and `prod` flavors run the same code against different Firebase projects (see `FIREBASE_SETUP.md`).

### Start routing (enforced by a go_router redirect)

```
signed in? ── yes ─► profile loaded? ── no ──► splash / retry
   │                     │
   │                     └ yes ─► onboardingCompleted? ── false ─► /onboarding (cannot leave)
   │                                                     └ true ──► /home
   └ no ─► followed accounts saved? ── yes ─► /supplier
                                     └ no ──► /login   (with "Open a supplier link")
```

A supplier link (`https://<domain>/a/{accountId}`) is handled on any of these paths: it adds the account to the followed list and opens the read-only account screen, signed in or not.

## 2. Data model (Firestore)

```
users/{uid}                          private to the admin
    onboardingCompleted (bool),
    adminName, dairyName, billCycleDays (default 7),
    migratedFromV1, createdAt, updatedAt
users/{uid}/rates/{category}         one rate chart per category
    fats: { "3.0": 45.0, "3.1": 46.0, ... "10.0": 98.0, "10.5": 101.0 }
    updatedAt

accounts/{accountId}                 top-level; auto-ID (20 random chars) = share key
    ownerUid, name, category, adminName, dairyName,
    deleted, createdAt, updatedAt
accounts/{accountId}/bills/{billId}  billId = start date, e.g. "2026-10-12"
    ownerUid, startDate, endDate, cycleDays,      (immutable after create)
    days: { "2026-10-12": { "M": {milk, fat, rate, rateManual?},
                            "E": {milk, fat, rate, rateManual?} }, ... },
    totalMilk, totalAmount, deleted, updatedAt
```

Why it is shaped this way:

| Choice | Reason |
|---|---|
| `onboardingCompleted` on the user document | A persistent flag the router checks on every start. It is created `false` at first sign-in and set `true` only when onboarding is submitted. |
| Accounts top-level with a random ID | The ID is the credential suppliers hold in their link or QR code, so the same data serves admin and supplier with no second copy and no extra writes. |
| A whole bill (all days) in one document | A bill is at most `cycleDays × 2` small entries. Viewing a bill is **1 read** and saving an entry is **1 write** (one document per entry would cost about 14 times more reads per bill view). |
| `rate` stored on every entry | Later rate-chart changes do not alter old bills. |
| `rateManual` on an entry | Marks an admin override. A later fat edit recomputes the rate from the chart only when `rateManual` is absent. It is written only when true. |
| `startDate`, `endDate`, `cycleDays` immutable; date keys limited to the range | Enforces "days stay within the range". Changing the profile's cycle never rewrites existing bills. |
| `totalMilk` and `totalAmount` stored on the bill | List screens show totals without computing, and Firestore `sum()` aggregations become possible later for cheap analytics. |
| `ownerUid` copied onto every account and bill | Rules check ownership from the document itself, with no extra `get()` (rule `get()` calls are billed as reads). |
| `deleted` flag plus `updatedAt` instead of hard deletes | Delta sync only sees existing documents. A soft delete arrives as an update, so supplier caches drop it. Purge later. |
| `adminName` and `dairyName` copied onto accounts | The supplier screen shows them without reading the private profile. Settings edits propagate with a batched update. |
| Rates private under `users/{uid}` | Suppliers only need the rate that was applied, which is on each entry. |
| Fat keys normalized | Rounded to at most 2 decimals and written with at least 1 (`"4.0"`, `"4.25"`). Lookup is by exact normalized key. |

Single-slot updates use `FieldPath(['days', '2026-10-12', 'M'])` (the hyphens in date keys require it), together with the recomputed totals and `updatedAt`.

A missing or zero rate is derived, not stored: a slot with `milk > 0` and `rate == 0` is shown with an amber highlight.

### Security rules (sketch)

```
users/{uid}           read, write: request.auth.uid == uid
                      validation: if onboardingCompleted == true then
                        adminName and dairyName are non-empty and
                        billCycleDays is between 1 and 31
users/{uid}/rates/**  read, write: request.auth.uid == uid

accounts/{accountId}
    get:              anyone (the ID is the key)
    list:             signed in AND resource.data.ownerUid == request.auth.uid
    create:           request.auth.uid == request.resource.data.ownerUid
    update, delete:   request.auth.uid == resource.data.ownerUid
                      (and ownerUid unchanged)
  /bills/{billId}
    read (get, list): anyone (addressing it requires the account ID)
    create:           request.auth.uid == request.resource.data.ownerUid
    update, delete:   request.auth.uid == resource.data.ownerUid
                      (startDate, endDate, cycleDays unchanged)

everything else, including collection-group queries: denied
```

Indexes live in `firestore.indexes.json` and are deployed to both projects: `accounts(ownerUid, updatedAt)` for the admin's delta sync, plus single-field indexes on `bills.updatedAt` and `bills.startDate`.

## 3. Theme

Use the `AppTheme` class from `../dairy_ledger_achieve/lib/app/theme.dart` unchanged, copied to `lib/app/theme.dart` and applied with `MaterialApp.router(theme: AppTheme.lightTheme)`. It replaces the v1 `deepPurpleAccent` theme.

| Item | Value |
|---|---|
| Background | milk white `#FDFBF7` |
| Primary | deep purple `#4527A0` (light `#673AB7`, dark `#311B92`, container `#E6DEFF`) |
| Accent | amber `#FFB300` (container `#FFF0C2`) |
| Text | primary `#211B2B`, secondary `#625B71`; error `#BA1A1A` |
| Material | Material 3, cards radius 16, inputs and buttons radius 12, dialogs radius 20 |

Design rules the theme encodes, which every screen must respect:
- Tap targets at least 56 dp (buttons, list rows, table rows and inputs).
- Body text at least 16 sp.
- Layouts must still fit with the phone font size at 130%. The 5-column bill table therefore uses a short date format (for example `12 Oct`), `FittedBox` or an `overflow-x` scroll fallback, and no fixed pixel widths.

Where amber is used: today's row, and the "rate not set" highlight and message. Brand text uses the theme's text styles (Poppins from v1 is optional).

## 4. Screens

Source: `docs/screen.md`. Items marked "(not in wireframe)" are proposed and need your review.

### Navigation structure

```
/login ─► /otp ─► /onboarding ─► /home ┐
                                       ├─ bottom bar: Home | Rates | Analytics
                         /rates ───────┤
                         /analytics ───┘
/home ─► /add-account          (FAB)
/home ─► /account/:id          (tile)       no bottom bar; Morning | Evening bar instead
/home ─► /settings             (gear icon)
/supplier                      (followed accounts)
/supplier/account/:id          (read-only account screen)
/a/:accountId                  (deep link / QR entry)
```

### Login screen
- Title "DAIRY LEDGER", a phone field with fixed `+91` prefix and 10 digits, and a **LOGIN** button.
- Sends the OTP with `verifyPhoneNumber`, then goes to the OTP screen.
- (not in wireframe) "Open a supplier link" text action for suppliers who have no followed account yet.

### OTP screen
- Title, code boxes and an **Authorise OTP** button.
- The wireframe shows 5 boxes, but Firebase phone OTPs are 6 digits, so the screen uses **6 boxes**.
- Android auto-fill via `verificationCompleted`, a resend timer, and a "change number" action (not in wireframe).
- On success: ensure `users/{uid}` exists (create it with `onboardingCompleted: false` and `billCycleDays: 7` if missing), then the router decides between onboarding and home.

### Onboarding screen
- Fields: **Name**, **Dairy name**, and a **billing cycle stepper** (`< 7 >`, default 7, range 1 to 31).
- Saving writes the names and cycle and sets `onboardingCompleted: true` in one update, then goes to home.
- Cannot be skipped or backed out of. If the user created the account and closed the app, the next start reads `onboardingCompleted == false` and opens this screen again.

### Home screen (Home tab)
- Header "DAIRY LEDGER" with a gear icon (to settings).
- A list of **account tiles**, each showing the account name, its category and (proposed) the latest bill total. Tapping opens the account screen.
- FAB (+) opens Add account. Empty state explains how to add the first account.
- Bottom bar: **Home | Rates | Analytics**.

### Add account screen (not in wireframe)
- Account name and a category dropdown fed by the rate categories.
- If there are no categories yet, it asks the admin to create one in the Rates tab first.
- Name stored uppercase; duplicates rejected.

### Rates screen (Rates tab)
- Header "DAIRY LEDGER" with a menu icon whose item is **Delete category**.
- A **category dropdown** (cow, buffalo, …). If no category exists it shows an **Add category** button instead. Adding a category seeds fat **3.0 to 10.0 in 0.1 steps** with rate 0 (meaning "not set").
- A FAT | RATE list for the selected category.
- FAB (+) opens a dialog to **add a fat** (fat and rate). This is how values outside 3.0 to 10.0 or with extra decimals are added.
- (not in wireframe) Tapping a row edits its rate, and custom fats can be removed.

### Account screen (admin)
- Back arrow and title "Account". An avatar, the **account name**, and an options menu (:) with **Show QR code** and **Delete account**.
  - **QR code:** a dialog with a QR code of the account link `https://<domain>/a/{accountId}` and a Share button. The farmer scans it with the phone camera, or the admin shares the URL.
  - **Delete account:** asks for confirmation, then soft-deletes.
- A header block: **Week: dd-mm-yyyy to dd-mm-yyyy**, **Total Milk**, **Total Bill**. These are the totals for the whole bill (both sessions).
- A table **DATE | MILK | FAT | RATE | TOTAL**, one row per day in the bill range, showing the session selected in the bottom bar. A footer row **TOTAL** shows the milk and amount totals for that session.
- Buttons **Previous week** and **Next / Add week**. The second label is dynamic: **Add week** when the latest bill is being viewed, **Next** otherwise.
- Bottom bar **Morning | Evening** switches the session shown in the table.
- With no bills yet, an empty state shows a prominent **Add week** button.

### Add week (range picker)
- A fixed-length range picker. The admin taps a **start date** and the whole `cycleDays` range highlights, with the end date shown. The end date and the length cannot be changed. For a 7-day cycle starting 12 Oct the range reads `12 Oct 2026 – 18 Oct 2026`.
- The start date is pre-filled with the day after the latest bill's end (or today for the first bill) and can be changed.
- Confirming checks for overlap with existing bills (cache-first query of bills near the chosen start) and rejects an overlap with a message naming the clashing bill.
- Creates the bill with `startDate`, `endDate` and `cycleDays`.

### Bill rows (inside the account screen)
- The DATE cell is fixed and not editable. Only dates inside the bill range exist.
- MILK, FAT and RATE are inline inputs. See "Bills" in section 5 for the rate rules.

### Settings screen (not in wireframe)
- Edit **Name**, **Dairy name** and **Billing cycle** (the same fields as onboarding). A note says a cycle change applies to new bills only.
- **Logout** and **Delete my account** (required by Google Play). Optionally the app version.

### Supplier screens (not in wireframe)
- **Supplier home** (`/supplier`): the followed accounts as tiles, in the same style as home tiles, showing dairy name, account name and latest bill total. Remove from list is a long-press or swipe action. No bottom bar.
- **Supplier account screen**: the admin account screen with `readOnly = true`: no options menu, no inline inputs, no Add week. Previous and Next only, plus pull-to-refresh and "Load older".
- If the account was deleted by the admin, a "no longer available" state with a remove action.

### Analytics tab
- The wireframe has the tab, but analytics is not in the MVP (section 6). The tab shows a "Coming soon" placeholder until it is built.

## 5. Features and how each works

### Auth and onboarding
1. The admin enters a phone number and then the OTP. Dev uses Firebase test numbers.
2. On the first successful sign-in the app creates `users/{uid}` with `onboardingCompleted: false` and `billCycleDays: 7` if it does not exist yet.
3. The router redirect reads the profile on every start. While `onboardingCompleted` is not `true`, every route except `/onboarding` redirects there, so closing the app mid-onboarding always resumes it.
4. Submitting onboarding validates the fields (non-empty names, cycle 1 to 31) and sets `onboardingCompleted: true` together with the answers. Security rules re-check the same conditions.
5. If the profile cannot be read (offline with no cache), the app shows a retry state rather than guessing.
6. Logout keeps all data in the cloud.

### Settings
- Editing names rewrites `adminName` and `dairyName` on the admin's accounts (batched, rare).
- Changing the bill cycle affects only bills created afterwards. Existing bills keep their own `cycleDays` and range.

### Rates
- A category is a rate chart in one document: one read, then cached.
- Seed 3.0 to 10.0 (71 values) at rate 0; add custom fats; edit rates; remove custom fats; delete a category (confirmation).

### Accounts
- Create, soft-delete. The admin's accounts are loaded with an owner query and kept current by delta sync.
- Deleting asks for confirmation. Suppliers following it see "no longer available".

### Bills (core feature)
1. **Create:** Add week uses the fixed-length range picker. The bill gets `startDate`, `endDate = start + cycleDays − 1` and `cycleDays` from the profile at that moment. These never change afterwards.
2. **Rows:** one row per day in the range for the selected session. Dates are fixed; no dates can be added or edited.
3. **Entering data:** the admin types **milk** and **fat**. The app looks up the rate for that fat in the category chart and fills the RATE cell. `total = milk × rate` rounded to 2 decimals. The slot saves on field blur, as one write, along with recomputed bill totals.
4. **Missing rate (never blocking):** if the fat has no rate (not in the chart, or still 0):
   - the entry is saved anyway with **rate 0**, so the total is 0;
   - a non-blocking message appears ("No rate for fat 4.2"), with an optional **Add rate** action that opens the add-fat dialog prefilled with that fat and, once saved, applies the rate to this entry;
   - the RATE cell is highlighted in amber until it has a rate. The admin can ignore all of this.
5. **Rate override (not strict):** the RATE cell is always editable. A typed rate is saved with `rateManual: true` and is kept even when the fat is edited later. Clearing the RATE cell removes the override and goes back to the chart lookup.
6. **Everything optional:** milk, fat and rate can each be entered in any order or left empty (an empty value counts as 0). Only basic number checks apply (non-negative).
7. **Totals:** the header shows whole-bill totals; the table footer shows the totals of the selected session.
8. **Navigation:** Previous and Next move between bills (newest first, loaded five at a time). On the latest bill the Next slot becomes **Add week**.
9. A bill can be soft-deleted.

### Supplier view
1. The admin shows the account QR code or shares `https://<domain>/a/{accountId}`.
2. The supplier opens it (camera, WhatsApp or browser). The app reads the account document once, saves `{accountId, accountName, dairyName, adminName}` into the followed list on the device, and opens the account.
3. The supplier account screen is the admin account screen with `readOnly = true`.
4. On later launches the supplier lands directly on the followed list; no link is needed. Each tile refreshes through `SyncService` (section 6).
5. Pull-to-refresh fetches changes. Cached bills also work offline.
6. A supplier can follow several accounts (several dairies too) and remove any of them.

## 6. Data flows, cost and caching

**Admin enters milk**
```
types 5.5 L, fat 4.2, leaves the field
  → RateRepo: chart["4.2"] = 52          (cache, no network)
  → BillRepo: total = 286.00, recompute bill totals
  → one update on accounts/{a}/bills/{b}: that slot + totals + updatedAt
  → the UI updates from the local cache immediately; the SDK uploads when online
```

**Supplier opens the app**
```
/supplier (followed list from the device)
  → for each account: SyncService.sync(accountId)
        query bills where updatedAt > cursor, one-shot, from the server
        → typically 0 or 1 changed bill (minimum charge: 1 read per query)
        → results land in the Firestore cache; cursor := newest updatedAt seen
  → screens read from the cache (free)
```

**Supplier loads older bills**
```
"Load older" → server query: bills orderBy startDate desc, startAfter last, limit 5
  → the SDK stores the page in the cache. (A cache-only query could return a page with
    gaps, because only recently changed old bills are cached.)
```

Principles:
- No real-time listeners. Providers load once and refresh after their own writes.
- Display always reads from the local cache. Network reads happen only in `sync` and for pages not yet cached.
- Persistence enabled with an unlimited cache size, so history stays on the device.
- Sync cursor per account in `shared_preferences`, taken from the server `updatedAt` of the newest document seen (never the phone clock).
- Refreshes are throttled (for example once a minute per account); pull-to-refresh bypasses it.
- Writes happen on field blur, not on every keystroke.

Estimated usage (Firestore free quota is 50k reads, 20k writes and 20k deletes per day, plus 1 GiB; check current pricing before launch):

| Action | Reads | Writes |
|---|---|---|
| Admin saves one milk slot | 0 | 1 |
| Admin with 100 accounts, both sessions, a full day | 0 | about 200 |
| Admin opens an account (cached) | 0 | 0 |
| Sign-in plus onboarding | 1 | 2 |
| Supplier opens the app, per followed account | about 2 (1 delta query plus the changed bill) | 0 |
| Supplier loads a page of 5 old bills (first time only) | 5 | 0 |
| Same page again | 0 (cache) | 0 |

A supplier with two accounts who opens the app twice a day costs about 8 reads a day, so on the order of 5,000 such suppliers fit inside the free read quota.

Analytics (post-MVP) is cheap by design, so cost alone does not require making it Pro:
- Range totals by `sum(totalAmount)` or `sum(totalMilk)` over bills are aggregation queries billed at 1 read per 1,000 index entries scanned. A year of totals for 100 accounts (about 5,200 bills) is roughly 6 reads. Aggregations need a network connection.
- A per-day chart needs the bill documents, about 1 read per bill touched, then cached. A 4-week chart across 100 accounts is a few hundred reads on first view and nearly none afterwards.
- It would need a collection-group query and index on `bills` filtered by `ownerUid`, plus a matching rule. Making it Pro would be a product choice, not a cost need.

## 7. One-time migration from v1

v2 keeps the application ID, so the v1 SQLite file (`dl_*.db`) stays on the phone after the update.

1. After onboarding completes, look for `dl_*.db` files in the app's database folder. If there are several, ask which to import (show the account count for each).
2. Ask "Import data from the previous version?".
3. Read the v1 tables and write v2 documents:
   - `ACCOUNTS` become accounts (new random IDs, a `legacyId` field for resuming).
   - `DAYS` grouped by account and `WEEKINITIALDATE` become one bill each: `startDate` = week start, `endDate` = start + 6, `cycleDays` = 7. Zero-milk placeholder rows are skipped.
   - `RATES` become `rates/{category}`. Rows with rate 0 are skipped. Values above 10.0 are kept as custom fats.
4. Write in batches of 500. A retry skips accounts that already exist with a matching `legacyId`. Set `migratedFromV1 = true` at the end.

Cost: one write per bill plus one per account, within the free write quota for typical v1 data. `sqflite` stays as a dependency only for this step. To test in dev (a different application ID), copy a sample `.db` file into the dev app with `adb`.

Not migrated: v1 supplier links (`/userscreen/<hash>/<hash>`) stop working and the admin sends new links or QR codes. Old Storage JSON is left in place.

## 8. State management (Riverpod)

`flutter_riverpod` with hand-written `Notifier` and `AsyncNotifier` providers (no code generation, so no `build_runner`). The app is wrapped in a `ProviderScope`; tests override repository providers with fakes.

| Provider | Kind | Role |
|---|---|---|
| `flavorProvider` | `Provider` | dev or prod: Firebase options and link domain |
| `authStateProvider` | `StreamProvider<User?>` | signed-in user |
| `profileProvider` | `AsyncNotifier` | `users/{uid}` (cache-first); exposes `onboardingCompleted` and `billCycleDays` |
| `routerProvider` | `Provider<GoRouter>` | watches auth, profile and followed list; its redirect enforces the start routing and the onboarding guard |
| `ratesProvider` | `AsyncNotifier` | category list and the selected category's chart |
| `accountsProvider` | `AsyncNotifier` | the admin's accounts, with delta sync |
| `billsProvider(accountId)` | family `AsyncNotifier` | paged bill list for an account |
| `billProvider(accountId, billId)` | family `AsyncNotifier` | one bill: entry edits, rate lookup and override, totals |
| `sessionProvider` | `NotifierProvider` | Morning or Evening in the account screen |
| `followedAccountsProvider` | `Notifier` | supplier list, persisted in `shared_preferences` |
| `syncServiceProvider` | `Provider` | delta sync and cursors |
| `*RepositoryProvider` | `Provider` | repositories (overridable in tests) |

Suggested layout (feature-first):
```
lib/
  app/        theme.dart, router.dart, app.dart, flavor.dart
  core/       firestore paths, date and number helpers, shared widgets
  features/   auth, onboarding, home, rates, account (bills), supplier, settings, analytics
              each with: data (repositories), models, providers, screens, widgets
  main_dev.dart, main_prod.dart, main_common.dart
```

## 9. Limits and trade-offs

- **Link = credential.** Anyone holding an account link or QR code can read that account. A leaked link cannot be revoked without moving the account to a new ID. Optional hardening later: Firebase App Check.
- **Followed accounts live on the supplier's device.** A new phone or cleared app data means scanning or tapping the link again. A supplier phone login could fix that later.
- **No deferred deep links.** Firebase Dynamic Links is shut down, so a supplier without the app installs it and then scans or taps again. Optional later: pass the account ID in the Play Store `referrer` parameter and read it on first launch (Android).
- **Hosting is required** for verified App Links (`assetlinks.json` with the Play App Signing SHA-256) and a small web fallback page. Prod uses `dairyledgerapp.web.app`; dev needs its own site (for example `dev-dairyledger.web.app`), set per flavor with a manifest placeholder. v1 registered a `/delete-account` link, so check whether the Play Console data-deletion declaration points at it and keep that page available.
- **Phone SMS volume:** the free SMS quota is small. Plan for the Blaze billing plan before launch.
- **Single writer assumed.** Two phones editing the same slot at once would be last write wins.

## 10. Build order

Each phase is runnable on `dev`.

**MVP** (all implemented except where marked, see section 12)
1. Foundations: add `flutter_riverpod`, `go_router`, `shared_preferences`, `app_links`, `qr_flutter` and `share_plus`; copy `AppTheme`; flavor provider; router with the redirect guards; Firestore rules and indexes in the repo; model and repository skeletons. Replace the current prototype code (the counter demo and the `setState`-based phone login in `lib/auth`).
2. Login, OTP, profile creation and the onboarding screen with its completion flag.
3. Home shell with the bottom bar, Settings (profile edit).
4. Rates screen.
5. Accounts: home list, Add account, account menu (delete).
6. Account screen and bills: header and totals, Morning/Evening table, inline entry, missing-rate message, rate override, Add week range picker, Previous and Next.
7. Supplier flow: Hosting site and `assetlinks.json` for dev, deep link `/a/:accountId`, QR code and share, followed list, read-only reuse of the account screen, `SyncService` and caching.

**Before the first release**
8. Migration from v1.
9. Delete my account (a Play requirement), prod Hosting and App Links, test from a Play internal track.

**Later**
- PDF report of a bill.
- Analytics (cheap as designed; Pro or free is a product decision).
- Marking bills paid, multi-language labels, push notifications, multiple staff per dairy, supplier phone login, optional "recalculate this bill with the current chart" action.

## 11. Assumptions to confirm

1. **Analytics tab:** shown as a "Coming soon" placeholder because it is in the wireframe. Say if you would rather hide it until it exists.
2. **"Current week" on the Add/Next button:** read as the latest bill, so the button is **Add week** on the newest bill and **Next** on older ones.
3. **"Week" label:** kept from the wireframe even when the cycle is not 7 days. Say if you want a neutral label such as "Bill" or "Period" for other cycle lengths.
4. **OTP boxes:** 6, not the 5 in the sketch, because Firebase sends 6-digit codes.
5. **QR scanning:** the farmer scans with the phone's own camera, which opens the link. An in-app scanner is not planned for the MVP.
6. **Screens not in the wireframe** (Add account, Settings, supplier screens) are proposed in section 4 for review.
7. **Riverpod without code generation:** chosen to avoid `build_runner`. Say if you prefer the generator-based style.

## 12. Implementation notes

What exists in the code and where it differs from the design above.

### Project structure

```
lib/
  main_dev.dart, main_prod.dart   flavor entry points (main.dart just calls dev)
  main_common.dart                Firebase init, Firestore cache settings, ProviderScope
  app/                            app.dart, router.dart (redirect rules), theme.dart, flavor.dart
  core/                           constants, logger, messenger, providers, provider_observer
    firestore/                    paths, cache-first reads, delta sync, sync cursors, write tracker
    utils/                        fat keys, formatters
    widgets/                      loading/empty/error views, dialogs, cycle stepper
  features/<feature>/             data (repositories), models, providers, presentation
    auth, profile, rates, accounts, bills, supplier, analytics (placeholder)
firestore.rules, firestore.indexes.json, hosting/   Firebase config in the repo
test/                             unit and widget tests
```

### Behaviour worth knowing

- **Date fields** `startDate` and `endDate` are stored as `yyyy-MM-dd` strings (they sort chronologically and are cheap to range-query), not as timestamps.
- **Writes are not awaited.** A Firestore write future only completes when the server acknowledges it, which never happens offline. Repositories call `trackWrite`, the UI continues from the local cache, and a rejected write shows a snack bar.
- **Delta sync** (`core/firestore/delta_sync.dart`) uses `Source.server` so an offline attempt throws and leaves the cursor untouched. Cursors are kept in `shared_preferences` as `seconds:nanos` of the newest server `updatedAt`.
- **Latest bills come from the cache after a sync; older pages always come from the server** (see section 6).
- **Admin home tiles** show name and category only. Showing a latest total per account would cost one extra read per account. Supplier home tiles do show the latest bill, because those accounts are synced on open anyway.
- **Deleting an account or a week is a soft delete** (`deleted: true`), so supplier devices notice it on their next sync.
- **Settings > Delete my account** hard-deletes all of the admin's accounts, bills, rates and profile (awaited, needs network), then deletes the login. If Firebase asks for a recent login, the data is already gone and the user is logged out with a message.
- **Account screen menu** also has "Delete this week" (not in the wireframe).
- **Session tab** (Morning/Evening) defaults to the time of day (before 15:00 is Morning).
- **Theme**: `AppTheme` from `dairy_ledger_achieve` plus Material 3 navigation bar, snack bar, list tile and divider themes and a light status bar.

### Debug logging

All logging goes through `logd(tag, message)` and prints only in debug builds. Filter the console by tag:

| Tag | What it shows |
|---|---|
| `AUTH` | sending the OTP (number masked), verifying, sign-in, sign-out |
| `FIRESTORE` | every read (cache or server) and every write (queued, acknowledged or failed) |
| `SYNC` | delta syncs, documents fetched, cursor movements, throttling |
| `STATE` | every Riverpod provider change (`AppProviderObserver`), onboarding, followed list |
| `ROUTER` | redirects and shared links being opened |

### Not built yet

Migration from v1, PDF report, analytics, and the production Hosting setup (see `hosting/README.md`).
