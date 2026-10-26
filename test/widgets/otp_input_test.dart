import 'package:dairy_ledger/features/auth/presentation/otp_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows six boxes and reports the code once all digits are in', (tester) async {
    String? completed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: OtpInput(onCompleted: (c) => completed = c))),
    ));

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(completed, isNull);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(completed, '123456');
  });

  testWidgets('ignores non-digits and more than six characters', (tester) async {
    String? completed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: OtpInput(onCompleted: (c) => completed = c))),
    ));

    await tester.enterText(find.byType(TextField), '12ab34567890');
    await tester.pump();
    expect(completed, '123456');
  });
}
