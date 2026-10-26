import 'package:dairy_ledger/core/constants.dart';
import 'package:dairy_ledger/features/bills/models/bill.dart';
import 'package:dairy_ledger/features/bills/models/bill_slot.dart';
import 'package:dairy_ledger/features/rates/models/rate_chart.dart';
import 'package:flutter_test/flutter_test.dart';

Bill newBill({int cycle = 7}) => Bill.create(
      accountId: 'acc1',
      ownerUid: 'uid1',
      start: DateTime(2026, 10, 12),
      cycleDays: cycle,
    );

void main() {
  group('Bill range', () {
    test('a 7-day bill starting 12 Oct ends on 18 Oct', () {
      final bill = newBill();
      expect(bill.id, '2026-10-12');
      expect(bill.endDate, DateTime(2026, 10, 18));
      expect(bill.dates.length, 7);
      expect(bill.dates.first, DateTime(2026, 10, 12));
      expect(bill.dates.last, DateTime(2026, 10, 18));
    });

    test('cycle length follows the profile and crosses month ends', () {
      final bill = newBill(cycle: 10);
      expect(bill.endDate, DateTime(2026, 10, 21));
      final late = Bill.create(
          accountId: 'a', ownerUid: 'u', start: DateTime(2026, 10, 28), cycleDays: 7);
      expect(late.endDate, DateTime(2026, 11, 3));
    });
  });

  group('Bill totals', () {
    test('slot total is milk x rate rounded to 2 decimals', () {
      expect(const BillSlot(milk: 5.5, fat: 4.2, rate: 52).total, 286.0);
      expect(const BillSlot(milk: 3.333, fat: 4, rate: 10).total, 33.33);
    });

    test('withSlot recomputes session and bill totals', () {
      var bill = newBill();
      bill = bill.withSlot(DateTime(2026, 10, 12), Session.morning,
          const BillSlot(milk: 5, fat: 4, rate: 50));
      bill = bill.withSlot(DateTime(2026, 10, 12), Session.evening,
          const BillSlot(milk: 3, fat: 4, rate: 50));
      bill = bill.withSlot(DateTime(2026, 10, 13), Session.morning,
          const BillSlot(milk: 2, fat: 4, rate: 50));

      expect(bill.sessionMilk(Session.morning), 7);
      expect(bill.sessionAmount(Session.morning), 350);
      expect(bill.sessionMilk(Session.evening), 3);
      expect(bill.totalMilk, 10);
      expect(bill.totalAmount, 500);
    });

    test('an empty slot removes the entry', () {
      var bill = newBill().withSlot(DateTime(2026, 10, 12), Session.morning,
          const BillSlot(milk: 5, fat: 4, rate: 50));
      bill = bill.withSlot(DateTime(2026, 10, 12), Session.morning, BillSlot.empty);
      expect(bill.days, isEmpty);
      expect(bill.totalAmount, 0);
    });

    test('missing rate is flagged but the total is simply 0', () {
      const slot = BillSlot(milk: 5, fat: 4.2, rate: 0);
      expect(slot.missingRate, isTrue);
      expect(slot.total, 0);
    });
  });

  group('Bill serialization', () {
    test('toCreateMap stores sessions under M / E and only flags manual rates', () {
      final bill = newBill().withSlot(
        DateTime(2026, 10, 12),
        Session.morning,
        const BillSlot(milk: 5, fat: 4, rate: 60, rateManual: true),
      );
      final map = bill.toCreateMap();
      final day = (map['days'] as Map)['2026-10-12'] as Map;
      expect((day['M'] as Map)['rateManual'], true);
      expect(map['startDate'], '2026-10-12');
      expect(map['endDate'], '2026-10-18');
      expect(map['totalAmount'], 300);
      expect(BillSlot.fromMap({'milk': 1, 'fat': 4, 'rate': 50}).rateManual, isFalse);
    });
  });

  group('RateChart', () {
    test('seeded chart has 3.0 .. 10.0 at rate 0, so every lookup is "missing"', () {
      final chart = RateChart.seeded('COW');
      expect(chart.fats.length, 71);
      expect(chart.rateFor(4.2), isNull);
    });

    test('rateFor finds a set rate, including custom fats', () {
      final chart = RateChart.seeded('COW').withFat('4.2', 52).withFat('10.5', 101);
      expect(chart.rateFor(4.2), 52);
      expect(chart.rateFor(4.20), 52);
      expect(chart.rateFor(10.5), 101);
      expect(chart.rateFor(4.3), isNull);
    });

    test('sorted orders by fat value, not by text', () {
      final chart = RateChart(category: 'X', fats: {'10.0': 1, '4.5': 2, '3.0': 3});
      expect(chart.sorted.map((e) => e.key).toList(), ['3.0', '4.5', '10.0']);
    });
  });
}
