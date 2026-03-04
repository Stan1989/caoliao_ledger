import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// Watch all accounts for a ledger.
  Stream<List<Account>> watchByLedger(int ledgerId) =>
      (select(accounts)
            ..where((t) => t.ledgerId.equals(ledgerId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// Watch non-archived accounts for a ledger.
  Stream<List<Account>> watchNonArchived(int ledgerId) =>
      (select(accounts)
            ..where(
              (t) =>
                  t.ledgerId.equals(ledgerId) &
                  t.isArchived.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// Get all accounts for a ledger.
  Future<List<Account>> getByLedger(int ledgerId) =>
      (select(accounts)..where((t) => t.ledgerId.equals(ledgerId))).get();

  /// Get a single account by ID.
  Future<Account?> getById(int id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get an account by ledger ID and name.
  Future<Account?> getByName(int ledgerId, String name) =>
      (select(accounts)
            ..where(
              (t) => t.ledgerId.equals(ledgerId) & t.name.equals(name),
            ))
          .getSingleOrNull();

  /// Create a new account.
  Future<int> createAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  /// Update an account.
  Future<bool> updateAccount(Account entry) =>
      update(accounts).replace(entry);

  /// Update account balance.
  Future<void> updateBalance(int accountId, double newBalance) =>
      (update(accounts)..where((t) => t.id.equals(accountId))).write(
        AccountsCompanion(
          balance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Adjust balance by delta (positive or negative).
  Future<void> adjustBalance(int accountId, double delta) async {
    final account = await getById(accountId);
    if (account != null) {
      await updateBalance(accountId, account.balance + delta);
    }
  }

  /// Delete an account.
  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  /// Delete all accounts for a ledger.
  Future<int> deleteByLedger(int ledgerId) =>
      (delete(accounts)..where((t) => t.ledgerId.equals(ledgerId))).go();
}
