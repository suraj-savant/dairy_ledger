import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logger.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/bill_repository.dart';
import '../models/bill.dart';
import '../models/bill_slot.dart';

final billRepositoryProvider = Provider<BillRepository>(
  (ref) => BillRepository(
    ref.watch(fsPathsProvider),
    ref.watch(syncCursorStoreProvider),
    ref.watch(syncThrottleProvider),
  ),
  name: 'billRepositoryProvider',
);

/// Loaded bills of one account (newest first) and which one is on screen.
class BillsState {
  const BillsState({
    required this.bills,
    this.index = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<Bill> bills;
  final int index;
  final bool hasMore;
  final bool loadingMore;

  Bill? get current => bills.isEmpty ? null : bills[index];

  /// The newest bill is on screen (the "Next" button becomes "Add week").
  bool get isLatest => index == 0;

  bool get canGoPrevious => index < bills.length - 1 || hasMore;

  BillsState copyWith({
    List<Bill>? bills,
    int? index,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      BillsState(
        bills: bills ?? this.bills,
        index: index ?? this.index,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  @override
  String toString() =>
      'BillsState(${bills.length} bills, index=$index, hasMore=$hasMore, current=${current?.id})';
}

/// Bills of one account. Shared by the admin screen (which also edits) and
/// the supplier screen (which only reads).
///
/// "Previous" moves to an older bill (higher index), "Next" to a newer one.
class BillsNotifier extends AsyncNotifier<BillsState> {
  BillsNotifier(this.accountId);
  final String accountId;

  BillRepository get _repo => ref.read(billRepositoryProvider);

  @override
  Future<BillsState> build() async {
    await _repo.sync(accountId); // fetch only bills changed since last time
    return _firstPage();
  }

  Future<BillsState> _firstPage({String? keepBillId}) async {
    final page = await _repo.loadLatest(accountId);
    var index = 0;
    if (keepBillId != null) {
      final i = page.bills.indexWhere((b) => b.id == keepBillId);
      if (i >= 0) index = i;
    }
    return BillsState(
      bills: page.bills,
      index: index,
      hasMore: page.rawCount >= AppConstants.billPageSize,
    );
  }

  /// Pull-to-refresh: ask the server for changes, then reload.
  Future<void> refresh() async {
    final keep = state.value?.current?.id;
    await _repo.sync(accountId, force: true);
    state = AsyncData(await _firstPage(keepBillId: keep));
  }

  /// Shows the next older bill, loading another page when needed.
  Future<void> showPrevious() async {
    final s = state.value;
    if (s == null || s.loadingMore) return;
    if (s.index < s.bills.length - 1) {
      state = AsyncData(s.copyWith(index: s.index + 1));
      return;
    }
    if (!s.hasMore) return;

    state = AsyncData(s.copyWith(loadingMore: true));
    final page = await _repo.loadOlder(accountId, s.bills.last);
    state = AsyncData(s.copyWith(
      bills: [...s.bills, ...page.bills],
      index: page.bills.isEmpty ? s.index : s.index + 1,
      hasMore: page.rawCount >= AppConstants.billPageSize,
      loadingMore: false,
    ));
  }

  /// Shows the next newer bill.
  void showNext() {
    final s = state.value;
    if (s == null || s.index == 0) return;
    state = AsyncData(s.copyWith(index: s.index - 1));
  }

  // ---- admin-only operations (never called from supplier screens) ----

  /// Default start date for a new bill: the day after the newest bill ends,
  /// or today when the account has no bill yet.
  DateTime suggestedStart() {
    final latest = state.value?.bills.firstOrNull;
    final today = DateTime.now();
    return latest == null
        ? DateTime(today.year, today.month, today.day)
        : DateTime(latest.endDate.year, latest.endDate.month, latest.endDate.day + 1);
  }

  /// Creates a bill of the profile's cycle length starting at [start].
  /// Returns an error message (for example on overlap) or null on success.
  Future<String?> addBill(DateTime start) async {
    final profile = ref.read(profileProvider).value;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return 'Please sign in again.';

    final bill = Bill.create(
      accountId: accountId,
      ownerUid: uid,
      start: start,
      cycleDays: profile?.billCycleDays ?? AppConstants.defaultBillCycleDays,
    );
    final overlap = await _repo.findOverlap(accountId, bill.startDate, bill.endDate);
    if (overlap != null) {
      return 'These dates overlap the bill ${Fmt.range(overlap.startDate, overlap.endDate)}.';
    }

    _repo.create(bill);
    final bills = [...(state.value?.bills ?? <Bill>[]), bill]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    state = AsyncData(BillsState(
      bills: bills,
      index: bills.indexWhere((b) => b.id == bill.id),
      hasMore: state.value?.hasMore ?? false,
    ));
    return null;
  }

  /// Stores [slot] for [date]/[session] in the bill on screen.
  void saveSlot(DateTime date, Session session, BillSlot slot) {
    final s = state.value;
    final bill = s?.current;
    if (s == null || bill == null) return;
    final updated = bill.withSlot(date, session, slot);
    if (updated.slot(date, session) == bill.slot(date, session)) return; // nothing changed
    final bills = [...s.bills]..[s.index] = updated;
    state = AsyncData(s.copyWith(bills: bills));
    _repo.saveSlot(updated, date, session);
  }

  /// Soft-deletes the bill on screen.
  void deleteCurrent() {
    final s = state.value;
    final bill = s?.current;
    if (s == null || bill == null) return;
    _repo.softDelete(accountId, bill.id);
    final bills = [...s.bills]..removeAt(s.index);
    logd('STATE', 'bill ${bill.id} deleted');
    state = AsyncData(s.copyWith(
      bills: bills,
      index: s.index.clamp(0, bills.isEmpty ? 0 : bills.length - 1),
    ));
  }
}

final billsProvider =
    AsyncNotifierProvider.autoDispose.family<BillsNotifier, BillsState, String>(
  BillsNotifier.new,
  name: 'billsProvider',
);

/// Which milking session the account screen shows. Starts on the session
/// that matches the time of day.
class SessionNotifier extends Notifier<Session> {
  @override
  Session build() =>
      DateTime.now().hour < 15 ? Session.morning : Session.evening;
  void select(Session s) => state = s;
}

final sessionProvider = NotifierProvider.autoDispose<SessionNotifier, Session>(
  SessionNotifier.new,
  name: 'sessionProvider',
);
