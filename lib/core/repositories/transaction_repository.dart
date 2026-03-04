import '../database/app_database.dart';

/// Abstract interface for transaction operations.
abstract class TransactionRepository {
  /// Watch transactions for a ledger with optional filters.
  Stream<List<Transaction>> watchByLedger(
    int ledgerId, {
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    int? memberId,
    int? projectId,
  });

  /// Get transactions for a specific month.
  Future<List<Transaction>> getByLedgerAndMonth(
    int ledgerId,
    int year,
    int month,
  );

  /// Get transactions for a ledger within a date range.
  Future<List<Transaction>> getByLedgerAndDateRange(
    int ledgerId,
    DateTime start,
    DateTime end,
  );

  /// Watch transactions for a specific account.
  Stream<List<Transaction>> watchByAccount(int accountId);

  /// Get a transaction by ID.
  Future<Transaction?> getById(int id);

  /// Create a new transaction with balance updates.
  /// Returns the new transaction's ID.
  Future<int> createTransaction({
    required int ledgerId,
    required int type,
    required double amount,
    int? categoryId,
    required int accountId,
    int? toAccountId,
    int? memberId,
    int? projectId,
    String? merchant,
    String? note,
    required DateTime transactionDate,
  });

  /// Update a transaction with balance diff adjustments.
  Future<void> updateTransaction(Transaction transaction);

  /// Delete a transaction with balance reversal.
  Future<void> deleteTransaction(int id);
}
