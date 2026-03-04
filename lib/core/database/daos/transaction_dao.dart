import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transactions.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// Watch transactions for a ledger within an optional date range,
  /// ordered by transaction_date descending.
  Stream<List<Transaction>> watchByLedger(
    int ledgerId, {
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    int? memberId,
    int? projectId,
  }) {
    final query = select(transactions)
      ..where((t) {
        Expression<bool> condition = t.ledgerId.equals(ledgerId);
        if (startDate != null) {
          condition = condition &
              t.transactionDate
                  .isBiggerOrEqualValue(startDate);
        }
        if (endDate != null) {
          condition = condition &
              t.transactionDate.isSmallerOrEqualValue(endDate);
        }
        if (categoryId != null) {
          condition = condition & t.categoryId.equals(categoryId);
        }
        if (accountId != null) {
          condition = condition &
              (t.accountId.equals(accountId) |
                  t.toAccountId.equals(accountId));
        }
        if (memberId != null) {
          condition = condition & t.memberId.equals(memberId);
        }
        if (projectId != null) {
          condition = condition & t.projectId.equals(projectId);
        }
        return condition;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]);
    return query.watch();
  }

  /// Get transactions for monthly aggregation.
  Future<List<Transaction>> getByLedgerAndMonth(
    int ledgerId,
    int year,
    int month,
  ) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (select(transactions)
          ..where(
            (t) =>
                t.ledgerId.equals(ledgerId) &
                t.transactionDate.isBiggerOrEqualValue(start) &
                t.transactionDate.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  /// Get transactions for a ledger within a date range.
  Future<List<Transaction>> getByLedgerAndDateRange(
    int ledgerId,
    DateTime start,
    DateTime end,
  ) {
    return (select(transactions)
          ..where(
            (t) =>
                t.ledgerId.equals(ledgerId) &
                t.transactionDate.isBiggerOrEqualValue(start) &
                t.transactionDate.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  /// Delete all transactions for a ledger.
  Future<int> deleteByLedger(int ledgerId) =>
      (delete(transactions)..where((t) => t.ledgerId.equals(ledgerId))).go();

  /// Watch transactions for a specific account (as source or destination).
  Stream<List<Transaction>> watchByAccount(int accountId) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.accountId.equals(accountId) |
                  t.toAccountId.equals(accountId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
          .watch();

  /// Get a single transaction by ID.
  Future<Transaction?> getById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Create a new transaction and return its ID.
  Future<int> createTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  /// Update a transaction.
  Future<bool> updateTransaction(Transaction entry) =>
      update(transactions).replace(entry);

  /// Delete a transaction by ID.
  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Count transactions linked to a specific category.
  Future<int> countByCategory(int categoryId) async {
    final countExpr = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([countExpr])
      ..where(transactions.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Find a duplicate transaction by 5-tuple: date, amount, accountId, categoryId.
  Future<Transaction?> findDuplicate(
    int ledgerId,
    DateTime date,
    double amount,
    int accountId,
    int? categoryId,
  ) {
    final query = select(transactions)
      ..where((t) {
        Expression<bool> condition = t.ledgerId.equals(ledgerId) &
            t.transactionDate.equals(date) &
            t.amount.equals(amount) &
            t.accountId.equals(accountId);
        if (categoryId != null) {
          condition = condition & t.categoryId.equals(categoryId);
        } else {
          condition = condition & t.categoryId.isNull();
        }
        return condition;
      });
    return query.getSingleOrNull();
  }
}
