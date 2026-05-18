import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/amount_visibility_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../app/theme.dart';

class DashboardSummaryData {
  final double expense;
  final double income;

  const DashboardSummaryData({required this.expense, required this.income});

  double get balance => income - expense;
}

final dashboardNowProvider = Provider<DateTime>((ref) => DateTime.now());
final dashboardShowBackgroundProvider = Provider<bool>((ref) => true);

({DateTime start, DateTime end}) currentDayRange(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  return (start: start, end: start.add(const Duration(days: 1)));
}

({DateTime start, DateTime end}) currentWeekRange(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: now.weekday - DateTime.monday));
  return (start: start, end: today.add(const Duration(days: 1)));
}

({DateTime start, DateTime end}) currentMonthRange(DateTime now) {
  final start = DateTime(now.year, now.month);
  return (start: start, end: DateTime(now.year, now.month + 1));
}

DashboardSummaryData calculateDashboardSummary(List<Transaction> transactions) {
  double totalExpense = 0;
  double totalIncome = 0;

  for (final transaction in transactions) {
    final type = TransactionType.fromValue(transaction.type);
    switch (type) {
      case TransactionType.expense:
        totalExpense += transaction.amount;
      case TransactionType.income:
        totalIncome += transaction.amount;
      case TransactionType.transfer:
      case TransactionType.balanceAdjustment:
        break;
    }
  }

  return DashboardSummaryData(expense: totalExpense, income: totalIncome);
}

final dashboardSummaryProvider =
    StreamProvider.family<DashboardSummaryData, (int, DateTime, DateTime)>((
      ref,
      params,
    ) {
      final (ledgerId, start, end) = params;
      return ref
          .watch(transactionRepositoryProvider)
          .watchByLedger(ledgerId, startDate: start, endDate: end)
          .map(calculateDashboardSummary);
    });

/// Dashboard / home page — shows summary for current month.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(activeLedgerIdProvider);
    if (ledgerId == null) {
      return const Scaffold(body: Center(child: Text('请先选择账本')));
    }

    final now = ref.watch(dashboardNowProvider);
    final showBackground = ref.watch(dashboardShowBackgroundProvider);
    final dayRange = currentDayRange(now);
    final weekRange = currentWeekRange(now);
    final monthRange = currentMonthRange(now);
    final amountVisible = ref.watch(amountVisibilityProvider);

    final dailySummaryAsync = ref.watch(
      dashboardSummaryProvider((ledgerId, dayRange.start, dayRange.end)),
    );
    final weeklySummaryAsync = ref.watch(
      dashboardSummaryProvider((ledgerId, weekRange.start, weekRange.end)),
    );
    final monthlySummaryAsync = ref.watch(
      dashboardSummaryProvider((ledgerId, monthRange.start, monthRange.end)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: Icon(amountVisible ? Icons.visibility : Icons.visibility_off),
            tooltip: amountVisible ? '隐藏金额' : '显示金额',
            onPressed: () =>
                ref.read(amountVisibilityProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '切换账本',
            onPressed: () {
              // Navigate to ledger selection
              ref.read(activeLedgerIdProvider.notifier).set(null);
            },
          ),
        ],
      ),
      body: dailySummaryAsync.when(
        data: (dailySummary) {
          return weeklySummaryAsync.when(
            data: (weeklySummary) {
              return monthlySummaryAsync.when(
                data: (monthlySummary) {
          final dpr = MediaQuery.devicePixelRatioOf(context);

          return LayoutBuilder(
            builder: (context, constraints) {
              final bgCacheWidth = (constraints.maxWidth * dpr)
                  .clamp(720.0, 1440.0)
                  .round();

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (showBackground)
                    Image(
                      image: ResizeImage(
                        const AssetImage('assets/image/home_bg.png'),
                        width: bgCacheWidth,
                      ),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                    ),
                  ColoredBox(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.52),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryCard(
                          title: '今天 ${now.month}/${now.day}',
                          summary: dailySummary,
                          amountVisible: amountVisible,
                        ),
                        const SizedBox(height: 16),
                        _SummaryCard(
                          title: '本周',
                          summary: weeklySummary,
                          amountVisible: amountVisible,
                        ),
                        const SizedBox(height: 16),
                        _SummaryCard(
                          title: '${now.year}年${now.month}月',
                          summary: monthlySummary,
                          amountVisible: amountVisible,
                        ),
                        const SizedBox(height: 16),
                        // Quick actions
                        Text(
                          '快捷操作',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _QuickAction(
                              icon: Icons.account_balance_wallet,
                              label: '账户管理',
                              onTap: () {},
                            ),
                            const SizedBox(width: 12),
                            _QuickAction(
                              icon: Icons.pie_chart_outline,
                              label: '预算设置',
                              onTap: () {},
                              badge: '敬请期待',
                            ),
                            const SizedBox(width: 12),
                            _QuickAction(
                              icon: Icons.analytics_outlined,
                              label: '深度报表',
                              onTap: () {},
                              badge: '敬请期待',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
            },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败：$e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final DashboardSummaryData summary;
  final bool amountVisible;

  const _SummaryCard({
    required this.title,
    required this.summary,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: '支出',
                    amount: summary.expense,
                    color: AppTheme.expenseColor,
                    amountVisible: amountVisible,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '收入',
                    amount: summary.income,
                    color: AppTheme.incomeColor,
                    amountVisible: amountVisible,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '结余',
                    amount: summary.balance,
                    color: Theme.of(context).colorScheme.onSurface,
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

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool amountVisible;

  const _SummaryItem({
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
          amountVisible ? '¥${AppTheme.formatDisplayAmount(amount)}' : '****',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                if (badge != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
