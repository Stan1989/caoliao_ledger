import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/members.dart';

part 'member_dao.g.dart';

@DriftAccessor(tables: [Members])
class MemberDao extends DatabaseAccessor<AppDatabase> with _$MemberDaoMixin {
  MemberDao(super.db);

  /// Watch members for a ledger.
  Stream<List<Member>> watchByLedger(int ledgerId) =>
      (select(members)..where((t) => t.ledgerId.equals(ledgerId))).watch();

  /// Get all members for a ledger.
  Future<List<Member>> getByLedger(int ledgerId) =>
      (select(members)..where((t) => t.ledgerId.equals(ledgerId))).get();

  /// Get a member by ID.
  Future<Member?> getById(int id) =>
      (select(members)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get a member by ledger ID and name.
  Future<Member?> getByName(int ledgerId, String name) =>
      (select(members)
            ..where(
              (t) => t.ledgerId.equals(ledgerId) & t.name.equals(name),
            ))
          .getSingleOrNull();

  /// Create a new member.
  Future<int> createMember(MembersCompanion entry) =>
      into(members).insert(entry);

  /// Update a member.
  Future<bool> updateMember(Member entry) => update(members).replace(entry);

  /// Delete all members for a ledger.
  Future<int> deleteByLedger(int ledgerId) =>
      (delete(members)..where((t) => t.ledgerId.equals(ledgerId))).go();

  /// Delete a member.
  Future<int> deleteMember(int id) =>
      (delete(members)..where((t) => t.id.equals(id))).go();
}
