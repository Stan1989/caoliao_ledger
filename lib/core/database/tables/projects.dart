import 'package:drift/drift.dart';

import 'ledgers.dart';

/// Projects table — project tags for categorizing transactions.
@TableIndex(name: 'idx_projects_ledger', columns: {#ledgerId})
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get name => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  // Cloud sync reservation
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
