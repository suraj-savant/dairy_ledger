import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants.dart';
import '../../../core/firestore/delta_sync.dart';
import '../../../core/firestore/firestore_paths.dart';
import '../../../core/firestore/firestore_reads.dart';
import '../../../core/firestore/sync_state.dart';
import '../../../core/firestore/write_tracker.dart';
import '../../../core/logger.dart';
import '../../../core/utils/formatters.dart';
import '../models/bill.dart';

/// Reads and writes `accounts/{accountId}/bills/{billId}`.
///
/// Used by the admin screens and, read-only, by the supplier screens.
/// Cost model: one document per bill, so a bill view is 1 read and saving a
/// milking slot is 1 write; screens read the cache and [sync] fetches only
/// bills changed since the last sync.
class BillRepository {
  BillRepository(this._paths, this._cursors, this._throttle);
  final FsPaths _paths;
  final SyncCursorStore _cursors;
  final SyncThrottle _throttle;

  /// Brings the local cache up to date with the server.
  ///
  /// First sync loads the newest page of bills; later syncs fetch only bills
  /// whose `updatedAt` is newer than the saved cursor (including soft-deleted
  /// ones, so they disappear from the cache view).
  Future<void> sync(String accountId, {bool force = false}) async {
    final key = 'bills.$accountId';
    if (!_throttle.take(key, force: force)) return;
    await runDeltaSync(
      cursorKey: key,
      cursors: _cursors,
      buildQuery: (cursor) {
        final bills = _paths.bills(accountId);
        return cursor == null
            ? bills.orderBy('startDate', descending: true).limit(AppConstants.billPageSize)
            : bills.where('updatedAt', isGreaterThan: cursor).orderBy('updatedAt');
      },
    );
  }

  /// Newest bills from the cache (call [sync] first). Returns the raw page
  /// size too so the caller can tell whether older bills may exist.
  Future<({List<Bill> bills, int rawCount})> loadLatest(
    String accountId, {
    int limit = AppConstants.billPageSize,
  }) async {
    final query = _paths
        .bills(accountId)
        .orderBy('startDate', descending: true)
        .limit(limit);
    var snap = await getQueryFromCache(query, label: 'bills latest account=$accountId');
    if (snap.docs.isEmpty && _cursors.read('bills.$accountId') != null) {
      // Cursor says we synced but the cache is empty (cache was cleared):
      // reload the first page from the server.
      logd('SYNC', 'cache empty despite cursor for $accountId, reloading');
      await _cursors.clear('bills.$accountId');
      await sync(accountId, force: true);
      snap = await getQueryFromCache(query, label: 'bills latest (retry) account=$accountId');
    }
    return (bills: _toBills(accountId, snap), rawCount: snap.docs.length);
  }

  /// Older bills, always fetched from the server (then cached by the SDK).
  /// Fetching from the cache could return a page with gaps, because only
  /// recently changed old bills are cached.
  Future<({List<Bill> bills, int rawCount})> loadOlder(
    String accountId,
    Bill last, {
    int limit = AppConstants.billPageSize,
  }) async {
    final query = _paths
        .bills(accountId)
        .orderBy('startDate', descending: true)
        .startAfter([Fmt.dateKey(last.startDate)])
        .limit(limit);
    final snap = await getQueryFromServer(query, label: 'bills older than ${last.id}');
    return (bills: _toBills(accountId, snap), rawCount: snap.docs.length);
  }

  List<Bill> _toBills(String accountId, QuerySnapshot<Json> snap) => snap.docs
      .where((d) => d.data()['deleted'] != true)
      .map((d) => Bill.fromDoc(accountId, d))
      .toList();

  /// The existing bill whose range overlaps [start]..[end], or null.
  /// Asks the server (a few documents at most) so older bills that are not
  /// cached are also checked; falls back to the cache when offline.
  Future<Bill?> findOverlap(String accountId, DateTime start, DateTime end) async {
    // A bill is at most 31 days long, so any overlapping bill starts within
    // 30 days before [start] and no later than [end].
    final from = Fmt.dateKey(DateTime(start.year, start.month, start.day - 30));
    final query = _paths
        .bills(accountId)
        .where('startDate', isGreaterThanOrEqualTo: from)
        .where('startDate', isLessThanOrEqualTo: Fmt.dateKey(end));
    final snap = await getQueryFromServer(query, label: 'bills overlap $from..${Fmt.dateKey(end)}');
    for (final bill in _toBills(accountId, snap)) {
      if (!bill.endDate.isBefore(start) && !bill.startDate.isAfter(end)) return bill;
    }
    return null;
  }

  /// Creates an empty bill document.
  void create(Bill bill) {
    final ref = _paths.bills(bill.accountId).doc(bill.id);
    trackWrite(
      'create ${ref.path} (${Fmt.dateKey(bill.startDate)}..${Fmt.dateKey(bill.endDate)})',
      ref.set({...bill.toCreateMap(), 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  /// Persists one changed slot of [updated] (already containing the new slot)
  /// together with the recomputed totals: a single document update.
  void saveSlot(Bill updated, DateTime date, Session session) {
    final ref = _paths.bills(updated.accountId).doc(updated.id);
    final slot = updated.slot(date, session);
    final dateKey = Fmt.dateKey(date);
    trackWrite(
      'update ${ref.path} $dateKey/${session.key} $slot',
      ref.update({
        // FieldPath because date keys contain hyphens.
        FieldPath(['days', dateKey, session.key]):
            slot.isEmpty ? FieldValue.delete() : slot.toMap(),
        'totalMilk': updated.totalMilk,
        'totalAmount': updated.totalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  void softDelete(String accountId, String billId) {
    final ref = _paths.bills(accountId).doc(billId);
    trackWrite(
      'soft-delete ${ref.path}',
      ref.update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }
}
