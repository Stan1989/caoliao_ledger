import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/features/record/providers/record_form_provider.dart';

void main() {
  group('RecordFormNotifier', () {
    test(
      'onSaveSuccess resets amount, note and transactionDate for next create',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(recordFormProvider.notifier);
        final before = DateTime.now();

        notifier.setAmount(123.45);
        notifier.setNote('午饭');
        notifier.setDate(DateTime(2020, 1, 2, 3, 4));

        await notifier.onSaveSuccess();

        final state = container.read(recordFormProvider);
        expect(state.amount, 0);
        expect(state.note, '');
        expect(
          state.transactionDate.isAfter(before) ||
              state.transactionDate.isAtSameMomentAs(before),
          isTrue,
        );
      },
    );

    test('loadTransaction keeps edit-mode values intact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(recordFormProvider.notifier);
      final transactionDate = DateTime(2024, 5, 6, 7, 8);

      notifier.loadTransaction(
        type: TransactionType.income,
        amount: 88,
        categoryId: 1,
        categoryName: '工资',
        accountId: 2,
        accountName: '银行卡',
        toAccountId: null,
        toAccountName: null,
        memberId: 3,
        memberName: '我',
        projectId: 4,
        projectName: '项目A',
        note: '编辑备注',
        transactionDate: transactionDate,
      );

      final state = container.read(recordFormProvider);
      expect(state.type, TransactionType.income);
      expect(state.amount, 88);
      expect(state.note, '编辑备注');
      expect(state.transactionDate, transactionDate);
    });
  });
}
