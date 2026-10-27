# How caching works in Dairy Ledger

This document explains where data lives on the phone, when the app reads from the local cache or from Firebase, when it writes, and what the debug log tags mean. It is written for the person debugging or changing the data layer. The design reasons (cost, offline use) are in `ARCHITECTURE.md` section 6; this file is the detailed "how".

Contents: 1. The four places data lives · 2. Log tags · 3. Reading · 4. Writing · 5. Delta sync · 6. Lifecycle · 7. Offline behaviour · 8. Cache configuration · 9. Cost per action · 10. Known limits and troubleshooting · 11. Example log traces · 12. Code map

## 1. The four places data lives

```
 ┌────────────────────────────── the phone ──────────────────────────────┐
 │                                                                        │
 │  Screens ──watch──► Riverpod providers        (A) in-memory state      │
 │                          │                        lost when the app    │
 │                          ▼                        process ends         │
 │                     Repositories                                       │
 │                          │                                             │
 │            ┌─────────────┴──────────────┐                              │
 │            ▼                            ▼                              │
 │  (B) Firestore SDK local cache     (C) shared_preferences              │
 │      on disk, managed by the SDK       sync cursors, followed list     │
 │      documents + queued writes         (also on disk)                  │
 └────────────┬───────────────────────────────────────────────────────────┘
              │ network (only when needed)
              ▼
        (D) Firestore server  (the source of truth)
```

| | What | Survives app restart | Cleared by logout |
|---|---|---|---|
| **A** Provider state | the lists and bills currently on screen | no | rebuilt after sign-in changes |
| **B** Firestore cache | every document the app has read or written, plus writes not yet uploaded | yes | **yes** |
| **C** `shared_preferences` | sync cursors (`sync_cursor.*`), followed-accounts list | yes | cursors **yes**, followed list no |
| **D** Server | all data | n/a | n/a |

Two ideas run through everything:

1. **Screens read from the cache (B), not from the server.** The server is only contacted by an explicit *sync* (section 5) or when something is missing from the cache.
2. **Writes go to the cache first, then to the server.** The UI updates at once from the cache, and the SDK uploads in the background, also after the phone was offline.

The Firestore SDK (B) is a real database on the phone, not just a memory cache. It stores documents it has seen, answers queries from them (also with no network) and keeps a queue of writes waiting for upload (queued writes are included in cache query results).

## 2. Log tags

All logs are debug-only and go through `logd(tag, message)` (`lib/core/logger.dart`). In the console filter on `[TAG]`.

| Tag | Meaning | Typical lines |
|---|---|---|
| `CACHE` | the **local cache (B)**: nothing here costs money or needs a network | `READ users/… -> hit`, `READ users/… -> miss, asking the server`, `QUERY users/…/accounts -> 3 docs`, `WRITE … -> applied to local cache, upload queued`, `STORE 2 docs from …`, `CLEAR everything` |
| `FIRESTORE` | traffic with the **server (D)**: this is what is billed | `QUERY … from server -> 2 docs, billed 2 read(s)`, `READ … from server`, `WRITE … -> acknowledged by server, billed 1 write`, `WRITE … -> REJECTED by server (permission-denied), local change rolled back` |
| `SYNC` | **delta-sync decisions** (C): why or why not the server was asked | `bills.<id>: initial load (no cursor yet)`, `bills.<id>: delta since 2026-10-26T…`, `skip bills.<id> (synced 12s ago)`, `cursor[…] -> …`, `skipped (unavailable), using the cache only` |
| `STATE` | **provider changes (A)** and local settings | `profileProvider: AsyncLoading -> AsyncData(…)`, `followed accounts saved (2)` |
| `AUTH` | sign-in and sign-out | `verifyPhoneNumber ******1234`, `signed in uid=…`, `logout: clearing local data first` |
| `ROUTER` | redirects and shared links | `redirect /splash -> /home`, `opening shared account …` |

How to read a trace: for any data load you should see, in order, a `SYNC` decision, optionally a `FIRESTORE` query with its billed reads, a `CACHE STORE` for documents that arrived, and finally a `CACHE QUERY/READ` that feeds the screen. **If a screen shows data and there is no `FIRESTORE` line, it came entirely from the cache and cost nothing.** To count what a session cost, search for `billed`.

## 3. Reading: when, from where

Every read goes through a repository. `core/firestore/firestore_reads.dart` has three helpers:

| Helper | Source | Log | Cost |
|---|---|---|---|
| `getDocCacheFirst(ref)` | cache; if the document is not cached, the server (which then caches it) | `CACHE … hit` or `CACHE … miss` + `FIRESTORE READ` | 0 on a hit, 1 read on a miss |
| `getQueryFromCache(query)` | cache only | `CACHE QUERY … -> N docs` | 0 |
| `getQueryFromServer(query)` | server, falling back to the cache when offline | `FIRESTORE QUERY …` + `CACHE STORE` | 1 per returned document (at least 1) |

Delta sync (section 5) uses its own server query with `Source.server`.

### What is read, and when

| Data | Trigger | Path | Source | Notes |
|---|---|---|---|---|
| **Profile** `users/{uid}` | provider built after sign-in (app start, login) | `ProfileRepository.fetchOrCreate` | cache first, server only on a miss | A missing document means a first login: it is **created** with `onboardingCompleted: false`. Not refreshed during normal use (see section 10). |
| **Rates** `users/{uid}/rates/*` | provider built after sign-in | `RateRepository.loadAll` | cache query; if empty, server | One document per category, so a whole chart is one cached read. Not refreshed during normal use. |
| **Admin's accounts** `users/{uid}/accounts` | app start (home screen), pull-to-refresh | `AccountRepository.loadOwned` | **delta sync** with the server, then a cache query | Pull-to-refresh forces the sync; otherwise it is throttled to once a minute. |
| **Latest bills of an account** | opening the account screen | `BillRepository.sync` then `loadLatest` | delta sync, then a cache query for the newest 5 | Same for admin and supplier screens (they share `billsProvider`). |
| **Older bills** | "Previous week" past the loaded ones | `BillRepository.loadOlder` | **always the server**, 5 per page, then cached | A cache-only page could have gaps (see section 5). |
| **Overlap check** when adding a week | Add week confirmed | `BillRepository.findOverlap` | server query of bills starting within about a month before the new range | A few documents at most. Offline it falls back to the cache. |
| **Supplier home tile** (latest bill) | opening the supplier home screen | `latestBillProvider` | delta sync, then a cache query for 1 bill | About 1 read for the sync plus any changed bill, per followed account. |
| **Supplier account document** | opening a followed account | `AccountRepository.fetchPublic(refresh: true)` | server **at most once per 6 hours** per account per app run, otherwise cache first | This is how a supplier notices a deleted or renamed account. |
| **Account from a shared link** | `/a/{ownerUid}/{accountId}` opened | `fetchPublic` | cache first, then server | Then it is saved to the followed list. |
| **Followed list** | provider built | `FollowedStore.read` | `shared_preferences` | Not Firestore. |

## 4. Writing: how and when

All writes go through `trackWrite` (`core/firestore/write_tracker.dart`). The key fact: a Firestore write **future completes only when the server acknowledges it**, which never happens while offline. So the app never awaits it:

```
repository.saveSlot(...)
   1. SDK applies the change to the local cache at once        [CACHE]   WRITE … -> applied to local cache, upload queued
   2. the provider updates its state; the screen shows the change immediately
   3. the SDK uploads when it can (now, or when the phone is back online)
   4a. server accepts                                           [FIRESTORE] WRITE … -> acknowledged by server, billed 1 write
   4b. server rejects (rules, document missing, …)             [FIRESTORE] WRITE … -> REJECTED …, local change rolled back
        and a snack bar "Could not save changes (code)" is shown
```

| Action | Document written | Operation | Notes |
|---|---|---|---|
| First login | `users/{uid}` | `set` | `onboardingCompleted: false`, `billCycleDays: 7` |
| Onboarding / Settings edit | `users/{uid}` | `set` with merge | Changed names also update every account (batched). |
| Create / edit / delete a rate | `users/{uid}/rates/{category}` | `set` / `update` with `FieldPath(['fats', key])` / `delete` | Fat keys contain a dot, hence `FieldPath`. |
| Add account | `users/{uid}/accounts/{id}` | `set` | The ID is generated on the phone, so it works offline. |
| Delete account / week | the account or bill document | `update` with `deleted: true` | **Soft delete**, so other devices' delta sync sees it. |
| Add week | `…/bills/{startDate}` | `set` | Empty days. |
| Edit a milking slot | `…/bills/{startDate}` | `update` of one `days.{date}.{M|E}` field, plus `totalMilk`, `totalAmount`, `updatedAt` | One write per saved slot. |
| Delete my account | everything under the user | awaited batched deletes | The only place where writes **are awaited** (needs the network). |

Details worth knowing:

- Every write sets `updatedAt` with `FieldValue.serverTimestamp()`. While a write is pending the field is empty locally; the app never reads `updatedAt` from local data, only from server results (section 5).
- Pending writes appear in cache query results. The `CACHE QUERY` log adds *(includes unsynced local writes)* when that happens.
- Writes are applied in the order issued. A rejected write is rolled back in the cache, but the provider's in-memory state is not (the screen can keep showing the rejected value until it is reloaded). Pull-to-refresh or reopening the screen reloads from the cache.
- Updating a document that no longer exists on the server (for example deleted in the console) is rejected with `not-found`.
- Saving a slot twice quickly produces two queued updates; the later one wins.

## 5. Delta sync: fetching only what changed

`runDeltaSync` (`core/firestore/delta_sync.dart`) keeps the cache current without re-reading unchanged documents.

**The cursor.** For each collection the app remembers the newest server `updatedAt` it has received, in `shared_preferences` as `seconds:nanos` under `sync_cursor.<key>`. Keys: `accounts.<uid>` and `bills.<accountId>`. It is the *server's* timestamp, never the phone clock, so a wrong phone clock cannot make the app skip data.

**The query.**

| Situation | Query | Log |
|---|---|---|
| No cursor yet (first time) | accounts: the whole collection. bills: the newest 5 by `startDate` | `SYNC … initial load (no cursor yet)` |
| Cursor exists | documents with `updatedAt > cursor`, ordered by `updatedAt` | `SYNC … delta since <time>` |

The query uses `Source.server`. If the phone is offline it **throws**, the sync is skipped and the cursor is left untouched, so nothing is ever skipped by mistake (`SYNC … skipped (unavailable), using the cache only`). After a successful query the SDK stores the returned documents in the cache (`CACHE STORE`), the cursor moves to the newest `updatedAt` seen (`SYNC cursor[…] -> …`), and the screen then reads the cache.

**Throttle.** To stop screens that open repeatedly from re-syncing, a sync for the same key is skipped if one ran less than **1 minute** ago (in memory, so it resets when the app restarts). Pull-to-refresh bypasses it (`force`). The supplier account document has its own 6-hour window.

**Why soft deletes.** A delta query can only return documents that exist. A document removed with `delete()` simply stops appearing, and nothing tells the phone it is gone. So the app never hard-deletes shared data; it sets `deleted: true`, which changes `updatedAt` and arrives in the next delta. Screens filter deleted documents out.

**Why older bill pages come from the server.** After the first sync the cache holds the newest bills plus any older bill that happened to change later. A cache-only "older than X" query could then return a page with holes. So `loadOlder` always asks the server for the next 5 and lets the SDK cache them.

**Cache reset guard.** If the cache query for the latest bills is empty although a cursor exists (the cache was cleared but the cursor was not), the app clears that cursor and runs a fresh initial load (`SYNC cache empty despite cursor … reloading`).

**Pull-to-refresh on the account screen** forces a sync and then reloads the newest page of bills; older pages loaded earlier are dropped from the screen (not from the cache).

## 6. Lifecycle: what happens when

**App start (already logged in).** Provider state is empty; the Firestore cache and cursors are on disk.
1. `STATE authStateProvider` → user found.
2. `CACHE READ users/{uid} -> hit` (profile, no network). Router sends the user to the home screen (or onboarding if `onboardingCompleted` is false).
3. Home screen builds the accounts provider: `SYNC accounts… delta`, one `FIRESTORE QUERY` (1 billed read when nothing changed), then a `CACHE QUERY` that feeds the list.
4. Rates load from the cache.

**Login on a new phone / after logout.** The cache is empty, so the profile read is a `CACHE … miss` followed by a `FIRESTORE READ`; accounts do an *initial load*; rates read the server because the cache is empty.

**Opening an account.** `SYNC bills.<id>` (initial load or delta, throttled to once a minute), then `CACHE QUERY bills latest`. Switching tabs, week or session costs nothing; "Previous week" past the loaded bills costs up to 5 reads.

**Editing.** Section 4. Nothing is read.

**Supplier opening a link.** `ROUTER opening shared account`, a cache-first read of the account (usually a server read the first time), the account is saved to the followed list (`STATE followed accounts saved`), then the same bill loading as above, with no sign-in.

**Supplier reopening the app.** The followed list comes from `shared_preferences`. The home screen syncs each followed account (delta) to show the latest total; opening an account refreshes its document at most every 6 hours.

**Logout** (`SessionService.logout`):
1. If changes are still waiting to upload (checked with a 5-second `waitForPendingWrites`), the user is asked before they are discarded.
2. `CACHE CLEAR everything`: the Firestore instance is terminated and `clearPersistence()` empties the cache (the instance is recreated by the next read or write).
3. `SYNC clearing N cursors` and the in-memory throttle is reset. **The cache and the cursors are always cleared together**: a cursor without its cache would make delta sync skip records, and a cache without cursors would keep stale ones.
4. The user is signed out. The supplier followed list stays.

**Settings > Refresh all data.** The same clearing (steps 1 to 3) while staying signed in, then the profile, rates and accounts providers reload from the server.

**Delete my account.** Server data is deleted first (awaited), then the login, then the cache is cleared.

**Uninstall / clear app data.** Removes everything on the phone; the server data is untouched.

## 7. Offline behaviour

| Action | Offline result |
|---|---|
| Open screens with already-cached data | Works, from the cache. |
| Delta sync | Skipped (`SYNC … skipped`), cursor unchanged. Screens show the cache. |
| Edit slots, add accounts and weeks, edit rates | Work immediately (`CACHE WRITE … queued`); uploaded when the phone reconnects (`FIRESTORE WRITE … acknowledged`). |
| Add week overlap check | Falls back to the cache, so an older uncached bill could be missed. |
| Older bills not yet cached | Fail to load (server needed). |
| Login / OTP | Needs the network. |
| First run with an empty cache | Profile load fails and the splash screen offers "Try again". |
| Delete account, Refresh all data | Refresh asks first if changes are unsynced; deletion needs the network. |

If the app is closed offline with queued writes, they are kept on disk and uploaded the next time it runs with a connection.

## 8. Cache configuration

- Set in `main_common.dart`: persistence on, `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED`. The plugin only accepts that value or 1 to 100 MB, and the Android plugin applies "unlimited" as the 100 MB default.
- When the cache exceeds its limit the SDK evicts the least recently used documents. One dairy's data is a few megabytes, so this is not a practical concern, but it is why delta sync assumes unchanged cached documents stay put. (If the cache were emptied the guard in section 5 reloads the newest bills, but older cached bills would be re-read only when scrolled to.)
- No real-time listeners are used anywhere. A listener would keep reading changes; instead the app syncs on demand.
- If applying the settings ever fails it is logged (`CACHE could not apply cache settings`) and the app continues with defaults.

## 9. Cost per action (Firestore billing)

| Action | Reads | Writes |
|---|---|---|
| Edit one milking slot | 0 | 1 |
| Open a screen whose data is cached | 0 | 0 |
| App start, accounts delta sync with no change | 1 | 0 |
| Open an account, delta sync with no change | 1 | 0 |
| Open an account for the first time | up to 5 (newest bills) | 0 |
| "Previous week" past the loaded bills | up to 5, once | 0 |
| Pull-to-refresh | 1 plus changed documents | 0 |
| Supplier opens the app, per followed account | about 2 | 0 |
| Supplier opens an account, document refresh | 1, at most every 6 hours | 0 |
| Add week | 1 or more (overlap check) | 1 |
| First login | 1 | 1 to 2 |
| Logout then login again | the initial loads again (profile 1, accounts N, rates per category, newest bills per opened account) | 0 |

Billing note: a query always costs at least 1 read, even when it returns nothing. The free daily quota is 50k reads and 20k writes.

## 10. Known limits and troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| A record deleted in the **Firebase console** still shows in the app | Hard deletes are invisible to delta sync (section 5) | Settings > Refresh all data, or log out and in |
| Edits fail with `not-found` | The document was deleted on the server but is still cached | Same |
| Profile or rates changed from another phone do not show | They are read cache-first and never re-synced during normal use | Settings > Refresh all data (accounts and bills do sync) |
| A change made on another phone to an account or bill does not show | Delta sync throttle (1 minute) or the screen was not reopened | Pull-to-refresh |
| Supplier still sees an account the admin deleted | The account document is refreshed at most every 6 hours | Reopen after that, or the bills sync will not hide it; remove it from the list |
| `Could not save changes (permission-denied)` | Firestore rules not deployed to this project, or old rules | `firebase deploy --only firestore --project <id>` |
| Lists empty on a fresh install and logs show `skipped (unavailable)` | No network | Connect and pull-to-refresh |
| Data from the previous user visible after switching accounts | Should not happen: logout clears the cache. Check the log for `CACHE CLEAR failed` | Settings > Refresh all data |
| Changes made offline lost after logout | Logout clears the cache; the app asks first if writes are still pending | Reconnect before logging out |

Other limits:
- The in-memory provider state is not rolled back when the server rejects a write (section 4).
- The throttle is per app run; after a restart the first screen open syncs again.
- Two devices editing the same slot at the same time: last write wins.

## 11. Example log traces

(IDs shortened.)

**App start, nothing changed on the server**
```
[STATE]     starting dev flavor (link domain dev-dairyledger.web.app)
[STATE]     authStateProvider: AsyncLoading -> AsyncData(User(...))
[CACHE]     READ  users/UID -> hit
[ROUTER]    redirect /splash -> /home
[SYNC]      accounts.UID: delta since 2026-10-26T09:12:03.512Z
[FIRESTORE] QUERY accounts.UID from server -> 0 docs, billed 1 read(s)
[CACHE]     QUERY users/UID/accounts -> 3 docs
```

**Opening an account for the first time**
```
[SYNC]      bills.ACC: initial load (no cursor yet)
[FIRESTORE] QUERY bills.ACC from server -> 2 docs, billed 2 read(s)
[CACHE]     STORE 2 changed docs from bills.ACC
[SYNC]      cursor[bills.ACC] -> 2026-10-25T18:40:11.204Z
[CACHE]     QUERY bills latest account=ACC -> 2 docs
```

**Opening it again 20 seconds later** (throttled, no server traffic)
```
[SYNC]      skip bills.ACC (synced 20s ago)
[CACHE]     QUERY bills latest account=ACC -> 2 docs
```

**Saving a slot**
```
[CACHE]     WRITE update users/UID/accounts/ACC/bills/2026-10-12 2026-10-14/M BillSlot(milk=5.0 fat=4.2 rate=52.0 manual=false) -> applied to local cache, upload queued
[STATE]     billsProvider: AsyncData(BillsState(2 bills ...)) -> AsyncData(BillsState(2 bills ...))
[FIRESTORE] WRITE update users/UID/accounts/ACC/bills/2026-10-12 ... -> acknowledged by server, billed 1 write
```

**The same save while offline**
```
[CACHE]     WRITE update ... -> applied to local cache, upload queued
   (no FIRESTORE line; it appears later, when the phone reconnects)
[FIRESTORE] WRITE update ... -> acknowledged by server, billed 1 write
```

**A rejected write**
```
[CACHE]     WRITE update ... -> applied to local cache, upload queued
[FIRESTORE] WRITE update ... -> REJECTED by server (permission-denied), local change rolled back
```

**Delta sync while offline**
```
[SYNC]      bills.ACC: delta since 2026-10-25T18:40:11.204Z
[SYNC]      bills.ACC: skipped (unavailable), using the cache only
[CACHE]     QUERY bills latest account=ACC -> 2 docs
```

**Logout**
```
[FIRESTORE] no pending writes
[AUTH]      logout: clearing local data first
[CACHE]     CLEAR everything (terminate + clearPersistence)
[CACHE]     CLEAR done
[SYNC]      clearing 3 cursors
[AUTH]      sign out
```

**First login on a clean phone**
```
[CACHE]     READ  users/UID -> miss, asking the server
[FIRESTORE] READ  users/UID from server, exists=false
[FIRESTORE] profile missing for UID, creating (onboarding pending)
[CACHE]     WRITE create users/UID -> applied to local cache, upload queued
[ROUTER]    redirect /splash -> /onboarding
```

## 12. Code map

| File | Role |
|---|---|
| `lib/core/logger.dart` | `logd` and the tag definitions |
| `lib/core/firestore/firestore_paths.dart` | the Firestore collection layout |
| `lib/core/firestore/firestore_reads.dart` | cache-first and cache-only reads, server queries |
| `lib/core/firestore/write_tracker.dart` | `trackWrite`: non-awaited writes and their logging |
| `lib/core/firestore/delta_sync.dart` | `runDeltaSync` |
| `lib/core/firestore/sync_state.dart` | `SyncCursorStore` (cursors) and `SyncThrottle` |
| `lib/core/local_data_service.dart` | clearing the cache and cursors, flushing pending writes |
| `lib/features/auth/data/session_service.dart` | logout and "refresh all data" built on the above |
| `lib/features/*/data/*_repository.dart` | which read or write each feature uses |
| `lib/features/bills/providers/bill_providers.dart` | when bills are synced, paged and refreshed |
| `lib/main_common.dart` | cache settings at start-up |
