import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/projects.dart';
import '../../models/enums.dart';

part 'project_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase> with _$ProjectDaoMixin {
  ProjectDao(super.db);

  /// Watch all projects for a ledger.
  Stream<List<Project>> watchByLedger(int ledgerId) =>
      (select(projects)..where((t) => t.ledgerId.equals(ledgerId))).watch();

  /// Watch non-archived projects for a ledger.
  Stream<List<Project>> watchNonArchived(int ledgerId) =>
      (select(projects)
            ..where(
              (t) =>
                  t.ledgerId.equals(ledgerId) &
                  t.isArchived.equals(false),
            ))
          .watch();

    /// Watch cumulative expense totals by project for a ledger.
    Stream<Map<int, double>> watchExpenseTotalsByLedger(int ledgerId) {
        return customSelect(
            '''
            SELECT p.id AS project_id, COALESCE(SUM(t.amount), 0) AS total_amount
            FROM projects p
            LEFT JOIN transactions t
                ON t.project_id = p.id
             AND t.ledger_id = ?
             AND t.type = ?
            WHERE p.ledger_id = ?
            GROUP BY p.id
            ''',
            variables: [
                Variable.withInt(ledgerId),
                Variable.withInt(TransactionType.expense.value),
                Variable.withInt(ledgerId),
            ],
            readsFrom: {projects, attachedDatabase.transactions},
        ).watch().map((rows) {
            return {
                for (final row in rows)
                    row.read<int>('project_id'): row.read<double>('total_amount'),
            };
        });
    }

  /// Get a project by ID.
  Future<Project?> getById(int id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get a project by ledger ID and name.
  Future<Project?> getByName(int ledgerId, String name) =>
      (select(projects)
            ..where(
              (t) => t.ledgerId.equals(ledgerId) & t.name.equals(name),
            ))
          .getSingleOrNull();

  /// Create a new project.
  Future<int> createProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  /// Update a project.
  Future<bool> updateProject(Project entry) =>
      update(projects).replace(entry);

  /// Delete a project.
  Future<int> deleteProject(int id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  /// Delete all projects for a ledger.
  Future<int> deleteByLedger(int ledgerId) =>
      (delete(projects)..where((t) => t.ledgerId.equals(ledgerId))).go();
}
