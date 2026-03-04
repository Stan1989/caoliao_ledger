import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/report_dao.dart';
import '../../../core/providers/database_provider.dart';

/// Time granularity for report range.
enum TimeGranularity { month, quarter, year, custom }

/// Dimension for aggregation.
enum ReportDimension { timeTrend, category, account, project }

/// Chart display type for non-time dimensions.
enum ChartType { bar, pie }

/// State for the report page.
class ReportState {
  final TimeGranularity granularity;
  final DateTime referenceDate;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ReportDimension dimension;
  final ChartType chartType;
  final bool showIncome; // false = expense, true = income
  final bool isLoading;
  final double totalExpense;
  final double totalIncome;
  final List<ReportSummaryItem> summaryItems;
  final List<TrendDataPoint> trendData;

  const ReportState({
    this.granularity = TimeGranularity.month,
    required this.referenceDate,
    this.customStart,
    this.customEnd,
    this.dimension = ReportDimension.timeTrend,
    this.chartType = ChartType.bar,
    this.showIncome = false,
    this.isLoading = false,
    this.totalExpense = 0,
    this.totalIncome = 0,
    this.summaryItems = const [],
    this.trendData = const [],
  });

  ReportState copyWith({
    TimeGranularity? granularity,
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
    ReportDimension? dimension,
    ChartType? chartType,
    bool? showIncome,
    bool? isLoading,
    double? totalExpense,
    double? totalIncome,
    List<ReportSummaryItem>? summaryItems,
    List<TrendDataPoint>? trendData,
  }) {
    return ReportState(
      granularity: granularity ?? this.granularity,
      referenceDate: referenceDate ?? this.referenceDate,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      dimension: dimension ?? this.dimension,
      chartType: chartType ?? this.chartType,
      showIncome: showIncome ?? this.showIncome,
      isLoading: isLoading ?? this.isLoading,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      summaryItems: summaryItems ?? this.summaryItems,
      trendData: trendData ?? this.trendData,
    );
  }

  /// Compute the start date of the current time range.
  DateTime get startDate {
    if (granularity == TimeGranularity.custom && customStart != null) {
      return customStart!;
    }
    switch (granularity) {
      case TimeGranularity.month:
        return DateTime(referenceDate.year, referenceDate.month);
      case TimeGranularity.quarter:
        final qMonth = ((referenceDate.month - 1) ~/ 3) * 3 + 1;
        return DateTime(referenceDate.year, qMonth);
      case TimeGranularity.year:
        return DateTime(referenceDate.year);
      case TimeGranularity.custom:
        return referenceDate;
    }
  }

  /// Compute the end date (exclusive) of the current time range.
  DateTime get endDate {
    if (granularity == TimeGranularity.custom && customEnd != null) {
      return customEnd!.add(const Duration(days: 1));
    }
    switch (granularity) {
      case TimeGranularity.month:
        return DateTime(referenceDate.year, referenceDate.month + 1);
      case TimeGranularity.quarter:
        final qMonth = ((referenceDate.month - 1) ~/ 3) * 3 + 1;
        return DateTime(referenceDate.year, qMonth + 3);
      case TimeGranularity.year:
        return DateTime(referenceDate.year + 1);
      case TimeGranularity.custom:
        return referenceDate.add(const Duration(days: 1));
    }
  }

  /// Display label for current time range.
  String get rangeLabel {
    switch (granularity) {
      case TimeGranularity.month:
        return '${referenceDate.year}年${referenceDate.month}月';
      case TimeGranularity.quarter:
        final q = (referenceDate.month - 1) ~/ 3 + 1;
        return '${referenceDate.year}年Q$q';
      case TimeGranularity.year:
        return '${referenceDate.year}年';
      case TimeGranularity.custom:
        if (customStart != null && customEnd != null) {
          return '${_fmtDate(customStart!)} ~ ${_fmtDate(customEnd!)}';
        }
        return '自定义';
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

/// Report notifier that fetches data from ReportDao.
class ReportNotifier extends Notifier<ReportState> {
  @override
  ReportState build() {
    final now = DateTime.now();
    final initial = ReportState(referenceDate: now);
    // Schedule initial data load after build.
    Future.microtask(() => _loadData());
    return initial;
  }

  ReportDao get _dao => ref.read(reportDaoProvider);

  int? get _ledgerId => ref.read(activeLedgerIdProvider);

  void setGranularity(TimeGranularity g) {
    state = state.copyWith(granularity: g);
    _loadData();
  }

  void setDimension(ReportDimension d) {
    state = state.copyWith(dimension: d);
    _loadData();
  }

  void setChartType(ChartType t) {
    state = state.copyWith(chartType: t);
  }

  void toggleIncomeExpense(bool showIncome) {
    state = state.copyWith(showIncome: showIncome);
    _loadData();
  }

  void previousPeriod() {
    final ref = state.referenceDate;
    DateTime newRef;
    switch (state.granularity) {
      case TimeGranularity.month:
        newRef = DateTime(ref.year, ref.month - 1);
        break;
      case TimeGranularity.quarter:
        newRef = DateTime(ref.year, ref.month - 3);
        break;
      case TimeGranularity.year:
        newRef = DateTime(ref.year - 1);
        break;
      case TimeGranularity.custom:
        return; // No previous for custom
    }
    state = state.copyWith(referenceDate: newRef);
    _loadData();
  }

  void nextPeriod() {
    final ref = state.referenceDate;
    DateTime newRef;
    switch (state.granularity) {
      case TimeGranularity.month:
        newRef = DateTime(ref.year, ref.month + 1);
        break;
      case TimeGranularity.quarter:
        newRef = DateTime(ref.year, ref.month + 3);
        break;
      case TimeGranularity.year:
        newRef = DateTime(ref.year + 1);
        break;
      case TimeGranularity.custom:
        return;
    }
    state = state.copyWith(referenceDate: newRef);
    _loadData();
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      granularity: TimeGranularity.custom,
      customStart: start,
      customEnd: end,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final ledgerId = _ledgerId;
    if (ledgerId == null) return;

    state = state.copyWith(isLoading: true);

    final start = state.startDate;
    final end = state.endDate;
    final type = state.showIncome ? 1 : 0;

    try {
      // Always load totals
      final totals = await _dao.getTotals(
        ledgerId,
        startDate: start,
        endDate: end,
      );

      if (state.dimension == ReportDimension.timeTrend) {
        List<TrendDataPoint> trend;
        if (state.granularity == TimeGranularity.month ||
            state.granularity == TimeGranularity.custom) {
          trend = await _dao.getDailyTrend(
            ledgerId,
            type,
            startDate: start,
            endDate: end,
          );
        } else {
          trend = await _dao.getMonthlyTrend(
            ledgerId,
            type,
            startDate: start,
            endDate: end,
          );
        }
        state = state.copyWith(
          isLoading: false,
          totalExpense: totals.expense,
          totalIncome: totals.income,
          trendData: trend,
          summaryItems: [],
        );
      } else {
        List<ReportSummaryItem> items;
        switch (state.dimension) {
          case ReportDimension.category:
            items = await _dao.getSummaryByCategory(
              ledgerId,
              type,
              startDate: start,
              endDate: end,
            );
            break;
          case ReportDimension.account:
            items = await _dao.getSummaryByAccount(
              ledgerId,
              type,
              startDate: start,
              endDate: end,
            );
            break;
          case ReportDimension.project:
            items = await _dao.getSummaryByProject(
              ledgerId,
              type,
              startDate: start,
              endDate: end,
            );
            break;
          default:
            items = [];
        }
        state = state.copyWith(
          isLoading: false,
          totalExpense: totals.expense,
          totalIncome: totals.income,
          summaryItems: items,
          trendData: [],
        );
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void refresh() => _loadData();
}

final reportProvider = NotifierProvider<ReportNotifier, ReportState>(
  ReportNotifier.new,
);
