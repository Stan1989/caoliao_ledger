import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'account_repository.dart';

/// Drift-backed implementation of [AccountRepository].
class DriftAccountRepository implements AccountRepository {
  final AppDatabase _db;

  DriftAccountRepository(this._db);

  @override
  Stream<List<Account>> watchByLedger(int ledgerId) =>
      _db.accountDao.watchByLedger(ledgerId);

  @override
  Stream<List<Account>> watchNonArchived(int ledgerId) =>
      _db.accountDao.watchNonArchived(ledgerId);

  @override
  Future<List<Account>> getByLedger(int ledgerId) =>
      _db.accountDao.getByLedger(ledgerId);

  @override
  Future<Account?> getById(int id) => _db.accountDao.getById(id);

  @override
  Future<int> createAccount({
    required int ledgerId,
    required String name,
    required int type,
    String? cardLastFour,
    double balance = 0.0,
    String? icon,
    int sortOrder = 0,
  }) {
    return _db.accountDao.createAccount(
      AccountsCompanion.insert(
        ledgerId: ledgerId,
        name: name,
        type: type,
        cardLastFour: Value(cardLastFour),
        balance: Value(balance),
        icon: Value(icon),
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateAccount(Account account) async {
    await _db.accountDao.updateAccount(account);
  }

  @override
  Future<void> adjustBalance(int accountId, double delta) async {
    await _db.accountDao.adjustBalance(accountId, delta);
  }

  @override
  Future<void> toggleArchive(int accountId, bool isArchived) async {
    final account = await _db.accountDao.getById(accountId);
    if (account != null) {
      await _db.accountDao.updateAccount(
        account.copyWith(
          isArchived: isArchived,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> deleteAccount(int id) async {
    await _db.accountDao.deleteAccount(id);
  }
}
