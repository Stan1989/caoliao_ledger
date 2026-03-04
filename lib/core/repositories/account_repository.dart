import '../database/app_database.dart';

/// Abstract interface for account operations.
abstract class AccountRepository {
  /// Watch all accounts for a ledger.
  Stream<List<Account>> watchByLedger(int ledgerId);

  /// Watch non-archived accounts for a ledger.
  Stream<List<Account>> watchNonArchived(int ledgerId);

  /// Get all accounts for a ledger.
  Future<List<Account>> getByLedger(int ledgerId);

  /// Get a single account by ID.
  Future<Account?> getById(int id);

  /// Create a new account.
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    required int type,
    String? cardLastFour,
    double balance = 0.0,
    String? icon,
    int sortOrder = 0,
  });

  /// Update an account.
  Future<void> updateAccount(Account account);

  /// Adjust account balance by a delta.
  Future<void> adjustBalance(int accountId, double delta);

  /// Toggle archive status of an account.
  Future<void> toggleArchive(int accountId, bool isArchived);

  /// Delete an account.
  Future<void> deleteAccount(int id);
}
