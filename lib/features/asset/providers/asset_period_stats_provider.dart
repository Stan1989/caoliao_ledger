import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/providers/database_provider.dart';
import 'asset_filter_provider.dart';

/// Per-account flow stats for a period.
class AccountPeriodStats {
  final int accountId;
  final double income;
  final double expense;
  final double net;

  const AccountPeriodStats({
    required this.accountId,
    this.income = 0,
    this.expense = 0,
    this.net = 0,
  });
}

/// Aggregated period stats for all accounts.
class PeriodStats {
  final double totalIncome;
  final double totalExpense;
  final double totalNet;
  final Map<int, AccountPeriodStats> byAccount;

  const PeriodStats({
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.totalNet = 0,
    this.byAccount = const {},
  });
}

/// Provider that computes period stats based on filter state.
final assetPeriodStatsProvider = FutureProvider<PeriodStats?>((ref) async {
  final filter = ref.watch(assetFilterProvider);
  if (filter.mode == AssetFilterMode.all) return null;

  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return null;

  final repo = ref.watch(transactionRepositoryProvider);

  DateTime start;
  DateTime end;
  switch (filter.mode) {
    case AssetFilterMode.month:
      start = DateTime(filter.selectedDate.year, filter.selectedDate.month);
      end = DateTime(filter.selectedDate.year, filter.selectedDate.month + 1);
    case AssetFilterMode.year:
      start = DateTime(filter.selectedDate.year);
      end = DateTime(filter.selectedDate.year + 1);
    case AssetFilterMode.all:
      return null;
  }

  final transactions = await repo.getByLedgerAndDateRange(ledgerId, start, end);

  double totalIncome = 0;
  double totalExpense = 0;
  final accountMap = <int, _MutableStats>{};

  for (final t in transactions) {
    final txnType = TransactionType.fromValue(t.type);
    switch (txnType) {
      case TransactionType.income:
        totalIncome += t.amount;
        accountMap.putIfAbsent(t.accountId, _MutableStats.new).income += t.amount;
      case TransactionType.expense:
        totalExpense += t.amount;
        accountMap.putIfAbsent(t.accountId, _MutableStats.new).expense += t.amount;
      case TransactionType.transfer:
        // Source account: outflow
        accountMap.putIfAbsent(t.accountId, _MutableStats.new).expense += t.amount;
        // Destination account: inflow
        if (t.toAccountId != null) {
          accountMap.putIfAbsent(t.toAccountId!, _MutableStats.new).income += t.amount;
        }
      case TransactionType.balanceAdjustment:
        break;
    }
  }

  final byAccount = accountMap.map(
    (id, s) => MapEntry(
      id,
      AccountPeriodStats(
        accountId: id,
        income: s.income,
        expense: s.expense,
        net: s.income - s.expense,
      ),
    ),
  );

  return PeriodStats(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    totalNet: totalIncome - totalExpense,
    byAccount: byAccount,
  );
});

class _MutableStats {
  double income = 0;
  double expense = 0;
}
