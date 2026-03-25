import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/amount_visibility_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../app/theme.dart';
import '../providers/flow_filter_provider.dart';
import 'flow_filter_sheet.dart';

/// Notifier for current displayed month.
class _CurrentMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime month) => state = month;
}

/// Current displayed month for the transaction flow page.
final _currentMonthProvider = NotifierProvider<_CurrentMonthNotifier, DateTime>(
  _CurrentMonthNotifier.new,
);

final _allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const [];
  return ref.watch(categoryRepositoryProvider).getByLedger(ledgerId);
});

bool matchesAccountFilter(Transaction transaction, Set<int> accountIds) {
  if (accountIds.isEmpty) return true;
  return accountIds.contains(transaction.accountId) ||
      (transaction.toAccountId != null &&
          accountIds.contains(transaction.toAccountId));
}

String buildFlowItemTitle(
  Transaction transaction,
  Map<int, String> categoryNames,
  Set<int> subcategoryIds,
) {
  final txnType = TransactionType.fromValue(transaction.type);
  final normalizedNote = (transaction.note ?? '').trim();

  switch (txnType) {
    case TransactionType.transfer:
      return normalizedNote.isNotEmpty ? normalizedNote : '转账';
    case TransactionType.expense:
      if (normalizedNote.isNotEmpty) return normalizedNote;
      final categoryName = transaction.categoryId != null &&
              subcategoryIds.contains(transaction.categoryId!)
          ? categoryNames[transaction.categoryId!]
          : null;
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        return categoryName;
      }
      return '支出';
    case TransactionType.income:
      if (normalizedNote.isNotEmpty) return normalizedNote;
      final categoryName = transaction.categoryId != null &&
              subcategoryIds.contains(transaction.categoryId!)
          ? categoryNames[transaction.categoryId!]
          : null;
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        return categoryName;
      }
      return '收入';
    case TransactionType.balanceAdjustment:
      return normalizedNote.isNotEmpty ? normalizedNote : '余额变更';
  }
}

/// Transaction flow page — monthly list with filters.
class FlowPage extends ConsumerStatefulWidget {
  final int? accountId;
  final String? accountName;

  const FlowPage({super.key, this.accountId, this.accountName});

  @override
  ConsumerState<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends ConsumerState<FlowPage> {
  /// Local filter state used when pushed from asset page (accountId != null).
  FlowFilterState _localFilter = const FlowFilterState();

  bool get _isPushedMode => widget.accountId != null;

  FlowFilterState get _currentFilter =>
      _isPushedMode ? _localFilter : ref.watch(flowFilterProvider);

  @override
  void initState() {
    super.initState();
    if (_isPushedMode) {
      _localFilter = FlowFilterState(accountIds: {widget.accountId!});
    }
  }

  void _updateFilter(FlowFilterState filter) {
    if (_isPushedMode) {
      setState(() => _localFilter = filter);
    } else {
      ref.read(flowFilterProvider.notifier).setFilter(filter);
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showFlowFilterSheet(
      context,
      current: _currentFilter,
      ref: ref,
    );
    if (result != null) {
      _updateFilter(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledgerId = ref.watch(activeLedgerIdProvider);
    if (ledgerId == null) {
      return const Scaffold(body: Center(child: Text('请先选择账本')));
    }

    final currentMonth = ref.watch(_currentMonthProvider);
    final amountVisible = ref.watch(amountVisibilityProvider);
    final filter = _currentFilter;
    final filterActive = filter.isActive;
    final hasDateOverride = filter.hasDateOverride;

    // Determine query date range
    final DateTime start;
    final DateTime end;
    if (filter.dateRange != null) {
      start = filter.dateRange!.start;
      end = filter.dateRange!.end.add(const Duration(days: 1));
    } else if (filter.minAmount != null) {
      // Min-amount filter queries all time
      start = DateTime(2000);
      end = DateTime(2100);
    } else {
      // No date override — use current month (even with dimension filters)
      start = currentMonth;
      end = DateTime(currentMonth.year, currentMonth.month + 1);
    }

    final txnStream = ref
        .watch(transactionRepositoryProvider)
        .watchByLedger(ledgerId, startDate: start, endDate: end);

    // Pre-load account and member name maps
    final accountsAsync = ref.watch(allAccountsProvider);
    final membersAsync = ref.watch(membersProvider);
    final categoriesAsync = ref.watch(_allCategoriesProvider);
    final accountNames = <int, String>{};
    final memberNames = <int, String>{};
    final categoryNames = <int, String>{};
    final subcategoryIds = <int>{};
    accountsAsync.whenData((list) {
      for (final a in list) {
        accountNames[a.id] = a.name;
      }
    });
    membersAsync.whenData((list) {
      for (final m in list) {
        memberNames[m.id] = m.name;
      }
    });
    categoriesAsync.whenData((list) {
      for (final c in list) {
        categoryNames[c.id] = c.name;
        if (c.parentId != null) {
          subcategoryIds.add(c.id);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPushedMode ? (widget.accountName ?? '账户流水') : '流水'),
        actions: [
          // Filter button
          IconButton(
            icon: Badge(
              isLabelVisible: filterActive,
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: '筛选',
            onPressed: _openFilterSheet,
          ),
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
          // Month navigation (hidden only when date override is active)
          if (!hasDateOverride)
            _MonthNavigator(
              current: currentMonth,
              onPrevious: () {
                ref
                    .read(_currentMonthProvider.notifier)
                    .set(DateTime(currentMonth.year, currentMonth.month - 1));
              },
              onNext: () {
                final next = DateTime(
                  currentMonth.year,
                  currentMonth.month + 1,
                );
                if (!next.isAfter(DateTime.now())) {
                  ref.read(_currentMonthProvider.notifier).set(next);
                }
              },
            ),
          // Filter active indicator
          if (filterActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _buildFilterDescription(filter),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _updateFilter(
                      _isPushedMode
                          ? FlowFilterState(accountIds: {widget.accountId!})
                          : const FlowFilterState(),
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          // Transaction list
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: txnStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('加载失败：${snapshot.error}'));
                }

                var transactions = snapshot.data ?? [];

                // Dart-side filtering for multi-select dimensions
                if (filter.accountIds.isNotEmpty) {
                  transactions = transactions
                      .where((t) => matchesAccountFilter(t, filter.accountIds))
                      .toList();
                }
                if (filter.memberIds.isNotEmpty) {
                  transactions = transactions.where((t) {
                    return t.memberId != null &&
                        filter.memberIds.contains(t.memberId);
                  }).toList();
                }
                if (filter.projectIds.isNotEmpty) {
                  transactions = transactions.where((t) {
                    return t.projectId != null &&
                        filter.projectIds.contains(t.projectId);
                  }).toList();
                }
                if (filter.transactionTypes.isNotEmpty) {
                  transactions = transactions.where((t) {
                    return matchesFlowFilterTransactionType(filter, t.type);
                  }).toList();
                }
                if (filter.minAmount != null) {
                  transactions = transactions.where((t) {
                    return t.amount.abs() > filter.minAmount!;
                  }).toList();
                }

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filterActive ? '没有符合筛选条件的记录' : '暂无记录',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                // Compute monthly totals
                double totalExpense = 0;
                double totalIncome = 0;
                for (final t in transactions) {
                  if (t.type == TransactionType.expense.value) {
                    totalExpense += t.amount;
                  } else if (t.type == TransactionType.income.value) {
                    totalIncome += t.amount;
                  }
                }

                // Group by day
                final grouped = <String, List<Transaction>>{};
                for (final t in transactions) {
                  final key = DateFormat(
                    'yyyy-MM-dd',
                  ).format(t.transactionDate);
                  grouped.putIfAbsent(key, () => []).add(t);
                }
                final sortedDays = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return Column(
                  children: [
                    // Monthly summary
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MiniStat(
                            '支出',
                            totalExpense,
                            AppTheme.expenseColor,
                            amountVisible: amountVisible,
                          ),
                          _MiniStat(
                            '收入',
                            totalIncome,
                            AppTheme.incomeColor,
                            amountVisible: amountVisible,
                          ),
                          _MiniStat(
                            '结余',
                            totalIncome - totalExpense,
                            Theme.of(context).colorScheme.onSurface,
                            amountVisible: amountVisible,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Day-grouped list
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedDays.length,
                        itemBuilder: (context, index) {
                          final day = sortedDays[index];
                          final dayTxns = grouped[day]!;
                          return _DayGroup(
                            day: day,
                            transactions: dayTxns,
                            amountVisible: amountVisible,
                            accountNames: accountNames,
                            memberNames: memberNames,
                            categoryNames: categoryNames,
                            subcategoryIds: subcategoryIds,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildFilterDescription(FlowFilterState filter) {
    final parts = <String>[];
    if (filter.dateRange != null) {
      final fmt = DateFormat('yyyy-MM-dd');
      parts.add(
        '${fmt.format(filter.dateRange!.start)} ~ ${fmt.format(filter.dateRange!.end)}',
      );
    }
    if (filter.accountIds.isNotEmpty) {
      parts.add('${filter.accountIds.length}个账户');
    }
    if (filter.memberIds.isNotEmpty) {
      parts.add('${filter.memberIds.length}个成员');
    }
    if (filter.projectIds.isNotEmpty) {
      parts.add('${filter.projectIds.length}个项目');
    }
    parts.add('类型: ${flowFilterTypeSummary(filter.transactionTypes)}');
    if (filter.minAmount != null) {
      parts.add('>¥${filter.minAmount!.toInt()}');
    }
    return parts.isEmpty ? '已筛选' : parts.join(' · ');
  }
}

class _MonthNavigator extends StatelessWidget {
  final DateTime current;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthNavigator({
    required this.current,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(
            '${current.year}年${current.month}月',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool amountVisible;

  const _MiniStat(
    this.label,
    this.amount,
    this.color, {
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          amountVisible ? '¥${AppTheme.formatDisplayAmount(amount)}' : '****',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DayGroup extends StatelessWidget {
  final String day;
  final List<Transaction> transactions;
  final bool amountVisible;
  final Map<int, String> accountNames;
  final Map<int, String> memberNames;
  final Map<int, String> categoryNames;
  final Set<int> subcategoryIds;

  const _DayGroup({
    required this.day,
    required this.transactions,
    required this.amountVisible,
    required this.accountNames,
    required this.memberNames,
    required this.categoryNames,
    required this.subcategoryIds,
  });

  @override
  Widget build(BuildContext context) {
    double dayExpense = 0;
    double dayIncome = 0;
    for (final t in transactions) {
      final type = TransactionType.fromValue(t.type);
      if (type == TransactionType.expense) {
        dayExpense += t.amount;
      } else if (type == TransactionType.income) {
        dayIncome += t.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _DayGroupStat(
                label: '支',
                amount: dayExpense,
                color: AppTheme.expenseColor,
                amountVisible: amountVisible,
              ),
              const SizedBox(width: 8),
              _DayGroupStat(
                label: '收',
                amount: dayIncome,
                color: AppTheme.incomeColor,
                amountVisible: amountVisible,
              ),
            ],
          ),
        ),
        ...transactions.map(
          (t) => _TransactionItem(
            transaction: t,
            amountVisible: amountVisible,
            accountNames: accountNames,
            memberNames: memberNames,
            categoryNames: categoryNames,
            subcategoryIds: subcategoryIds,
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _DayGroupStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool amountVisible;

  const _DayGroupStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.amountVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          amountVisible ? AppTheme.formatDisplayAmountCompact(amount) : '****',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final bool amountVisible;
  final Map<int, String> accountNames;
  final Map<int, String> memberNames;
  final Map<int, String> categoryNames;
  final Set<int> subcategoryIds;

  const _TransactionItem({
    required this.transaction,
    required this.amountVisible,
    required this.accountNames,
    required this.memberNames,
    required this.categoryNames,
    required this.subcategoryIds,
  });

  @override
  Widget build(BuildContext context) {
    final txnType = TransactionType.fromValue(transaction.type);
    final color = AppTheme.amountColor(transaction.type);
    final amountText = AppTheme.formatAmount(
      transaction.amount,
      transaction.type,
    );
    final title = buildFlowItemTitle(
      transaction,
      categoryNames,
      subcategoryIds,
    );

    IconData icon;
    switch (txnType) {
      case TransactionType.expense:
        icon = Icons.remove_circle_outline;
      case TransactionType.income:
        icon = Icons.add_circle_outline;
      case TransactionType.transfer:
        icon = Icons.swap_horiz;
      case TransactionType.balanceAdjustment:
        icon = Icons.tune;
    }

    final time = DateFormat('HH:mm').format(transaction.transactionDate);

    // Build subtitle: time · account(→toAccount) · member
    final parts = <String>[time];
    if (txnType == TransactionType.transfer) {
      final from = accountNames[transaction.accountId] ?? '';
      final to = transaction.toAccountId != null
          ? accountNames[transaction.toAccountId!] ?? ''
          : '';
      if (from.isNotEmpty || to.isNotEmpty) {
        parts.add('$from→$to');
      }
    } else {
      final acctName = accountNames[transaction.accountId];
      if (acctName != null) parts.add(acctName);
    }
    if (transaction.memberId != null) {
      final memberName = memberNames[transaction.memberId!];
      if (memberName != null) parts.add(memberName);
    }
    final subtitle = parts.join(' · ');

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(
        amountVisible ? amountText : '****',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: () => context.push('/record/${transaction.id}'),
    );
  }
}
