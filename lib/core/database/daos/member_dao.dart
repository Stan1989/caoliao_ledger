import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/members.dart';
import '../../models/enums.dart';

part 'member_dao.g.dart';

@DriftAccessor(tables: [Members])
class MemberDao extends DatabaseAccessor<AppDatabase> with _$MemberDaoMixin {
  MemberDao(super.db);

  /// Watch members for a ledger.
  Stream<List<Member>> watchByLedger(int ledgerId) =>
      (select(members)..where((t) => t.ledgerId.equals(ledgerId))).watch();

  /// Watch cumulative expense totals by member for a ledger.
  Stream<Map<int, double>> watchExpenseTotalsByLedger(int ledgerId) {
    return customSelect(
      '''
      SELECT m.id AS member_id, COALESCE(SUM(t.amount), 0) AS total_amount
      FROM members m
      LEFT JOIN transactions t
          ON t.member_id = m.id
       AND t.ledger_id = ?
       AND t.type = ?
      WHERE m.ledger_id = ?
      GROUP BY m.id
      ''',
      variables: [
        Variable.withInt(ledgerId),
        Variable.withInt(TransactionType.expense.value),
        Variable.withInt(ledgerId),
      ],
      readsFrom: {members, attachedDatabase.transactions},
    ).watch().map((rows) {
      return {
        for (final row in rows)
          row.read<int>('member_id'): row.read<double>('total_amount'),
      };
    });
  }

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
