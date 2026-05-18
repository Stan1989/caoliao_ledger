import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/database/daos/report_dao.dart';
import 'package:caoliao_ledger/core/providers/amount_visibility_provider.dart';
import 'package:caoliao_ledger/features/report/presentation/report_page.dart';
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

class _StaticReportNotifier extends ReportNotifier {
  _StaticReportNotifier(this._state);

  final ReportState _state;

  @override
  ReportState build() => _state;
}

void main() {
  group('buildChartSummaryItems', () {
    test('returns original items when there are 10 or fewer entries', () {
      final items = List.generate(
        10,
        (index) => ReportSummaryItem(
          id: index,
          name: '项目$index',
          amount: (100 - index).toDouble(),
        ),
      );

      expect(buildChartSummaryItems(items), same(items));
    });

    test('returns top 10 items plus aggregated others entry', () {
      final items = List.generate(
        12,
        (index) => ReportSummaryItem(
          id: index,
          name: '项目$index',
          amount: (120 - index).toDouble(),
        ),
      );

      final chartItems = buildChartSummaryItems(items);

      expect(chartItems, hasLength(11));
      expect(chartItems.take(10).map((item) => item.name),
          items.take(10).map((item) => item.name));
      expect(chartItems.last.name, '其他');
      expect(
        chartItems.last.amount,
        items.skip(10).fold<double>(0, (sum, item) => sum + item.amount),
      );
    });
  });

  group('ReportState comparison ranges', () {
    test('calculates previous period and same period last year for quarter', () {
      final state = ReportState(
        referenceDate: DateTime(2026, 5, 13),
        granularity: TimeGranularity.quarter,
      );

      expect(state.supportsComparison, isTrue);
      expect(state.previousPeriodRange, isNotNull);
      expect(state.samePeriodLastYearRange, isNotNull);
      expect(state.previousPeriodRange!.start, DateTime(2026, 1, 1));
      expect(state.previousPeriodRange!.end, DateTime(2026, 4, 1));
      expect(state.samePeriodLastYearRange!.start, DateTime(2025, 4, 1));
      expect(state.samePeriodLastYearRange!.end, DateTime(2025, 7, 1));
    });

    test('does not support comparison for custom range', () {
      final state = ReportState(
        referenceDate: DateTime(2026, 5, 13),
        granularity: TimeGranularity.custom,
        customStart: DateTime(2026, 5, 1),
        customEnd: DateTime(2026, 5, 13),
      );

      expect(state.supportsComparison, isFalse);
      expect(state.previousPeriodRange, isNull);
      expect(state.samePeriodLastYearRange, isNull);
    });
  });

  group('buildReportComparisonSummary', () {
    test('returns null percentage for zero baseline', () {
      final summary = buildReportComparisonSummary(
        supported: true,
        currentAmount: 500,
        previousAmount: 0,
        previousYearAmount: 250,
      );

      expect(summary.supported, isTrue);
      expect(summary.periodOverPeriod, isNotNull);
      expect(summary.periodOverPeriod!.deltaAmount, 500);
      expect(summary.periodOverPeriod!.deltaPercent, isNull);
      expect(summary.yearOverYear!.deltaPercent, 100);
    });
  });

  testWidgets('renders comparison lines on summary cards for non-custom views', (
    tester,
  ) async {
    final state = ReportState(
      referenceDate: DateTime(2026, 5, 13),
      granularity: TimeGranularity.month,
      dimension: ReportDimension.timeTrend,
      totalExpense: 1200,
      totalIncome: 3600,
      expenseComparison: buildReportComparisonSummary(
        supported: true,
        currentAmount: 1200,
        previousAmount: 1000,
        previousYearAmount: 900,
      ),
      incomeComparison: buildReportComparisonSummary(
        supported: true,
        currentAmount: 3600,
        previousAmount: 3000,
        previousYearAmount: 0,
      ),
      trendData: const <TrendDataPoint>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportProvider.overrideWith(() => _StaticReportNotifier(state)),
          amountVisibilityProvider.overrideWith(
            () => _StaticAmountVisibilityNotifier(true),
          ),
        ],
        child: const MaterialApp(home: ReportPage()),
      ),
    );
    await tester.pump();

    expect(find.text('环比'), findsNWidgets(2));
    expect(find.text('同比'), findsNWidgets(2));
    expect(find.text('+¥200.00 (+20.0%)'), findsOneWidget);
    expect(find.text('+¥300.00 (+33.3%)'), findsOneWidget);
    expect(find.text('+¥600.00 (+20.0%)'), findsOneWidget);
    expect(find.text('+¥3,600.00 (--)'), findsOneWidget);
  });

  testWidgets('keeps comparison lines readable on narrow widths', (tester) async {
    final state = ReportState(
      referenceDate: DateTime(2026, 5, 13),
      granularity: TimeGranularity.month,
      dimension: ReportDimension.timeTrend,
      totalExpense: 999999.88,
      totalIncome: 888888.66,
      expenseComparison: buildReportComparisonSummary(
        supported: true,
        currentAmount: 999999.88,
        previousAmount: 12345.67,
        previousYearAmount: 23456.78,
      ),
      incomeComparison: buildReportComparisonSummary(
        supported: true,
        currentAmount: 888888.66,
        previousAmount: 34567.89,
        previousYearAmount: 45678.91,
      ),
      trendData: const <TrendDataPoint>[],
    );

    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportProvider.overrideWith(() => _StaticReportNotifier(state)),
          amountVisibilityProvider.overrideWith(
            () => _StaticAmountVisibilityNotifier(true),
          ),
        ],
        child: const MaterialApp(home: ReportPage()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('环比'), findsNWidgets(2));
    expect(find.text('同比'), findsNWidgets(2));
  });
}