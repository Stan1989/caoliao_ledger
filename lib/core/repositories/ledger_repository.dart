import '../database/app_database.dart';

/// Abstract interface for ledger operations.
abstract class LedgerRepository {
  /// Watch all ledgers.
  Stream<List<Ledger>> watchAll();

  /// Get all ledgers.
  Future<List<Ledger>> getAll();

  /// Get a ledger by ID.
  Future<Ledger?> getById(int id);

  /// Create a new ledger with default categories seeded.
  /// Returns the new ledger's ID.
  Future<int> createLedger({
    required String name,
    String? icon,
    String currency = 'CNY',
  });

  /// Update a ledger.
  Future<void> updateLedger(Ledger ledger);

  /// Delete a ledger and all associated data.
  Future<void> deleteLedger(int id);
}
