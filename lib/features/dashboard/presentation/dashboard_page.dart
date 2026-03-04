import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/amount_visibility_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../app/theme.dart';

/// Dashboard / home page — shows summary for current month.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(activeLedgerIdProvider);
    if (ledgerId == null) {
      return const Scaffold(
        body: Center(child: Text('请先选择账本')),
      );
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final amountVisible = ref.watch(amountVisibilityProvider);

    final transactionsAsync = ref.watch(
      _monthlyTransactionsProvider((ledgerId, start, end)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: Icon(amountVisible ? Icons.visibility : Icons.visibility_off),
            tooltip: amountVisible ? '隐藏金额' : '显示金额',
            onPressed: () => ref.read(amountVisibilityProvider.notifier).toggle(),
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
      body: transactionsAsync.when(
        data: (transactions) {
          double totalExpense = 0;
          double totalIncome = 0;

          for (final t in transactions) {
            final type = TransactionType.fromValue(t.type);
            switch (type) {
              case TransactionType.expense:
                totalExpense += t.amount;
              case TransactionType.income:
                totalIncome += t.amount;
              case TransactionType.transfer:
              case TransactionType.balanceAdjustment:
                break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Monthly summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${now.year}年${now.month}月',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryItem(
                                label: '支出',
                                amount: totalExpense,
                                color: AppTheme.expenseColor,
                                amountVisible: amountVisible,
                              ),
                            ),
                            Expanded(
                              child: _SummaryItem(
                                label: '收入',
                                amount: totalIncome,
                                color: AppTheme.incomeColor,
                                amountVisible: amountVisible,
                              ),
                            ),
                            Expanded(
                              child: _SummaryItem(
                                label: '结余',
                                amount: totalIncome - totalExpense,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                                amountVisible: amountVisible,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

/// Provider for monthly transactions.
final _monthlyTransactionsProvider = StreamProvider.family<
    List<Transaction>, (int, DateTime, DateTime)>((ref, params) {
  final (ledgerId, start, end) = params;
  return ref.watch(transactionRepositoryProvider).watchByLedger(
        ledgerId,
        startDate: start,
        endDate: end,
      );
});

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
          amountVisible
              ? '¥${amount.toStringAsFixed(2)}'
              : '****',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
