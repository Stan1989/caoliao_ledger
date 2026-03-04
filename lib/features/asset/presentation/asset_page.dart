import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/amount_visibility_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../providers/asset_filter_provider.dart';
import '../providers/asset_period_stats_provider.dart';

/// Asset management page — list and manage accounts.
class AssetPage extends ConsumerWidget {
  const AssetPage({super.key});

  static const _liabilityTypes = {AccountType.creditCard, AccountType.liability};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(allAccountsProvider);
    final amountVisible = ref.watch(amountVisibilityProvider);
    final filter = ref.watch(assetFilterProvider);
    final periodStatsAsync = ref.watch(assetPeriodStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        actions: [
          IconButton(
            icon: Icon(amountVisible ? Icons.visibility : Icons.visibility_off),
            tooltip: amountVisible ? '隐藏金额' : '显示金额',
            onPressed: () => ref.read(amountVisibilityProvider.notifier).toggle(),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('还没有账户'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showCreateAccount(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('添加账户'),
                  ),
                ],
              ),
            );
          }

          // Group by type
          final grouped = <AccountType, List<Account>>{};
          double totalAsset = 0;
          double totalLiability = 0;
          for (final a in accounts) {
            final type = AccountType.fromValue(a.type);
            grouped.putIfAbsent(type, () => []).add(a);
            if (!a.isArchived) {
              if (_liabilityTypes.contains(type)) {
                totalLiability += a.balance;
              } else {
                totalAsset += a.balance;
              }
            }
          }
          final netAsset = totalAsset - totalLiability;

          final isPeriodMode = filter.mode != AssetFilterMode.all;
          final periodStats = periodStatsAsync.value;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filter selector
              _FilterSelector(
                mode: filter.mode,
                onChanged: (mode) =>
                    ref.read(assetFilterProvider.notifier).setMode(mode),
              ),

              // Period navigator (only in month/year mode)
              if (isPeriodMode)
                _PeriodNavigator(
                  mode: filter.mode,
                  date: filter.selectedDate,
                  onPrevious: () =>
                      ref.read(assetFilterProvider.notifier).previousPeriod(),
                  onNext: () =>
                      ref.read(assetFilterProvider.notifier).nextPeriod(),
                ),

              const SizedBox(height: 8),

              // Summary card
              if (isPeriodMode && periodStats != null)
                _PeriodSummaryCard(
                  stats: periodStats,
                  amountVisible: amountVisible,
                )
              else
                _NetAssetCard(
                  netAsset: netAsset,
                  totalAsset: totalAsset,
                  totalLiability: totalLiability,
                  amountVisible: amountVisible,
                ),

              const SizedBox(height: 16),

              // Group sections
              ...grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Text(
                        entry.key.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    ...entry.value.map((account) {
                      final isLiability =
                          _liabilityTypes.contains(AccountType.fromValue(account.type));
                      final displayBalance =
                          isLiability ? -account.balance : account.balance;
                      final accountStats =
                          periodStats?.byAccount[account.id];

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.push(
                            '/account/${account.id}/transactions?name=${Uri.encodeComponent(account.name)}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row: name + balance
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(account.name),
                                        if (account.isArchived) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '已归档',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                            ),
                                          ),
                                        ],
                                        if (account.cardLastFour != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '**** ${account.cardLastFour}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    amountVisible
                                        ? '¥${displayBalance.toStringAsFixed(2)}'
                                        : '****',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),

                              // Period stats row (only in period mode)
                              if (isPeriodMode) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _SmallStat(
                                      label: '收',
                                      value: accountStats?.income ?? 0,
                                      amountVisible: amountVisible,
                                    ),
                                    const SizedBox(width: 16),
                                    _SmallStat(
                                      label: '支',
                                      value: accountStats?.expense ?? 0,
                                      amountVisible: amountVisible,
                                    ),
                                    const SizedBox(width: 16),
                                    _SmallStat(
                                      label: '净',
                                      value: accountStats?.net ?? 0,
                                      amountVisible: amountVisible,
                                      highlight: true,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAccount(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateAccount(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    var selectedType = AccountType.cash;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('添加账户',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '账户名称'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: '账户类型'),
                items: AccountType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setModalState(() => selectedType = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(labelText: '初始余额'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final balance =
                          double.tryParse(balanceController.text) ?? 0;
                      final ledgerId =
                          ref.read(activeLedgerIdProvider)!;
                      await ref
                          .read(accountRepositoryProvider)
                          .createAccount(
                            ledgerId: ledgerId,
                            name: name,
                            type: selectedType.value,
                            balance: balance,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _FilterSelector extends StatelessWidget {
  final AssetFilterMode mode;
  final ValueChanged<AssetFilterMode> onChanged;

  const _FilterSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<AssetFilterMode>(
        segments: const [
          ButtonSegment(value: AssetFilterMode.all, label: Text('全部')),
          ButtonSegment(value: AssetFilterMode.month, label: Text('按月')),
          ButtonSegment(value: AssetFilterMode.year, label: Text('按年')),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  final AssetFilterMode mode;
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodNavigator({
    required this.mode,
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = mode == AssetFilterMode.month
        ? '${date.year}年${date.month}月'
        : '${date.year}年';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _NetAssetCard extends StatelessWidget {
  final double netAsset;
  final double totalAsset;
  final double totalLiability;
  final bool amountVisible;

  const _NetAssetCard({
    required this.netAsset,
    required this.totalAsset,
    required this.totalLiability,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('净资产', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              amountVisible
                  ? '¥${netAsset.toStringAsFixed(2)}'
                  : '****',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '总资产',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountVisible
                          ? '¥${totalAsset.toStringAsFixed(2)}'
                          : '****',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '总负债',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountVisible
                          ? '¥${totalLiability.toStringAsFixed(2)}'
                          : '****',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  final PeriodStats stats;
  final bool amountVisible;

  const _PeriodSummaryCard({required this.stats, required this.amountVisible});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SummaryColumn(
              label: '总收入',
              value: stats.totalIncome,
              amountVisible: amountVisible,
              color: Colors.green,
            ),
            _SummaryColumn(
              label: '总支出',
              value: stats.totalExpense,
              amountVisible: amountVisible,
              color: Colors.red,
            ),
            _SummaryColumn(
              label: '净流入',
              value: stats.totalNet,
              amountVisible: amountVisible,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final double value;
  final bool amountVisible;
  final Color? color;

  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.amountVisible,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          amountVisible ? '¥${value.toStringAsFixed(2)}' : '****',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final double value;
  final bool amountVisible;
  final bool highlight;

  const _SmallStat({
    required this.label,
    required this.value,
    required this.amountVisible,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      amountVisible
          ? '$label ¥${value.toStringAsFixed(2)}'
          : '$label ****',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: highlight
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: highlight ? FontWeight.w600 : null,
          ),
    );
  }
}
