import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/features/transaction_flow/providers/flow_filter_provider.dart';

void main() {
  group('kFlowAmountPresets', () {
    test('contains the expected six ascending presets', () {
      expect(
        kFlowAmountPresets.map((preset) => preset.value),
        [200.0, 500.0, 1000.0, 3000.0, 5000.0, 10000.0],
      );
      expect(
        kFlowAmountPresets.map((preset) => preset.label),
        ['>200', '>500', '>1000', '>3000', '>5000', '>10000'],
      );
    });
  });

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

  group('resolveFlowQueryRange', () {
    test('uses current month when no date override is set', () {
      const filter = FlowFilterState();
      final currentMonth = DateTime(2026, 5);

      final range = resolveFlowQueryRange(currentMonth, filter);

      expect(range.start, currentMonth);
      expect(range.end, DateTime(2026, 6));
    });

    test('uses explicit date range when provided', () {
      final filter = FlowFilterState(
        dateRange: DateTimeRange(
          start: DateTime(2026, 5, 10),
          end: DateTime(2026, 5, 12),
        ),
      );

      final range = resolveFlowQueryRange(DateTime(2026, 5), filter);

      expect(range.start, DateTime(2026, 5, 10));
      expect(range.end, DateTime(2026, 5, 13));
    });

    test('uses all-time range when minAmount is set', () {
      const filter = FlowFilterState(minAmount: 500);

      final range = resolveFlowQueryRange(DateTime(2026, 5), filter);

      expect(range.start, DateTime(2000));
      expect(range.end, DateTime(2100));
    });
  });

  group('toggleFlowAmountPreset', () {
    test('selects a preset when nothing is currently selected', () {
      expect(toggleFlowAmountPreset(null, 200), 200);
    });

    test('clears the preset when the same amount is tapped again', () {
      expect(toggleFlowAmountPreset(200, 200), isNull);
    });

    test('switches to the new preset when a different amount is tapped', () {
      expect(toggleFlowAmountPreset(200, 500), 500);
    });
  });
}
