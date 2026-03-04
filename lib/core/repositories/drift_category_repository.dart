import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'category_repository.dart';

/// Drift-backed implementation of [CategoryRepository].
class DriftCategoryRepository implements CategoryRepository {
  final AppDatabase _db;

  DriftCategoryRepository(this._db);

  @override
  Stream<List<Category>> watchByLedgerAndType(int ledgerId, int type) =>
      _db.categoryDao.watchByLedgerAndType(ledgerId, type);

  @override
  Stream<List<Category>> watchSubcategories(int parentId) =>
      _db.categoryDao.watchSubcategories(parentId);

  @override
  Future<List<Category>> getByLedger(int ledgerId) =>
      _db.categoryDao.getByLedger(ledgerId);

  @override
  Future<List<Category>> getSubcategories(int parentId) =>
      _db.categoryDao.getSubcategories(parentId);

  @override
  Future<Category?> getById(int id) => _db.categoryDao.getById(id);

  @override
  Future<int> createCategory({
    required int ledgerId,
    required String name,
    required int type,
    String? icon,
    int? parentId,
    int sortOrder = 0,
  }) {
    return _db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        ledgerId: ledgerId,
        name: name,
        type: type,
        icon: Value(icon),
        parentId: Value(parentId),
        sortOrder: Value(sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _db.categoryDao.updateCategory(category);
  }

  @override
  Future<void> deleteCategory(int id) async {
    await _db.categoryDao.deleteCategory(id);
  }
}
