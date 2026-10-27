import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dairy_ledger/features/rates/models/rate_chart.dart';
import 'package:dairy_ledger/features/rates/presentation/rate_editor.dart';
import 'package:dairy_ledger/features/rates/providers/rate_providers.dart';

void main() {
  final chart = RateChart(
    category: 'COW',
    fats: {'3.0': 0, '3.5': 32, '4.0': 36},
  );

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: RateEditor(chart: chart)),
    ),
  );

  testWidgets('shows 0.0 for a missing rate and clears it on focus', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('32.0'), findsOneWidget);

    await tester.tap(find.text('0.0'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('ticking a fat shows Delete and removes the row', (tester) async {
    await pump(tester);
    expect(find.textContaining('Delete ('), findsNothing);

    await tester.tap(
      find.byType(Checkbox).at(2),
    ); // row 3.5 (index 0 is select-all)
    await tester.pump();
    expect(find.text('Delete (1)'), findsOneWidget);

    await tester.tap(find.text('Delete (1)'));
    await tester.pump();
    expect(find.text('3.5'), findsNothing);
    expect(find.text('3.0'), findsOneWidget);
  });

  test('edit mode flag starts off', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(ratesEditingProvider), isFalse);
  });
}
