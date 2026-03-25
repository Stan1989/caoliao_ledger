import 'package:flutter/material.dart';
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

  group('FlowFilterState.hasDateOverride', () {
    test('returns false for default empty state', () {
      const filter = FlowFilterState();
      expect(filter.hasDateOverride, isFalse);
    });

    test('returns false for account-only filter', () {
      const filter = FlowFilterState(accountIds: {1, 2});
      expect(filter.hasDateOverride, isFalse);
    });

    test('returns false for member-only filter', () {
      const filter = FlowFilterState(memberIds: {3});
      expect(filter.hasDateOverride, isFalse);
    });

    test('returns false for project-only filter', () {
      const filter = FlowFilterState(projectIds: {5});
      expect(filter.hasDateOverride, isFalse);
    });

    test('returns false for type-only filter', () {
      const filter = FlowFilterState(
        transactionTypes: {TransactionType.expense, TransactionType.transfer},
      );
      expect(filter.hasDateOverride, isFalse);
    });

    test('returns true when dateRange is set', () {
      final filter = FlowFilterState(
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 3, 25),
        ),
      );
      expect(filter.hasDateOverride, isTrue);
    });

    test('returns true when minAmount is set', () {
      const filter = FlowFilterState(minAmount: 1000);
      expect(filter.hasDateOverride, isTrue);
    });

    test('returns true when dateRange combined with dimension filters', () {
      final filter = FlowFilterState(
        accountIds: const {1},
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 3, 25),
        ),
      );
      expect(filter.hasDateOverride, isTrue);
    });
  });
}
