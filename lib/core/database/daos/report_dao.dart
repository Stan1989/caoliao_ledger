import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transactions.dart';
import '../tables/categories.dart';
import '../tables/accounts.dart';
import '../tables/projects.dart';

part 'report_dao.g.dart';

/// Summary item for a single dimension value (category, account, or project).
class ReportSummaryItem {
  final int? id;
  final String name;
  final double amount;

  ReportSummaryItem({
    required this.id,
    required this.name,
    required this.amount,
  });
}

/// Trend data point for time-series chart.
class TrendDataPoint {
  final DateTime date;
  final double amount;

  TrendDataPoint({required this.date, required this.amount});
}

@DriftAccessor(tables: [Transactions, Categories, Accounts, Projects])
class ReportDao extends DatabaseAccessor<AppDatabase> with _$ReportDaoMixin {
  ReportDao(super.db);

  /// Get sum of amounts grouped by category for a ledger, transaction type,
  /// and date range.
  Future<List<ReportSummaryItem>> getSummaryByCategory(
    int ledgerId,
    int type, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = select(transactions).join([
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..where(transactions.ledgerId.equals(ledgerId) &
          transactions.type.equals(type) &
          transactions.transactionDate.isBiggerOrEqualValue(startDate) &
          transactions.transactionDate.isSmallerThanValue(endDate))
      ..groupBy([categories.id])
      ..addColumns([transactions.amount.sum()]);

    final rows = await query.get();
    return rows.map((row) {
      final cat = row.readTableOrNull(categories);
      return ReportSummaryItem(
        id: cat?.id,
        name: cat?.name ?? '未分类',
        amount: row.read(transactions.amount.sum()) ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Get sum of amounts grouped by account.
  Future<List<ReportSummaryItem>> getSummaryByAccount(
    int ledgerId,
    int type, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = select(transactions).join([
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ])
      ..where(transactions.ledgerId.equals(ledgerId) &
          transactions.type.equals(type) &
          transactions.transactionDate.isBiggerOrEqualValue(startDate) &
          transactions.transactionDate.isSmallerThanValue(endDate))
      ..groupBy([accounts.id])
      ..addColumns([transactions.amount.sum()]);

    final rows = await query.get();
    return rows.map((row) {
      final acc = row.readTable(accounts);
      return ReportSummaryItem(
        id: acc.id,
        name: acc.name,
        amount: row.read(transactions.amount.sum()) ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Get sum of amounts grouped by project.
  Future<List<ReportSummaryItem>> getSummaryByProject(
    int ledgerId,
    int type, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = select(transactions).join([
      leftOuterJoin(projects, projects.id.equalsExp(transactions.projectId)),
    ])
      ..where(transactions.ledgerId.equals(ledgerId) &
          transactions.type.equals(type) &
          transactions.transactionDate.isBiggerOrEqualValue(startDate) &
          transactions.transactionDate.isSmallerThanValue(endDate))
      ..groupBy([projects.id])
      ..addColumns([transactions.amount.sum()]);

    final rows = await query.get();
    return rows.map((row) {
      final proj = row.readTableOrNull(projects);
      return ReportSummaryItem(
        id: proj?.id,
        name: proj?.name ?? '无项目',
        amount: row.read(transactions.amount.sum()) ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Get daily trend data for a given date range.
  Future<List<TrendDataPoint>> getDailyTrend(
    int ledgerId,
    int type, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final dateExpr = transactions.transactionDate.date;
    final query = selectOnly(transactions)
      ..where(transactions.ledgerId.equals(ledgerId) &
          transactions.type.equals(type) &
          transactions.transactionDate.isBiggerOrEqualValue(startDate) &
          transactions.transactionDate.isSmallerThanValue(endDate))
      ..addColumns([dateExpr, transactions.amount.sum()])
      ..groupBy([dateExpr])
      ..orderBy([OrderingTerm.asc(dateExpr)]);

    final rows = await query.get();
    return rows.map((row) {
      final dateStr = row.read(dateExpr)!;
      return TrendDataPoint(
        date: DateTime.parse(dateStr),
        amount: row.read(transactions.amount.sum()) ?? 0,
      );
    }).toList();
  }

  /// Get monthly trend data for a given date range.
  Future<List<TrendDataPoint>> getMonthlyTrend(
    int ledgerId,
    int type, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Use strftime to extract year-month
    final monthExpr = transactions.transactionDate.strftime('%Y-%m');
    final query = selectOnly(transactions)
      ..where(transactions.ledgerId.equals(ledgerId) &
          transactions.type.equals(type) &
          transactions.transactionDate.isBiggerOrEqualValue(startDate) &
          transactions.transactionDate.isSmallerThanValue(endDate))
      ..addColumns([monthExpr, transactions.amount.sum()])
      ..groupBy([monthExpr])
      ..orderBy([OrderingTerm.asc(monthExpr)]);

    final rows = await query.get();
    return rows.map((row) {
      final monthStr = row.read(monthExpr)!;
      return TrendDataPoint(
        date: DateTime.parse('$monthStr-01'),
        amount: row.read(transactions.amount.sum()) ?? 0,
      );
    }).toList();
  }

  /// Get total amounts for expense and income in a date range.
  Future<({double expense, double income})> getTotals(
    int ledgerId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = selectOnly(transactions)
      ..where(transactions.ledgerId.equals(ledgerId) &
          transactions.transactionDate.isBiggerOrEqualValue(startDate) &
          transactions.transactionDate.isSmallerThanValue(endDate))
      ..addColumns([transactions.type, transactions.amount.sum()])
      ..groupBy([transactions.type]);

    final rows = await query.get();
    double expense = 0;
    double income = 0;
    for (final row in rows) {
      final type = row.read(transactions.type)!;
      final amount = row.read(transactions.amount.sum()) ?? 0;
      if (type == 0) expense = amount;
      if (type == 1) income = amount;
    }
    return (expense: expense, income: income);
  }
}
