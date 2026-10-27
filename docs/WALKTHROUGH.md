# End-to-end walkthrough: opening an account and editing an entry

This follows one realistic scenario through the code: **the admin opens an account from the home screen, edits one milk entry, then moves around the weeks.** It shows how navigation, state, reading, rendering and writing fit together. For the caching details see `CACHING.md`; for the design see `ARCHITECTURE.md`. All paths below are under `lib/`.

Contents: Stage 1 Navigation · 2 Finding the account · 3 Loading the bills · 4 Rendering · 5 Editing an entry (the write) · 6 Next actions · 7 How the supplier sees the change · The whole flow in one picture · Log trace of the scenario

## Stage 1: Tapping the account on the home screen

`features/accounts/presentation/home_screen.dart`

```dart
onTap: () => context.push('/account/${account.id}'),
```

`push` asks go_router (`app/router.dart`) for a new screen. Before building it, go_router runs `_redirect`. The user is signed in, the profile is loaded and onboarding is done, so it returns `null` ("fine, continue"). The route `/account/:id` then builds:

```dart
AccountScreen(accountId: s.pathParameters['id']!)
```

## Stage 2: Finding the account (no Firestore)

`features/bills/presentation/account_screen.dart`

```dart
final account = ref.watch(accountByIdProvider(accountId));
```

`accountByIdProvider` does not read Firestore. It picks the account out of the list that `accountsProvider` already holds in memory from the home screen. If it is not there (for example the app was just restarted on this route) the screen shows a spinner until `accountsProvider` has loaded.

The screen builds an app bar (menu with "Delete account") and a `BillView(account, readOnly: false, headerMenu: …)`, where the header menu is the dropdown with "Show QR code" and "Delete this week".

## Stage 3: Loading the bills

`features/bills/presentation/bill_view.dart`

```dart
final bills = ref.watch(billsProvider(account.ref));   // account.ref = (ownerUid, accountId)
return bills.when(loading: …, error: …, data: (state) { … });
```

The first time this is watched, Riverpod creates a `BillsNotifier` for that account and runs its `build()` (`features/bills/providers/bill_providers.dart`). While it runs the screen shows a spinner.

```dart
Future<BillsState> build() async {
  await _repo.sync(account);      // 1. bring the cache up to date
  return _firstPage();            // 2. read the newest 5 bills from the cache
}
```

**1. `BillRepository.sync`** (`features/bills/data/bill_repository.dart`)
- It asks the throttle (`core/firestore/sync_state.dart`) whether this account was synced in the last minute. If so it skips.
- Otherwise it calls `runDeltaSync` (`core/firestore/delta_sync.dart`). That reads the cursor from SharedPreferences and builds the query: no cursor means "the newest 5 bills", a cursor means "bills whose `updatedAt` is newer than the cursor".
- It runs the query with `Source.server`, so only new or changed bills are billed. The SDK stores the results in its cache and the cursor moves to the newest `updatedAt` seen.

```
[SYNC]      bills.ACC: delta since 2026-10-26T09:12:03Z
[FIRESTORE] QUERY bills.ACC from server -> 0 docs, billed 1 read(s)
```

**2. `loadLatest`** queries the cache with `orderBy startDate desc limit 5`. This is free. Each document becomes a `Bill` object and the result is `BillsState(bills, index: 0, hasMore)`.

```
[CACHE]     QUERY bills latest account=ACC -> 2 docs
```

## Stage 4: Rendering

The provider changes from loading to data. Riverpod notifies `BillView`, which rebuilds. `state.current` is the bill at `index 0` (the newest week), and the screen builds:

- **`BillHeader`**: the account name, the `Week: dd-mm-yyyy to dd-mm-yyyy` line and the totals. The totals come from getters on `Bill` that sum its slots.
- **A `TabBar`** with Morning and Evening, opening on the session that matches the time of day.
- **A `TabBarView`** with one `_SessionTable` per session. Each renders one `BillDayRow` per date in `bill.dates`, using `bill.slot(date, session)` (zeros when empty), then a `BillTotalRow` for that session.
- **`BillPager`** with Previous week and Next / Add week.

`BillView` also watches `ratesProvider` to get the rate chart for this account's category. It is loaded from the cache the same way and is only needed for editing.

## Stage 5: Editing an entry (the write)

The admin taps the row `14-10-2026` in the Morning tab.

### 5a. The dialog

- `BillDayRow.onTap` leads to `_editSlot` in `bill_view.dart`, which opens `showSlotDialog` (`features/bills/presentation/slot_dialog.dart`).
- The admin types milk `5` and fat `4.2`. On each fat change the dialog calls `resolveSlot` (`features/bills/models/slot_resolver.dart`), which looks the rate up in the chart. It fills in `52` and shows a live total of `₹ 260.00`.
- A typed rate that differs from the chart becomes a manual override (`rateManual`) and is kept when the fat changes later. A fat with no rate shows an amber hint and still saves, with rate 0.
- Save returns a `BillSlot` through `Navigator.pop`.

### 5b. State is updated first

`_onSlotChanged` calls `BillsNotifier.saveSlot(date, session, slot)`:

```dart
final updated = bill.withSlot(date, session, slot);       // a new Bill object
state = AsyncData(s.copyWith(bills: bills));              // UI updates NOW
_repo.saveSlot(updated, date, session);                   // then persist
```

Setting `state` makes `BillView` rebuild at once: the row shows the new numbers and the session total, and the header totals update. The dialog is already gone. Nothing waits for the network.

### 5c. Writing to Firebase

`BillRepository.saveSlot` calls `trackWrite` (`core/firestore/write_tracker.dart`) with:

```dart
ref.update({
  FieldPath(['days', '2026-10-14', 'M']): slot.toMap(),   // just this one slot
  'totalMilk': …, 'totalAmount': …,
  'updatedAt': FieldValue.serverTimestamp(),
})
```

- It is one document update. `FieldPath` is needed because the date key contains hyphens.
- `trackWrite` does **not** `await` it. The SDK applies the change to its local database straight away and queues the upload, even if the phone is offline.
- Later the server checks the security rules (`firestore.rules`): the caller owns the path, and `startDate`, `endDate` and `cycleDays` are unchanged. It then acknowledges the write. If it rejects it, the SDK rolls the local copy back and a snack bar appears.

```
[CACHE]     WRITE update …/bills/2026-10-12 2026-10-14/M … -> applied to local cache, upload queued
[FIRESTORE] WRITE update … -> acknowledged by server, billed 1 write
```

### 5d. If the fat had no rate

After saving, `_onSlotChanged` shows a snack bar: "No rate for fat 4.7 [Add rate]". Tapping it opens the fat dialog. On save, `ratesProvider.setFat` writes the rate to the chart (`users/{uid}/rates/{CATEGORY}`, another non-awaited write) and the slot is saved again with that rate.

## Stage 6: The next actions

| Action | What the code does | Server cost |
|---|---|---|
| Switch Morning / Evening | The `TabController` switches. The same `Bill` object is shown with a different session. | 0 |
| **Previous week** | `showPrevious()`: if an older bill is already loaded it just changes `index + 1`. | 0 |
| Previous week past the loaded ones | `loadOlder` asks the server for the next 5 bills, which the SDK caches. | up to 5 reads |
| **Pull to refresh** | `refresh()` forces a sync. The delta query now returns the bill we just edited (its `updatedAt` is newer than the cursor) and the cursor advances. The first page is then reloaded from the cache, which includes any unsynced local writes. | 1 plus changed docs |
| Leave and return within a minute | `billsProvider` is auto-disposed, so `build()` runs again; the sync is throttled and skipped, and the cache query serves the screen. | 0 |
| Edit another entry | Back to Stage 5. | 1 write |

## Stage 7: How the supplier sees the change

The admin does nothing extra. The supplier opens their read-only screen, which uses the same `BillsNotifier`. On the next delta sync (app open or pull-to-refresh) the supplier's device finds that this bill's `updatedAt` is newer than its cursor and downloads only that one bill. It then renders from the cache with `readOnly: true`, so the rows have no tap handler and there is no menu.

## The whole flow in one picture

```
tap row ─► router ─► AccountScreen ─► BillView ─watch─► billsProvider (BillsNotifier.build)
                                                            │
                          ┌─────────────────────────────────┤
                          ▼                                 ▼
                 sync (throttled, 1 min)           loadLatest (cache query)
                 server: only changed bills                │
                 → cache + cursor                          ▼
                                                  BillsState ─► rebuild ─► tabs, rows, totals
                                                            ▲
 tap a row ─► slot dialog ─► resolveSlot ─► saveSlot ─► state updated (instant UI)
                                              │
                                              └─► update document ─► local cache (instant) ─► upload queue ─► server ack / reject
```

The same pattern holds throughout: **state updates first, the cache second, and the server last and in the background.** Reads go the other way: from the cache, with the server asked only for changes. That keeps the app fast and usable offline, and keeps Firestore reads low.

## Log trace of the scenario

```
[ROUTER]    (push /account/ACC; no redirect)
[SYNC]      bills.ACC: delta since 2026-10-26T09:12:03Z
[FIRESTORE] QUERY bills.ACC from server -> 0 docs, billed 1 read(s)
[CACHE]     QUERY bills latest account=ACC -> 2 docs
[STATE]     billsProvider: AsyncLoading -> AsyncData(BillsState(2 bills, index=0, …))
   (admin taps a row, types milk 5, fat 4.2, Save)
[STATE]     billsProvider: AsyncData(BillsState(2 bills …)) -> AsyncData(BillsState(2 bills …))
[CACHE]     WRITE update …/bills/2026-10-12 2026-10-14/M BillSlot(milk=5.0 fat=4.2 rate=52.0 manual=false) -> applied to local cache, upload queued
[FIRESTORE] WRITE update … -> acknowledged by server, billed 1 write
   (admin pulls to refresh)
[SYNC]      bills.ACC: delta since 2026-10-26T09:12:03Z
[FIRESTORE] QUERY bills.ACC from server -> 1 docs, billed 1 read(s)
[CACHE]     STORE 1 changed docs from bills.ACC
[SYNC]      cursor[bills.ACC] -> 2026-10-26T09:31:44Z
[CACHE]     QUERY bills latest account=ACC -> 2 docs
```

## Where to look in the code

| Step | File |
|---|---|
| Routes and redirect | `app/router.dart` |
| Account screen and menus | `features/bills/presentation/account_screen.dart` |
| Shared body: header, tabs, rows, pager, dialogs | `features/bills/presentation/bill_view.dart` |
| Row, header and pager widgets | `features/bills/presentation/widgets/` |
| Edit dialog and rate rules | `features/bills/presentation/slot_dialog.dart`, `features/bills/models/slot_resolver.dart` |
| State and navigation between weeks | `features/bills/providers/bill_providers.dart` |
| Reads, sync and writes | `features/bills/data/bill_repository.dart` |
| Delta sync, throttle, cursor | `core/firestore/delta_sync.dart`, `core/firestore/sync_state.dart` |
| Non-awaited writes | `core/firestore/write_tracker.dart` |
| Models | `features/bills/models/bill.dart`, `bill_slot.dart` |
