import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/core/providers/amount_visibility_provider.dart';
import 'package:caoliao_ledger/core/providers/database_provider.dart';
import 'package:caoliao_ledger/core/repositories/transaction_repository.dart';
import 'package:caoliao_ledger/features/dashboard/presentation/dashboard_page.dart';

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this.responses);

  final Map<String, List<Transaction>> responses;

  String _key(int ledgerId, DateTime? startDate, DateTime? endDate) {
    return '$ledgerId|${startDate?.toIso8601String()}|${endDate?.toIso8601String()}';
  }

  @override
  Stream<List<Transaction>> watchByLedger(
    int ledgerId, {
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    int? memberId,
    int? projectId,
  }) {
    return Stream.value(responses[_key(ledgerId, startDate, endDate)] ?? []);
  }

  @override
  Future<int> createTransaction({required int ledgerId, required int type, required double amount, int? categoryId, required int accountId, int? toAccountId, int? memberId, int? projectId, String? merchant, String? note, required DateTime transactionDate}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTransaction(int id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Transaction>> getByLedgerAndDateRange(int ledgerId, DateTime start, DateTime end) {
    throw UnimplementedError();
  }

  @override
  Future<List<Transaction>> getByLedgerAndMonth(int ledgerId, int year, int month) {
    throw UnimplementedError();
  }

  @override
  Future<Transaction?> getById(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTransaction(Transaction transaction) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Transaction>> watchByAccount(int accountId) {
    throw UnimplementedError();
  }
}

class _StaticAmountVisibilityNotifier extends AmountVisibilityNotifier {
  _StaticAmountVisibilityNotifier(this.initialValue);

  final bool initialValue;

  @override
  bool build() => initialValue;

  @override
  Future<void> toggle() async {
    state = !state;
  }
}

Transaction _txn({required int id, required int type, required double amount}) {
  final now = DateTime(2026, 5, 13, 10);
  return Transaction(
    id: id,
    ledgerId: 1,
    type: type,
    amount: amount,
    categoryId: null,
    accountId: 1,
    toAccountId: null,
    memberId: null,
    projectId: null,
    merchant: null,
    note: null,
    transactionDate: now,
    createdAt: now,
    syncStatus: 0,
    remoteId: null,
    updatedAt: now,
  );
}

void main() {
  group('currentWeekRange', () {
    test('starts on Monday and ends at tomorrow for midweek dates', () {
      final now = DateTime(2026, 5, 13, 14, 30);

      final range = currentWeekRange(now);

      expect(range.start, DateTime(2026, 5, 11));
      expect(range.end, DateTime(2026, 5, 14));
    });
  });

  group('calculateDashboardSummary', () {
    test('excludes transfer and balance adjustment transactions', () {
      final summary = calculateDashboardSummary([
        _txn(id: 1, type: TransactionType.expense.value, amount: 100),
        _txn(id: 2, type: TransactionType.income.value, amount: 250),
        _txn(id: 3, type: TransactionType.transfer.value, amount: 999),
        _txn(id: 4, type: TransactionType.balanceAdjustment.value, amount: 888),
      ]);

      expect(summary.expense, 100);
      expect(summary.income, 250);
      expect(summary.balance, 150);
    });

    test('returns zero summary for empty transactions', () {
      const summary = DashboardSummaryData(expense: 0, income: 0);

      expect(summary.expense, 0);
      expect(summary.income, 0);
      expect(summary.balance, 0);
    });
  });

  testWidgets('renders stacked weekly and monthly cards and hides amounts when disabled', (tester) async {
    final now = DateTime(2026, 5, 13, 10);
    final weekRange = currentWeekRange(now);
    final monthRange = currentMonthRange(now);
    final repo = _FakeTransactionRepository({
      '1|${weekRange.start.toIso8601String()}|${weekRange.end.toIso8601String()}': [
        _txn(id: 1, type: TransactionType.expense.value, amount: 100),
        _txn(id: 2, type: TransactionType.income.value, amount: 300),
      ],
      '1|${monthRange.start.toIso8601String()}|${monthRange.end.toIso8601String()}': [
        _txn(id: 3, type: TransactionType.expense.value, amount: 100),
        _txn(id: 4, type: TransactionType.income.value, amount: 300),
        _txn(id: 5, type: TransactionType.expense.value, amount: 20),
      ],
    });

    final container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repo),
        dashboardNowProvider.overrideWithValue(now),
        dashboardShowBackgroundProvider.overrideWithValue(false),
        amountVisibilityProvider.overrideWith(
          () => _StaticAmountVisibilityNotifier(false),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeLedgerIdProvider.notifier).set(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pump();

    expect(find.text('本周'), findsOneWidget);
    expect(find.text('2026年5月'), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('****'), findsNWidgets(6));
  });
}