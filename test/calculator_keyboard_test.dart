import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/features/record/presentation/widgets/calculator_keyboard.dart';

void main() {
  group('CalculatorKeyboard backspace', () {
    testWidgets('deletes last input character from non-empty expression', (
      tester,
    ) async {
      var latestAmount = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalculatorKeyboard(
              onValueChanged: (value) => latestAmount = value,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();

      expect(find.text('12'), findsWidgets);
      expect(latestAmount, 12);

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(find.text('12'), findsNothing);
      expect(find.text('1'), findsWidgets);
      expect(latestAmount, 1);
    });

    testWidgets(
      'backspace on empty expression keeps display and amount at zero',
      (tester) async {
        var latestAmount = 0.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CalculatorKeyboard(
                onValueChanged: (value) => latestAmount = value,
                onDone: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.backspace_outlined));
        await tester.pump();

        expect(find.text('0'), findsNWidgets(2));
        expect(latestAmount, 0);
        expect(find.byType(CalculatorKeyboard), findsOneWidget);
      },
    );
  });
}
