import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Watch categories by ledger and type (expense or income).
  Stream<List<Category>> watchByLedgerAndType(int ledgerId, int type) =>
      (select(categories)
            ..where(
              (t) =>
                  t.ledgerId.equals(ledgerId) &
                  t.type.equals(type) &
                  t.parentId.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// Watch subcategories for a parent category.
  Stream<List<Category>> watchSubcategories(int parentId) =>
      (select(categories)
            ..where((t) => t.parentId.equals(parentId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// Get all categories for a ledger.
  Future<List<Category>> getByLedger(int ledgerId) =>
      (select(categories)..where((t) => t.ledgerId.equals(ledgerId))).get();

  /// Get subcategories for a parent.
  Future<List<Category>> getSubcategories(int parentId) =>
      (select(categories)..where((t) => t.parentId.equals(parentId))).get();

  /// Get a single category by ID.
  Future<Category?> getById(int id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get a top-level category by ledger, name, and type.
  Future<Category?> getByNameAndType(int ledgerId, String name, int type) =>
      (select(categories)
            ..where(
              (t) =>
                  t.ledgerId.equals(ledgerId) &
                  t.name.equals(name) &
                  t.type.equals(type) &
                  t.parentId.isNull(),
            ))
          .getSingleOrNull();

  /// Get a subcategory by name and parent ID.
  Future<Category?> getByNameAndParent(String name, int parentId) =>
      (select(categories)
            ..where(
              (t) => t.name.equals(name) & t.parentId.equals(parentId),
            ))
          .getSingleOrNull();

  /// Create a new category and return its ID.
  Future<int> createCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  /// Batch insert categories.
  Future<void> insertAll(List<CategoriesCompanion> entries) async {
    await batch((b) => b.insertAll(categories, entries));
  }

  /// Update a category.
  Future<bool> updateCategory(Category entry) =>
      update(categories).replace(entry);

  /// Delete a category.
  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  /// Batch update sortOrder for multiple categories.
  Future<void> updateSortOrders(List<Category> items) async {
    await batch((b) {
      for (final item in items) {
        b.replace(categories, item);
      }
    });
  }

  /// Delete a category and all its subcategories.
  Future<void> deleteCategoryWithChildren(int id) async {
    await (delete(categories)..where((t) => t.parentId.equals(id))).go();
    await (delete(categories)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all categories for a ledger.
  Future<int> deleteByLedger(int ledgerId) =>
      (delete(categories)..where((t) => t.ledgerId.equals(ledgerId))).go();
}
