import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants.dart';
import '../../../core/firestore/firestore_paths.dart';
import '../../../core/utils/formatters.dart';
import '../../accounts/models/account.dart';
import 'bill_slot.dart';

/// One bill (shown as a "week" in the UI): a fixed range of [cycleDays] days
/// of one account, with every entered milking slot stored in a single
/// Firestore document (`users/{ownerUid}/accounts/{accountId}/bills/{startDate}`).
///
/// [startDate], [endDate] and [cycleDays] never change after creation, so a
/// later change of the profile's bill cycle does not touch existing bills.
class Bill {
  const Bill({
    required this.accountId,
    required this.ownerUid,
    required this.startDate,
    required this.endDate,
    required this.cycleDays,
    this.days = const {},
  });

  final String accountId;
  final String ownerUid;
  final DateTime startDate;
  final DateTime endDate;
  final int cycleDays;

  /// dateKey -> session -> slot. Only slots with data are present.
  final Map<String, Map<Session, BillSlot>> days;

  AccountRef get accountRef => (ownerUid: ownerUid, accountId: accountId);

  /// Bill ID = start date key, e.g. `2026-10-12`.
  String get id => Fmt.dateKey(startDate);

  /// New empty bill of [cycleDays] days starting at [start].
  factory Bill.create({
    required String accountId,
    required String ownerUid,
    required DateTime start,
    required int cycleDays,
  }) {
    final s = DateTime(start.year, start.month, start.day);
    return Bill(
      accountId: accountId,
      ownerUid: ownerUid,
      startDate: s,
      endDate: DateTime(s.year, s.month, s.day + cycleDays - 1),
      cycleDays: cycleDays,
    );
  }

  /// Every date inside the range (the only dates that exist for this bill).
  List<DateTime> get dates => List.generate(
        cycleDays,
        (i) => DateTime(startDate.year, startDate.month, startDate.day + i),
      );

  BillSlot slot(DateTime date, Session session) =>
      days[Fmt.dateKey(date)]?[session] ?? BillSlot.empty;

  double sessionMilk(Session s) => Fmt.round2(_sum(s, (x) => x.milk));
  double sessionAmount(Session s) => Fmt.round2(_sum(s, (x) => x.total));
  double get totalMilk => Fmt.round2(sessionMilk(Session.morning) + sessionMilk(Session.evening));
  double get totalAmount => Fmt.round2(sessionAmount(Session.morning) + sessionAmount(Session.evening));

  double _sum(Session s, double Function(BillSlot) pick) {
    var total = 0.0;
    for (final day in days.values) {
      final slot = day[s];
      if (slot != null) total += pick(slot);
    }
    return total;
  }

  /// Copy with [slot] stored for [date]/[session] (an empty slot removes it).
  Bill withSlot(DateTime date, Session session, BillSlot slot) {
    final key = Fmt.dateKey(date);
    final next = {
      for (final e in days.entries) e.key: Map<Session, BillSlot>.of(e.value),
    };
    final day = next.putIfAbsent(key, () => {});
    if (slot.isEmpty) {
      day.remove(session);
      if (day.isEmpty) next.remove(key);
    } else {
      day[session] = slot;
    }
    return Bill(
      accountId: accountId,
      ownerUid: ownerUid,
      startDate: startDate,
      endDate: endDate,
      cycleDays: cycleDays,
      days: next,
    );
  }

  /// Map used when the bill document is created.
  Json toCreateMap() => {
        'startDate': Fmt.dateKey(startDate),
        'endDate': Fmt.dateKey(endDate),
        'cycleDays': cycleDays,
        'days': {
          for (final e in days.entries)
            e.key: {for (final s in e.value.entries) s.key.key: s.value.toMap()},
        },
        'totalMilk': totalMilk,
        'totalAmount': totalAmount,
        'deleted': false,
      };

  factory Bill.fromDoc(AccountRef account, DocumentSnapshot<Json> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    final rawDays = (m['days'] as Map?) ?? const {};
    final days = <String, Map<Session, BillSlot>>{};
    for (final d in rawDays.entries) {
      final sessions = <Session, BillSlot>{};
      for (final s in Session.values) {
        final raw = (d.value as Map?)?[s.key];
        if (raw is Map) {
          sessions[s] = BillSlot.fromMap(Map<String, dynamic>.from(raw));
        }
      }
      if (sessions.isNotEmpty) days[d.key as String] = sessions;
    }
    return Bill(
      accountId: account.accountId,
      ownerUid: account.ownerUid,
      startDate: Fmt.parseKey(m['startDate'] as String),
      endDate: Fmt.parseKey(m['endDate'] as String),
      cycleDays: (m['cycleDays'] as num?)?.toInt() ?? AppConstants.defaultBillCycleDays,
      days: days,
    );
  }

  @override
  String toString() => 'Bill($id..${Fmt.dateKey(endDate)}, ${days.length} days)';
}
