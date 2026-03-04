import 'package:drift/drift.dart';

import 'transactions.dart';

/// Attachments table — files attached to transactions.
@TableIndex(name: 'idx_attachments_transaction', columns: {#transactionId})
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get filePath => text()();
  TextColumn get fileType => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Cloud sync reservation
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
