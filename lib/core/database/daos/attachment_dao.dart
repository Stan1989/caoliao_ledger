import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/attachments.dart';

part 'attachment_dao.g.dart';

@DriftAccessor(tables: [Attachments])
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.db);

  /// Watch attachments for a transaction.
  Stream<List<Attachment>> watchByTransaction(int transactionId) =>
      (select(attachments)
            ..where((t) => t.transactionId.equals(transactionId)))
          .watch();

  /// Get attachments for a transaction.
  Future<List<Attachment>> getByTransaction(int transactionId) =>
      (select(attachments)
            ..where((t) => t.transactionId.equals(transactionId)))
          .get();

  /// Create a new attachment.
  Future<int> createAttachment(AttachmentsCompanion entry) =>
      into(attachments).insert(entry);

  /// Delete an attachment.
  Future<int> deleteAttachment(int id) =>
      (delete(attachments)..where((t) => t.id.equals(id))).go();

  /// Delete all attachments for a transaction.
  Future<int> deleteByTransaction(int transactionId) =>
      (delete(attachments)
            ..where((t) => t.transactionId.equals(transactionId)))
          .go();
}
