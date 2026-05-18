import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/core/database/daos/report_dao.dart';
import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/core/providers/amount_visibility_provider.dart';
import 'package:caoliao_ledger/features/cash_flow_analysis/presentation/cash_flow_analysis_page.dart';
import 'package:caoliao_ledger/features/cash_flow_analysis/providers/cash_flow_analysis_provider.dart';
import 'package:caoliao_ledger/features/report/providers/report_provider.dart';

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

class _StaticCashFlowAnalysisNotifier extends CashFlowAnalysisNotifier {
  _StaticCashFlowAnalysisNotifier(this._state);

  final CashFlowAnalysisState _state;

  @override
  CashFlowAnalysisState build() => _state;
}

void main() {
  test('loadCashFlowAnalysisSnapshot excludes transfer and balance adjustment', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime(2026, 5, 13, 10);
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '测试账本', updatedAt: Value(now)),
        );
    final accountId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            ledgerId: ledgerId,
            name: '现金',
            type: AccountType.cash.value,
            updatedAt: Value(now),
          ),
        );
    final salaryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            ledgerId: ledgerId,
            name: '工资',
            type: CategoryType.income.value,
            updatedAt: Value(now),
          ),
        );
    final bonusId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            ledgerId: ledgerId,
            name: '奖金',
            type: CategoryType.income.value,
            updatedAt: Value(now),
          ),
        );
    final rentId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            ledgerId: ledgerId,
            name: '房租',
            type: CategoryType.expense.value,
            updatedAt: Value(now),
          ),
        );
    final foodId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            ledgerId: ledgerId,
            name: '餐饮',
            type: CategoryType.expense.value,
            updatedAt: Value(now),
          ),
        );

    Future<void> insertTransaction({
      required int type,
      required double amount,
      required DateTime date,
      int? categoryId,
    }) {
      return db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: type,
              amount: amount,
              accountId: accountId,
              categoryId: Value(categoryId),
              transactionDate: date,
              updatedAt: Value(now),
            ),
          );
    }

    await insertTransaction(
      type: TransactionType.income.value,
      amount: 3000,
      date: DateTime(2026, 5, 5, 9),
      categoryId: salaryId,
    );
    await insertTransaction(
      type: TransactionType.income.value,
      amount: 500,
      date: DateTime(2026, 5, 20, 9),
      categoryId: bonusId,
    );
    await insertTransaction(
      type: TransactionType.expense.value,
      amount: 1000,
      date: DateTime(2026, 5, 2, 9),
      categoryId: rentId,
    );
    await insertTransaction(
      type: TransactionType.expense.value,
      amount: 300,
      date: DateTime(2026, 5, 6, 9),
      categoryId: foodId,
    );
    await insertTransaction(
      type: TransactionType.expense.value,
      amount: 200,
      date: DateTime(2026, 5, 15, 9),
      categoryId: foodId,
    );
    await insertTransaction(
      type: TransactionType.transfer.value,
      amount: 9999,
      date: DateTime(2026, 5, 9, 9),
    );
    await insertTransaction(
      type: TransactionType.balanceAdjustment.value,
      amount: 8888,
      date: DateTime(2026, 5, 10, 9),
    );

    final snapshot = await loadCashFlowAnalysisSnapshot(
      dao: db.reportDao,
      ledgerId: ledgerId,
      granularity: TimeGranularity.month,
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 6, 1),
    );

    expect(snapshot.overview.inflow, 3500);
    expect(snapshot.overview.outflow, 1500);
    expect(snapshot.overview.net, 2000);

    expect(snapshot.inflowItems.map((item) => item.name), ['工资', '奖金']);
    expect(snapshot.inflowItems.map((item) => item.amount), [3000, 500]);
    expect(snapshot.outflowItems.map((item) => item.name), ['房租', '餐饮']);
    expect(snapshot.outflowItems.map((item) => item.amount), [1000, 500]);

    expect(snapshot.netTrend.length, 5);
    expect(snapshot.netTrend[0].date, DateTime(2026, 5, 2));
    expect(snapshot.netTrend[0].amount, -1000);
    expect(snapshot.netTrend[1].date, DateTime(2026, 5, 5));
    expect(snapshot.netTrend[1].amount, 3000);
    expect(snapshot.netTrend[2].date, DateTime(2026, 5, 6));
    expect(snapshot.netTrend[2].amount, -300);
    expect(snapshot.netTrend[3].date, DateTime(2026, 5, 15));
    expect(snapshot.netTrend[3].amount, -200);
    expect(snapshot.netTrend[4].date, DateTime(2026, 5, 20));
    expect(snapshot.netTrend[4].amount, 500);
  });

  testWidgets('renders overview, trend, structure, and ranking sections', (
    tester,
  ) async {
    final state = CashFlowAnalysisState(
      referenceDate: DateTime(2026, 5, 13),
      granularity: TimeGranularity.month,
      overview: const CashFlowOverviewData(inflow: 3600, outflow: 1500),
      netTrend: [
        TrendDataPoint(date: DateTime(2026, 5, 2), amount: -1000),
        TrendDataPoint(date: DateTime(2026, 5, 5), amount: 3000),
      ],
      inflowItems: [
        ReportSummaryItem(id: 1, name: '工资', amount: 3000),
        ReportSummaryItem(id: 2, name: '奖金', amount: 600),
      ],
      outflowItems: [
        ReportSummaryItem(id: 3, name: '房租', amount: 1000),
        ReportSummaryItem(id: 4, name: '餐饮', amount: 500),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashFlowAnalysisProvider.overrideWith(
            () => _StaticCashFlowAnalysisNotifier(state),
          ),
          amountVisibilityProvider.overrideWith(
            () => _StaticAmountVisibilityNotifier(true),
          ),
        ],
        child: const MaterialApp(home: CashFlowAnalysisPage()),
      ),
    );
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;

    expect(find.text('现金流总览'), findsOneWidget);
    expect(find.text('净现金流趋势'), findsOneWidget);
    expect(find.text('¥3,600.00'), findsOneWidget);
    expect(find.text('¥1,500.00'), findsOneWidget);
    expect(find.text('¥2,100.00'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('流入结构'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('流入结构'), findsOneWidget);
    expect(find.text('流出结构'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('流入排行'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('流入排行'), findsOneWidget);
    expect(find.text('流出排行'), findsOneWidget);
  });
}