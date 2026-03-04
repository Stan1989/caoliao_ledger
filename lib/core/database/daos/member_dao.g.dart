// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_dao.dart';

// ignore_for_file: type=lint
mixin _$MemberDaoMixin on DatabaseAccessor<AppDatabase> {
  $LedgersTable get ledgers => attachedDatabase.ledgers;
  $MembersTable get members => attachedDatabase.members;
  MemberDaoManager get managers => MemberDaoManager(this);
}

class MemberDaoManager {
  final _$MemberDaoMixin _db;
  MemberDaoManager(this._db);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db.attachedDatabase, _db.ledgers);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db.attachedDatabase, _db.members);
}
