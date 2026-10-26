import 'package:dairy_ledger/app/theme.dart';
import 'package:dairy_ledger/features/bills/models/bill_slot.dart';
import 'package:dairy_ledger/features/bills/presentation/widgets/bill_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chart used by the tests: only fat 4.2 has a rate (52).
double? chart(double fat) => fat == 4.2 ? 52 : null;

Future<List<BillSlot>> pumpRow(WidgetTester tester, {BillSlot slot = BillSlot.empty}) async {
  final saved = <BillSlot>[];
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Column(children: [
        EditableBillRow(
          date: DateTime(2026, 10, 12),
          slot: slot,
          rateFor: chart,
          onChanged: saved.add,
        ),
        // A second focusable widget to move focus out of the row.
        const TextField(key: Key('outside')),
      ]),
    ),
  ));
  return saved;
}

Finder cell(int i) => find.byType(TextField).at(i); // 0 milk, 1 fat, 2 rate

Future<void> leaveRow(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('outside')));
  await tester.pump();
}

void main() {
  testWidgets('fat fills the rate from the chart and the row saves once on blur', (tester) async {
    final saved = await pumpRow(tester);

    await tester.enterText(cell(0), '5');
    await tester.enterText(cell(1), '4.2');
    await tester.pump();

    expect(tester.widget<TextField>(cell(2)).controller!.text, '52');
    expect(find.text('260.00'), findsOneWidget); // 5 x 52, shown live
    expect(saved, isEmpty); // nothing saved while typing

    await leaveRow(tester);
    expect(saved.length, 1);
    expect(saved.single, const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  testWidgets('a typed rate overrides the chart and is flagged manual', (tester) async {
    final saved = await pumpRow(tester);

    await tester.enterText(cell(0), '5');
    await tester.enterText(cell(1), '4.2');
    await tester.enterText(cell(2), '60');
    await leaveRow(tester);

    expect(saved.single, const BillSlot(milk: 5, fat: 4.2, rate: 60, rateManual: true));
  });

  testWidgets('a fat without a rate is saved with rate 0 and never blocks', (tester) async {
    final saved = await pumpRow(tester);

    await tester.enterText(cell(0), '5');
    await tester.enterText(cell(1), '4.7');
    await leaveRow(tester);

    expect(saved.single, const BillSlot(milk: 5, fat: 4.7, rate: 0));
    expect(saved.single.missingRate, isTrue);
  });

  testWidgets('an existing manual rate survives a fat change', (tester) async {
    final saved = await pumpRow(
      tester,
      slot: const BillSlot(milk: 5, fat: 4.2, rate: 60, rateManual: true),
    );

    await tester.enterText(cell(1), '4.3');
    await leaveRow(tester);

    expect(saved.single.rate, 60);
    expect(saved.single.rateManual, isTrue);
  });

  testWidgets('clearing the rate goes back to the chart', (tester) async {
    final saved = await pumpRow(
      tester,
      slot: const BillSlot(milk: 5, fat: 4.2, rate: 60, rateManual: true),
    );

    await tester.enterText(cell(2), '');
    await leaveRow(tester);

    expect(saved.single, const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  testWidgets('leaving the row without changes saves nothing', (tester) async {
    final saved = await pumpRow(tester, slot: const BillSlot(milk: 5, fat: 4.2, rate: 52));

    await tester.tap(cell(0));
    await tester.pump();
    await leaveRow(tester);

    expect(saved, isEmpty);
  });
}
