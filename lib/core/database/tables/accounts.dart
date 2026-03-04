import 'package:drift/drift.dart';

import 'ledgers.dart';

/// Accounts table — bank accounts, cash, credit cards, wallets.
@TableIndex(name: 'idx_accounts_ledger', columns: {#ledgerId, #sortOrder})
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get name => text()();
  IntColumn get type => integer()(); // AccountType enum value
  TextColumn get cardLastFour => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  // Cloud sync reservation
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

