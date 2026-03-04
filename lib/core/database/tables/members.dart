import 'package:drift/drift.dart';

import 'ledgers.dart';

/// Members table — people within a ledger.
@TableIndex(name: 'idx_members_ledger', columns: {#ledgerId})
class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get name => text()();
  IntColumn get role => integer()(); // MemberRole enum value: admin=0, member=1
  TextColumn get avatar => text().nullable()();
  // Cloud sync reservation
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
