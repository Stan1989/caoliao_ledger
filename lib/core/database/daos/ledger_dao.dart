import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ledgers.dart';

part 'ledger_dao.g.dart';

@DriftAccessor(tables: [Ledgers])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  /// Watch all ledgers.
  Stream<List<Ledger>> watchAll() => select(ledgers).watch();

  /// Get all ledgers.
  Future<List<Ledger>> getAll() => select(ledgers).get();

  /// Get a single ledger by ID.
  Future<Ledger?> getById(int id) =>
      (select(ledgers)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Create a new ledger and return its ID.
  Future<int> createLedger(LedgersCompanion entry) =>
      into(ledgers).insert(entry);

  /// Update a ledger.
  Future<bool> updateLedger(Ledger entry) => update(ledgers).replace(entry);

  /// Delete a ledger by ID.
  Future<int> deleteLedger(int id) =>
      (delete(ledgers)..where((t) => t.id.equals(id))).go();
}
