import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/report_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../../report/providers/report_provider.dart';

class CashFlowOverviewData {
  final double inflow;
  final double outflow;

  const CashFlowOverviewData({required this.inflow, required this.outflow});

  double get net => inflow - outflow;
}

class CashFlowAnalysisSnapshot {
  final CashFlowOverviewData overview;
  final List<TrendDataPoint> netTrend;
  final List<ReportSummaryItem> inflowItems;
  final List<ReportSummaryItem> outflowItems;

  const CashFlowAnalysisSnapshot({
    required this.overview,
    required this.netTrend,
    required this.inflowItems,
    required this.outflowItems,
  });
}

List<TrendDataPoint> mergeNetCashFlowTrend({
  required List<TrendDataPoint> inflowTrend,
  required List<TrendDataPoint> outflowTrend,
}) {
  final totalsByDate = <DateTime, double>{};

  for (final point in inflowTrend) {
    totalsByDate.update(point.date, (value) => value + point.amount, ifAbsent: () => point.amount);
  }
  for (final point in outflowTrend) {
    totalsByDate.update(point.date, (value) => value - point.amount, ifAbsent: () => -point.amount);
  }

  final entries = totalsByDate.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries
      .map((entry) => TrendDataPoint(date: entry.key, amount: entry.value))
      .toList();
}

Future<CashFlowAnalysisSnapshot> loadCashFlowAnalysisSnapshot({
  required ReportDao dao,
  required int ledgerId,
  required TimeGranularity granularity,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final totals = await dao.getTotals(
    ledgerId,
    startDate: startDate,
    endDate: endDate,
  );

  final Future<List<TrendDataPoint>> inflowTrendFuture =
      granularity == TimeGranularity.month || granularity == TimeGranularity.custom
      ? dao.getDailyTrend(
          ledgerId,
          1,
          startDate: startDate,
          endDate: endDate,
        )
      : dao.getMonthlyTrend(
          ledgerId,
          1,
          startDate: startDate,
          endDate: endDate,
        );
  final Future<List<TrendDataPoint>> outflowTrendFuture =
      granularity == TimeGranularity.month || granularity == TimeGranularity.custom
      ? dao.getDailyTrend(
          ledgerId,
          0,
          startDate: startDate,
          endDate: endDate,
        )
      : dao.getMonthlyTrend(
          ledgerId,
          0,
          startDate: startDate,
          endDate: endDate,
        );

  final results = await Future.wait([
    inflowTrendFuture,
    outflowTrendFuture,
    dao.getSummaryByCategory(
      ledgerId,
      1,
      startDate: startDate,
      endDate: endDate,
    ),
    dao.getSummaryByCategory(
      ledgerId,
      0,
      startDate: startDate,
      endDate: endDate,
    ),
  ]);

  final inflowTrend = results[0] as List<TrendDataPoint>;
  final outflowTrend = results[1] as List<TrendDataPoint>;
  final inflowItems = results[2] as List<ReportSummaryItem>;
  final outflowItems = results[3] as List<ReportSummaryItem>;

  return CashFlowAnalysisSnapshot(
    overview: CashFlowOverviewData(
      inflow: totals.income,
      outflow: totals.expense,
    ),
    netTrend: mergeNetCashFlowTrend(
      inflowTrend: inflowTrend,
      outflowTrend: outflowTrend,
    ),
    inflowItems: inflowItems,
    outflowItems: outflowItems,
  );
}

class CashFlowAnalysisState {
  final TimeGranularity granularity;
  final DateTime referenceDate;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool isLoading;
  final CashFlowOverviewData overview;
  final List<TrendDataPoint> netTrend;
  final List<ReportSummaryItem> inflowItems;
  final List<ReportSummaryItem> outflowItems;

  const CashFlowAnalysisState({
    this.granularity = TimeGranularity.month,
    required this.referenceDate,
    this.customStart,
    this.customEnd,
    this.isLoading = false,
    this.overview = const CashFlowOverviewData(inflow: 0, outflow: 0),
    this.netTrend = const [],
    this.inflowItems = const [],
    this.outflowItems = const [],
  });

  CashFlowAnalysisState copyWith({
    TimeGranularity? granularity,
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
    bool? isLoading,
    CashFlowOverviewData? overview,
    List<TrendDataPoint>? netTrend,
    List<ReportSummaryItem>? inflowItems,
    List<ReportSummaryItem>? outflowItems,
  }) {
    return CashFlowAnalysisState(
      granularity: granularity ?? this.granularity,
      referenceDate: referenceDate ?? this.referenceDate,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      isLoading: isLoading ?? this.isLoading,
      overview: overview ?? this.overview,
      netTrend: netTrend ?? this.netTrend,
      inflowItems: inflowItems ?? this.inflowItems,
      outflowItems: outflowItems ?? this.outflowItems,
    );
  }

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

  String get rangeLabel {
    switch (granularity) {
      case TimeGranularity.month:
        return '${referenceDate.year}年${referenceDate.month}月';
      case TimeGranularity.quarter:
        final quarter = (referenceDate.month - 1) ~/ 3 + 1;
        return '${referenceDate.year}年Q$quarter';
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

class CashFlowAnalysisNotifier extends Notifier<CashFlowAnalysisState> {
  @override
  CashFlowAnalysisState build() {
    final initial = CashFlowAnalysisState(referenceDate: DateTime.now());
    Future.microtask(() => _loadData());
    return initial;
  }

  ReportDao get _dao => ref.read(reportDaoProvider);

  int? get _ledgerId => ref.read(activeLedgerIdProvider);

  void setGranularity(TimeGranularity granularity) {
    state = state.copyWith(granularity: granularity);
    _loadData();
  }

  void previousPeriod() {
    final referenceDate = state.referenceDate;
    DateTime nextReferenceDate;
    switch (state.granularity) {
      case TimeGranularity.month:
        nextReferenceDate = DateTime(referenceDate.year, referenceDate.month - 1);
      case TimeGranularity.quarter:
        nextReferenceDate = DateTime(referenceDate.year, referenceDate.month - 3);
      case TimeGranularity.year:
        nextReferenceDate = DateTime(referenceDate.year - 1);
      case TimeGranularity.custom:
        return;
    }
    state = state.copyWith(referenceDate: nextReferenceDate);
    _loadData();
  }

  void nextPeriod() {
    final referenceDate = state.referenceDate;
    DateTime nextReferenceDate;
    switch (state.granularity) {
      case TimeGranularity.month:
        nextReferenceDate = DateTime(referenceDate.year, referenceDate.month + 1);
      case TimeGranularity.quarter:
        nextReferenceDate = DateTime(referenceDate.year, referenceDate.month + 3);
      case TimeGranularity.year:
        nextReferenceDate = DateTime(referenceDate.year + 1);
      case TimeGranularity.custom:
        return;
    }
    state = state.copyWith(referenceDate: nextReferenceDate);
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

    try {
      final snapshot = await loadCashFlowAnalysisSnapshot(
        dao: _dao,
        ledgerId: ledgerId,
        granularity: state.granularity,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        isLoading: false,
        overview: snapshot.overview,
        netTrend: snapshot.netTrend,
        inflowItems: snapshot.inflowItems,
        outflowItems: snapshot.outflowItems,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final cashFlowAnalysisProvider =
    NotifierProvider<CashFlowAnalysisNotifier, CashFlowAnalysisState>(
  CashFlowAnalysisNotifier.new,
);