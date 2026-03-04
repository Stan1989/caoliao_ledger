import 'package:drift/drift.dart';

import 'ledgers.dart';

/// Categories table — expense/income categories with parent-child hierarchy.
@TableIndex(name: 'idx_categories_ledger_type', columns: {#ledgerId, #type})
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get type => integer()(); // CategoryType enum value: expense=0, income=1
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  // Cloud sync reservation
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
