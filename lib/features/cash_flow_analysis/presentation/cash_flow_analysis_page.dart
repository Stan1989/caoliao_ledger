import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/daos/report_dao.dart';
import '../../../core/providers/amount_visibility_provider.dart';
import '../../report/providers/report_provider.dart';
import '../providers/cash_flow_analysis_provider.dart';

class CashFlowAnalysisPage extends ConsumerWidget {
  const CashFlowAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashFlowAnalysisProvider);
    final notifier = ref.read(cashFlowAnalysisProvider.notifier);
    final amountVisible = ref.watch(amountVisibilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('现金流分析'),
        actions: [
          IconButton(
            icon: Icon(amountVisible ? Icons.visibility : Icons.visibility_off),
            tooltip: amountVisible ? '隐藏金额' : '显示金额',
            onPressed: () =>
                ref.read(amountVisibilityProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Column(
        children: [
          _TimeRangeSelector(state: state, notifier: notifier),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _OverviewCard(
                        overview: state.overview,
                        amountVisible: amountVisible,
                      ),
                      const SizedBox(height: 16),
                      _TrendCard(
                        trendData: state.netTrend,
                        granularity: state.granularity,
                        amountVisible: amountVisible,
                      ),
                      const SizedBox(height: 16),
                      _StructureSection(
                        inflowItems: state.inflowItems,
                        outflowItems: state.outflowItems,
                        amountVisible: amountVisible,
                      ),
                      const SizedBox(height: 16),
                      _RankingSection(
                        inflowItems: state.inflowItems,
                        outflowItems: state.outflowItems,
                        amountVisible: amountVisible,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  final CashFlowAnalysisState state;
  final CashFlowAnalysisNotifier notifier;

  const _TimeRangeSelector({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: TimeGranularity.values.map((granularity) {
              final label = switch (granularity) {
                TimeGranularity.month => '月',
                TimeGranularity.quarter => '季',
                TimeGranularity.year => '年',
                TimeGranularity.custom => '自定义',
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: state.granularity == granularity,
                  onSelected: (_) {
                    if (granularity == TimeGranularity.custom) {
                      _pickCustomRange(context);
                    } else {
                      notifier.setGranularity(granularity);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: state.granularity == TimeGranularity.custom
                    ? null
                    : notifier.previousPeriod,
              ),
              Text(
                state.rangeLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: state.granularity == TimeGranularity.custom
                    ? null
                    : notifier.nextPeriod,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month),
        end: now,
      ),
    );
    if (picked != null) {
      notifier.setCustomRange(picked.start, picked.end);
    }
  }
}

class _OverviewCard extends StatelessWidget {
  final CashFlowOverviewData overview;
  final bool amountVisible;

  const _OverviewCard({required this.overview, required this.amountVisible});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('现金流总览', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    label: '流入',
                    amount: overview.inflow,
                    color: AppTheme.incomeColor,
                    amountVisible: amountVisible,
                  ),
                ),
                Expanded(
                  child: _OverviewItem(
                    label: '流出',
                    amount: overview.outflow,
                    color: AppTheme.expenseColor,
                    amountVisible: amountVisible,
                  ),
                ),
                Expanded(
                  child: _OverviewItem(
                    label: '净现金流',
                    amount: overview.net,
                    color: overview.net >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    amountVisible: amountVisible,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool amountVisible;

  const _OverviewItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amountVisible
              ? '¥${AppTheme.formatDisplayAmount(amount)}'
              : '****',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<TrendDataPoint> trendData;
  final TimeGranularity granularity;
  final bool amountVisible;

  const _TrendCard({
    required this.trendData,
    required this.granularity,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('净现金流趋势', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (trendData.isEmpty)
              const SizedBox(height: 200, child: Center(child: Text('暂无数据')))
            else
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              amountVisible
                                  ? AppTheme.formatDisplayAmountCompact(value)
                                  : '****',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: trendData.length > 12 ? 2 : 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= trendData.length) {
                              return const SizedBox();
                            }
                            final date = trendData[index].date;
                            final label = granularity == TimeGranularity.month ||
                                    granularity == TimeGranularity.custom
                                ? '${date.day}'
                                : '${date.month}月';
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(label, style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: trendData
                            .asMap()
                            .entries
                            .map((entry) => FlSpot(entry.key.toDouble(), entry.value.amount))
                            .toList(),
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 2,
                        dotData: FlDotData(show: trendData.length <= 31),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StructureSection extends StatelessWidget {
  final List<ReportSummaryItem> inflowItems;
  final List<ReportSummaryItem> outflowItems;
  final bool amountVisible;

  const _StructureSection({
    required this.inflowItems,
    required this.outflowItems,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('结构分析', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _StructureCard(
          title: '流入结构',
          items: inflowItems,
          amountVisible: amountVisible,
          color: AppTheme.incomeColor,
        ),
        const SizedBox(height: 12),
        _StructureCard(
          title: '流出结构',
          items: outflowItems,
          amountVisible: amountVisible,
          color: AppTheme.expenseColor,
        ),
      ],
    );
  }
}

class _StructureCard extends StatelessWidget {
  final String title;
  final List<ReportSummaryItem> items;
  final bool amountVisible;
  final Color color;

  const _StructureCard({
    required this.title,
    required this.items,
    required this.amountVisible,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('暂无数据')
            else
              ...items.take(4).map((item) {
                final ratio = total == 0 ? 0.0 : item.amount / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.name)),
                          Text(
                            amountVisible
                                ? '¥${AppTheme.formatDisplayAmount(item.amount)}'
                                : '****',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: ratio,
                          backgroundColor: color.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${(ratio * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RankingSection extends StatelessWidget {
  final List<ReportSummaryItem> inflowItems;
  final List<ReportSummaryItem> outflowItems;
  final bool amountVisible;

  const _RankingSection({
    required this.inflowItems,
    required this.outflowItems,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('明细排行', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _RankingCard(
          title: '流入排行',
          items: inflowItems,
          color: AppTheme.incomeColor,
          amountVisible: amountVisible,
        ),
        const SizedBox(height: 12),
        _RankingCard(
          title: '流出排行',
          items: outflowItems,
          color: AppTheme.expenseColor,
          amountVisible: amountVisible,
        ),
      ],
    );
  }
}

class _RankingCard extends StatelessWidget {
  final String title;
  final List<ReportSummaryItem> items;
  final Color color;
  final bool amountVisible;

  const _RankingCard({
    required this.title,
    required this.items,
    required this.color,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('暂无数据')
            else
              ...items.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ),
                  title: Text(item.name),
                  trailing: Text(
                    amountVisible
                        ? '¥${AppTheme.formatDisplayAmount(item.amount)}'
                        : '****',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}