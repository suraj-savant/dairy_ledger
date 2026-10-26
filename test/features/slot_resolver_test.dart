import 'package:dairy_ledger/features/bills/models/bill_slot.dart';
import 'package:dairy_ledger/features/bills/models/slot_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chart used by the tests: only fat 4.2 has a rate (52).
double? chart(double fat) => fat == 4.2 ? 52 : null;

BillSlot resolve({
  double milk = 5,
  double fat = 4.2,
  String rate = '',
  bool manual = false,
}) =>
    resolveSlot(milk: milk, fat: fat, rateText: rate, rateManual: manual, rateFor: chart);

void main() {
  test('the rate comes from the chart for the typed fat', () {
    expect(resolve(), const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  test('a fat without a chart rate gives rate 0 and never blocks', () {
    final slot = resolve(fat: 4.7);
    expect(slot, const BillSlot(milk: 5, fat: 4.7, rate: 0));
    expect(slot.missingRate, isTrue);
  });

  test('a typed rate that differs from the chart is a manual override', () {
    expect(resolve(rate: '60', manual: true),
        const BillSlot(milk: 5, fat: 4.2, rate: 60, rateManual: true));
  });

  test('a manual rate also works for a fat that has no chart rate', () {
    expect(resolve(fat: 4.7, rate: '48', manual: true),
        const BillSlot(milk: 5, fat: 4.7, rate: 48, rateManual: true));
  });

  test('a typed rate equal to the chart is not flagged manual', () {
    expect(resolve(rate: '52', manual: true), const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  test('clearing the rate goes back to the chart', () {
    expect(resolve(rate: '', manual: true), const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  test('without the manual flag the chart wins over stale rate text', () {
    expect(resolve(rate: '60', manual: false), const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  test('no fat means no rate', () {
    expect(resolve(fat: 0), const BillSlot(milk: 5));
  });

  test('everything empty gives an empty slot, which is not stored', () {
    expect(resolve(milk: 0, fat: 0).isEmpty, isTrue);
  });
}
