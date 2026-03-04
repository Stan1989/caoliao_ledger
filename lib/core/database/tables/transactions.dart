import 'package:drift/drift.dart';

import 'ledgers.dart';
import 'categories.dart';
import 'accounts.dart';
import 'members.dart';
import 'projects.dart';

/// Transactions table — expense, income, and transfer records.
@TableIndex(
  name: 'idx_transactions_ledger_date',
  columns: {#ledgerId, #transactionDate},
)
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get type => integer()(); // TransactionType enum value
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId =>
      integer().nullable().references(Accounts, #id)(); // transfer only
  IntColumn get memberId => integer().nullable().references(Members, #id)();
  IntColumn get projectId => integer().nullable().references(Projects, #id)();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Cloud sync reservation
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
