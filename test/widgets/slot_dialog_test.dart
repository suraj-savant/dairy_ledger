import 'package:dairy_ledger/app/theme.dart';
import 'package:dairy_ledger/features/bills/models/bill_slot.dart';
import 'package:dairy_ledger/features/bills/presentation/slot_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double? chart(double fat) => fat == 4.2 ? 52 : null;

/// Opens the dialog from a button and records what it returns.
Future<({BillSlot? Function() result})> openDialog(
  WidgetTester tester, {
  BillSlot slot = BillSlot.empty,
}) async {
  BillSlot? result;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => result = await showSlotDialog(
              context,
              date: DateTime(2026, 10, 12),
              sessionLabel: 'Morning',
              slot: slot,
              rateFor: chart,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (result: () => result);
}

Finder field(int i) => find.byType(TextField).at(i); // 0 milk, 1 fat, 2 rate

void main() {
  testWidgets('shows the full date and session, and zeros stay empty', (tester) async {
    await openDialog(tester);
    expect(find.text('12-10-2026'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(tester.widget<TextField>(field(0)).controller!.text, isEmpty);
  });

  testWidgets('fat fills the rate from the chart and the total updates live', (tester) async {
    final r = await openDialog(tester);

    await tester.enterText(field(0), '5');
    await tester.enterText(field(1), '4.2');
    await tester.pump();

    expect(tester.widget<TextField>(field(2)).controller!.text, '52');
    expect(find.text('₹ 260.00'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(r.result(), const BillSlot(milk: 5, fat: 4.2, rate: 52));
  });

  testWidgets('a typed rate overrides the chart and is flagged manual', (tester) async {
    final r = await openDialog(tester);

    await tester.enterText(field(0), '5');
    await tester.enterText(field(1), '4.2');
    await tester.enterText(field(2), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(r.result(), const BillSlot(milk: 5, fat: 4.2, rate: 60, rateManual: true));
  });

  testWidgets('a fat without a rate shows a hint, saves with rate 0 and never blocks', (tester) async {
    final r = await openDialog(tester);

    await tester.enterText(field(0), '5');
    await tester.enterText(field(1), '4.7');
    await tester.pump();
    expect(find.textContaining('No rate for this fat'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(r.result(), const BillSlot(milk: 5, fat: 4.7, rate: 0));
  });

  testWidgets('an existing manual rate survives a fat change', (tester) async {
    final r = await openDialog(
      tester,
      slot: const BillSlot(milk: 5, fat: 4.2, rate: 60, rateManual: true),
    );

    await tester.enterText(field(1), '4.3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(r.result()!.rate, 60);
    expect(r.result()!.rateManual, isTrue);
  });

  testWidgets('cancel returns nothing', (tester) async {
    final r = await openDialog(tester);
    await tester.enterText(field(0), '5');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(r.result(), isNull);
  });
}
