// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_dao.dart';

// ignore_for_file: type=lint
mixin _$AttachmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $LedgersTable get ledgers => attachedDatabase.ledgers;
  $CategoriesTable get categories => attachedDatabase.categories;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $MembersTable get members => attachedDatabase.members;
  $ProjectsTable get projects => attachedDatabase.projects;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $AttachmentsTable get attachments => attachedDatabase.attachments;
  AttachmentDaoManager get managers => AttachmentDaoManager(this);
}

class AttachmentDaoManager {
  final _$AttachmentDaoMixin _db;
  AttachmentDaoManager(this._db);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db.attachedDatabase, _db.ledgers);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db.attachedDatabase, _db.members);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db.attachedDatabase, _db.attachments);
}
