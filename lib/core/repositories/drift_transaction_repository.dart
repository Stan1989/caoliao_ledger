import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import 'transaction_repository.dart';

/// Drift-backed implementation of [TransactionRepository].
/// Handles balance updates on create/update/delete.
class DriftTransactionRepository implements TransactionRepository {
  final AppDatabase _db;

  DriftTransactionRepository(this._db);

  /// Adjusts account balance, inverting the delta for liability accounts.
  /// Liability accounts (creditCard, liability) store positive balance as debt,
  /// so transaction effects are reversed compared to normal accounts.
  Future<void> _adjustBalance(int accountId, double delta) async {
    final account = await _db.accountDao.getById(accountId);
    if (account == null) return;
    final isLiability = AccountType.fromValue(account.type).isLiability;
    await _db.accountDao.updateBalance(
      accountId,
      account.balance + (isLiability ? -delta : delta),
    );
  }

  @override
  Stream<List<Transaction>> watchByLedger(
    int ledgerId, {
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    int? memberId,
    int? projectId,
  }) {
    return _db.transactionDao.watchByLedger(
      ledgerId,
      startDate: startDate,
      endDate: endDate,
      categoryId: categoryId,
      accountId: accountId,
      memberId: memberId,
      projectId: projectId,
    );
  }

  @override
  Future<List<Transaction>> getByLedgerAndMonth(
    int ledgerId,
    int year,
    int month,
  ) {
    return _db.transactionDao.getByLedgerAndMonth(ledgerId, year, month);
  }

  @override
  Future<List<Transaction>> getByLedgerAndDateRange(
    int ledgerId,
    DateTime start,
    DateTime end,
  ) {
    return _db.transactionDao.getByLedgerAndDateRange(ledgerId, start, end);
  }

  @override
  Stream<List<Transaction>> watchByAccount(int accountId) =>
      _db.transactionDao.watchByAccount(accountId);

  @override
  Future<Transaction?> getById(int id) => _db.transactionDao.getById(id);

  @override
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
  }) async {
    final now = DateTime.now();
    final txnId = await _db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: Value(categoryId),
        accountId: accountId,
        toAccountId: Value(toAccountId),
        memberId: Value(memberId),
        projectId: Value(projectId),
        merchant: Value(merchant),
        note: Value(note),
        transactionDate: transactionDate,
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Update account balances
    final txnType = TransactionType.fromValue(type);
    switch (txnType) {
      case TransactionType.expense:
        await _adjustBalance(accountId, -amount);
      case TransactionType.income:
        await _adjustBalance(accountId, amount);
      case TransactionType.transfer:
        await _adjustBalance(accountId, -amount);
        if (toAccountId != null) {
          await _adjustBalance(toAccountId, amount);
        }
      case TransactionType.balanceAdjustment:
        break; // balance set directly, no adjustment
    }

    return txnId;
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    // Get old transaction to compute balance diff
    final oldTxn = await _db.transactionDao.getById(transaction.id);
    if (oldTxn == null) return;

    // Reverse old balances
    final oldType = TransactionType.fromValue(oldTxn.type);
    switch (oldType) {
      case TransactionType.expense:
        await _adjustBalance(oldTxn.accountId, oldTxn.amount);
      case TransactionType.income:
        await _adjustBalance(oldTxn.accountId, -oldTxn.amount);
      case TransactionType.transfer:
        await _adjustBalance(oldTxn.accountId, oldTxn.amount);
        if (oldTxn.toAccountId != null) {
          await _adjustBalance(oldTxn.toAccountId!, -oldTxn.amount);
        }
      case TransactionType.balanceAdjustment:
        break; // balance set directly, no adjustment
    }

    // Apply new transaction
    await _db.transactionDao.updateTransaction(transaction);

    // Apply new balances
    final newType = TransactionType.fromValue(transaction.type);
    switch (newType) {
      case TransactionType.expense:
        await _adjustBalance(transaction.accountId, -transaction.amount);
      case TransactionType.income:
        await _adjustBalance(transaction.accountId, transaction.amount);
      case TransactionType.transfer:
        await _adjustBalance(transaction.accountId, -transaction.amount);
        if (transaction.toAccountId != null) {
          await _adjustBalance(transaction.toAccountId!, transaction.amount);
        }
      case TransactionType.balanceAdjustment:
        break; // balance set directly, no adjustment
    }
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final txn = await _db.transactionDao.getById(id);
    if (txn == null) return;

    // Reverse balance
    final txnType = TransactionType.fromValue(txn.type);
    switch (txnType) {
      case TransactionType.expense:
        await _adjustBalance(txn.accountId, txn.amount);
      case TransactionType.income:
        await _adjustBalance(txn.accountId, -txn.amount);
      case TransactionType.transfer:
        await _adjustBalance(txn.accountId, txn.amount);
        if (txn.toAccountId != null) {
          await _adjustBalance(txn.toAccountId!, -txn.amount);
        }
      case TransactionType.balanceAdjustment:
        break; // balance set directly, no adjustment
    }

    // Delete attachments first, then transaction
    await _db.attachmentDao.deleteByTransaction(id);
    await _db.transactionDao.deleteTransaction(id);
  }
}
