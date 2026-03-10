import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/daos/report_dao.dart';
import '../../../core/providers/amount_visibility_provider.dart';
import '../providers/report_provider.dart';

/// Report page with time range selector, dimension tabs, charts, and detail list.
class ReportPage extends ConsumerWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportProvider);
    final notifier = ref.read(reportProvider.notifier);
    final amountVisible = ref.watch(amountVisibilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表统计'),
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
          // Time range selector
          _TimeRangeSelector(state: state, notifier: notifier),
          // Dimension tabs
          _DimensionTabs(state: state, notifier: notifier),
          // Income / Expense toggle
          _IncomeExpenseToggle(
            state: state,
            notifier: notifier,
            amountVisible: amountVisible,
          ),
          // Chart area
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      _ChartArea(state: state, notifier: notifier),
                      _DetailList(state: state, amountVisible: amountVisible),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- Time Range Selector ----------

class _TimeRangeSelector extends StatelessWidget {
  final ReportState state;
  final ReportNotifier notifier;

  const _TimeRangeSelector({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Granularity chips
          Row(
            children: TimeGranularity.values.map((g) {
              final label = switch (g) {
                TimeGranularity.month => '月',
                TimeGranularity.quarter => '季',
                TimeGranularity.year => '年',
                TimeGranularity.custom => '自定义',
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: state.granularity == g,
                  onSelected: (_) {
                    if (g == TimeGranularity.custom) {
                      _pickCustomRange(context);
                    } else {
                      notifier.setGranularity(g);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Navigation arrows + label
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

// ---------- Dimension Tabs ----------

class _DimensionTabs extends StatelessWidget {
  final ReportState state;
  final ReportNotifier notifier;

  const _DimensionTabs({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ReportDimension>(
        segments: const [
          ButtonSegment(value: ReportDimension.timeTrend, label: Text('时间趋势')),
          ButtonSegment(value: ReportDimension.category, label: Text('分类')),
          ButtonSegment(value: ReportDimension.account, label: Text('账号')),
          ButtonSegment(value: ReportDimension.project, label: Text('项目')),
        ],
        selected: {state.dimension},
        onSelectionChanged: (s) => notifier.setDimension(s.first),
      ),
    );
  }
}

// ---------- Income / Expense Toggle ----------

class _IncomeExpenseToggle extends StatelessWidget {
  final ReportState state;
  final ReportNotifier notifier;
  final bool amountVisible;

  const _IncomeExpenseToggle({
    required this.state,
    required this.notifier,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _ToggleCard(
              label: '支出',
              amount: state.totalExpense,
              selected: !state.showIncome,
              color: cs.error,
              onTap: () => notifier.toggleIncomeExpense(false),
              amountVisible: amountVisible,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ToggleCard(
              label: '收入',
              amount: state.totalIncome,
              selected: state.showIncome,
              color: cs.primary,
              onTap: () => notifier.toggleIncomeExpense(true),
              amountVisible: amountVisible,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String label;
  final double amount;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool amountVisible;

  const _ToggleCard({
    required this.label,
    required this.amount,
    required this.selected,
    required this.color,
    required this.onTap,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: selected ? 2 : 0,
      color: selected
          ? color.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : null,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amountVisible
                    ? '¥${AppTheme.formatDisplayAmount(amount)}'
                    : '****',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Chart Area ----------

class _ChartArea extends StatelessWidget {
  final ReportState state;
  final ReportNotifier notifier;

  const _ChartArea({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.dimension == ReportDimension.timeTrend) {
      return _buildLineChart(context);
    }

    return Column(
      children: [
        // Chart type toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (state.chartType == ChartType.bar)
                IconButton(
                  tooltip: '全屏查看',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _FullscreenBarChartPage(state: state),
                      ),
                    );
                  },
                ),
              SegmentedButton<ChartType>(
                segments: const [
                  ButtonSegment(
                    value: ChartType.bar,
                    icon: Icon(Icons.bar_chart),
                  ),
                  ButtonSegment(
                    value: ChartType.pie,
                    icon: Icon(Icons.pie_chart),
                  ),
                ],
                selected: {state.chartType},
                onSelectionChanged: (s) => notifier.setChartType(s.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (state.chartType == ChartType.bar)
          _buildBarChart(context)
        else
          _buildPieChart(context),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context) {
    final data = state.trendData;
    if (data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        AppTheme.formatDisplayAmountCompact(value),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: _bottomInterval(data.length),
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= data.length) return const SizedBox();
                    final d = data[idx].date;
                    final label =
                        state.granularity == TimeGranularity.month ||
                            state.granularity == TimeGranularity.custom
                        ? '${d.day}'
                        : '${d.month}月';
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(label, style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 2,
                dotData: FlDotData(show: data.length <= 31),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _bottomInterval(int length) {
    if (length <= 12) return 1;
    if (length <= 31) return 5;
    return (length / 6).ceilToDouble();
  }

  Widget _buildBarChart(BuildContext context) {
    final items = state.summaryItems;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _BarChartPanel(
        items: items,
        paletteResolver: (index) => _chartColor(context, index),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    final items = state.summaryItems;
    if (items.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }

    final total = items.fold<double>(0, (s, e) => s + e.amount);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: items.asMap().entries.map((e) {
              final pct = total > 0 ? (e.value.amount / total * 100) : 0.0;
              return PieChartSectionData(
                value: e.value.amount,
                color: _chartColor(context, e.key),
                title: '${pct.toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _chartColor(BuildContext context, int index) {
    const palette = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFEF5350),
      Color(0xFFFF7043),
      Color(0xFFAB47BC),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFFA726),
      Color(0xFF8D6E63),
      Color(0xFF78909C),
    ];
    return palette[index % palette.length];
  }
}

class _BarChartPanel extends StatelessWidget {
  final List<ReportSummaryItem> items;
  final Color Function(int index) paletteResolver;

  const _BarChartPanel({required this.items, required this.paletteResolver});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }

    final maxAmount = items.fold<double>(
      0,
      (m, e) => e.amount > m ? e.amount : m,
    );

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barGroups: items.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.amount,
                  color: paletteResolver(e.key),
                  width: items.length > 8 ? 12 : 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      AppTheme.formatDisplayAmountCompact(value),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      items[idx].name.length > 4
                          ? '${items[idx].name.substring(0, 4)}…'
                          : items[idx].name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
        ),
      ),
    );
  }
}

class _FullscreenBarChartPage extends StatefulWidget {
  final ReportState state;

  const _FullscreenBarChartPage({required this.state});

  @override
  State<_FullscreenBarChartPage> createState() =>
      _FullscreenBarChartPageState();
}

class _FullscreenBarChartPageState extends State<_FullscreenBarChartPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('柱状图全屏')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _BarChartPanel(
            items: widget.state.summaryItems,
            paletteResolver: (index) {
              const palette = [
                Color(0xFF5C6BC0),
                Color(0xFF26A69A),
                Color(0xFFEF5350),
                Color(0xFFFF7043),
                Color(0xFFAB47BC),
                Color(0xFF42A5F5),
                Color(0xFF66BB6A),
                Color(0xFFFFA726),
                Color(0xFF8D6E63),
                Color(0xFF78909C),
              ];
              return palette[index % palette.length];
            },
          ),
        ),
      ),
    );
  }
}

// ---------- Detail List ----------

class _DetailList extends StatelessWidget {
  final ReportState state;
  final bool amountVisible;

  const _DetailList({required this.state, required this.amountVisible});

  @override
  Widget build(BuildContext context) {
    if (state.dimension == ReportDimension.timeTrend) {
      return _buildTrendList(context);
    }
    return _buildSummaryList(context);
  }

  Widget _buildTrendList(BuildContext context) {
    final data = state.trendData;
    if (data.isEmpty) return const SizedBox();

    return Column(
      children: data.map((point) {
        final label =
            state.granularity == TimeGranularity.month ||
                state.granularity == TimeGranularity.custom
            ? '${point.date.month}/${point.date.day}'
            : '${point.date.year}/${point.date.month}';
        return ListTile(
          dense: true,
          title: Text(label),
          trailing: Text(
            amountVisible
                ? '¥${AppTheme.formatDisplayAmount(point.amount)}'
                : '****',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryList(BuildContext context) {
    final items = state.summaryItems;
    if (items.isEmpty) return const SizedBox();

    final total = items.fold<double>(0, (s, e) => s + e.amount);

    const palette = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFEF5350),
      Color(0xFFFF7042),
      Color(0xFFAB47BC),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFFA726),
      Color(0xFF8D6E63),
      Color(0xFF78909C),
    ];

    return Column(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        final pct = total > 0 ? item.amount / total : 0.0;
        return ListTile(
          leading: CircleAvatar(
            radius: 6,
            backgroundColor: palette[e.key % palette.length],
          ),
          title: Text(item.name),
          subtitle: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: palette[e.key % palette.length],
              minHeight: 6,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountVisible
                    ? '¥${AppTheme.formatDisplayAmount(item.amount)}'
                    : '****',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                amountVisible ? '${(pct * 100).toStringAsFixed(1)}%' : '****',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
