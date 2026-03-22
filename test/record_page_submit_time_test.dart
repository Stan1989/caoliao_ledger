import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/features/record/presentation/record_page.dart';

void main() {
  group('resolveSubmitTransactionDate', () {
    test('create flow persists user-selected datetime', () {
      final selected = DateTime(2026, 3, 22, 8, 45);

      final resolved = resolveSubmitTransactionDate(
        isEditMode: false,
        formTransactionDate: selected,
      );

      expect(resolved, selected);
    });

    test('create flow persists unchanged default datetime', () {
      final defaultDate = DateTime(2026, 3, 22, 10, 0);

      final resolved = resolveSubmitTransactionDate(
        isEditMode: false,
        formTransactionDate: defaultDate,
      );

      expect(resolved, defaultDate);
    });

    test('edit flow datetime behavior remains consistent', () {
      final edited = DateTime(2024, 5, 6, 7, 8);

      final resolved = resolveSubmitTransactionDate(
        isEditMode: true,
        formTransactionDate: edited,
      );

      expect(resolved, edited);
    });
  });
}
