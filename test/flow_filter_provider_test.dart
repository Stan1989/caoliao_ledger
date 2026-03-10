import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/features/transaction_flow/providers/flow_filter_provider.dart';

void main() {
  group('flowFilterTypeSummary', () {
    test('returns 全部 when no types selected', () {
      expect(flowFilterTypeSummary({}), '全部');
    });

    test('returns explicit type names when partially selected', () {
      expect(
        flowFilterTypeSummary({
          TransactionType.expense,
          TransactionType.transfer,
        }),
        '支出, 转账',
      );
    });

    test('returns 全部 when all selectable types are selected', () {
      expect(flowFilterTypeSummary(kFlowSelectableTypes), '全部');
    });
  });

  group('matchesFlowFilterTransactionType', () {
    test('matches any type when no type filter is set', () {
      const filter = FlowFilterState();
      expect(
        matchesFlowFilterTransactionType(filter, TransactionType.expense.value),
        isTrue,
      );
      expect(
        matchesFlowFilterTransactionType(filter, TransactionType.income.value),
        isTrue,
      );
      expect(
        matchesFlowFilterTransactionType(
          filter,
          TransactionType.transfer.value,
        ),
        isTrue,
      );
    });

    test('matches only selected types when type filter is set', () {
      const filter = FlowFilterState(
        transactionTypes: {TransactionType.expense, TransactionType.transfer},
      );
      expect(
        matchesFlowFilterTransactionType(filter, TransactionType.expense.value),
        isTrue,
      );
      expect(
        matchesFlowFilterTransactionType(filter, TransactionType.income.value),
        isFalse,
      );
      expect(
        matchesFlowFilterTransactionType(
          filter,
          TransactionType.transfer.value,
        ),
        isTrue,
      );
    });
  });

  group('FlowFilterState.isActive', () {
    test('is active when transaction types are selected', () {
      const filter = FlowFilterState(
        transactionTypes: {TransactionType.expense},
      );
      expect(filter.isActive, isTrue);
    });
  });
}
