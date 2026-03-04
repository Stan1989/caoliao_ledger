import '../database/app_database.dart';

/// Abstract interface for category operations.
abstract class CategoryRepository {
  /// Watch top-level categories by ledger and type.
  Stream<List<Category>> watchByLedgerAndType(int ledgerId, int type);

  /// Watch subcategories for a parent category.
  Stream<List<Category>> watchSubcategories(int parentId);

  /// Get all categories for a ledger.
  Future<List<Category>> getByLedger(int ledgerId);

  /// Get subcategories for a parent.
  Future<List<Category>> getSubcategories(int parentId);

  /// Get a category by ID.
  Future<Category?> getById(int id);

  /// Create a new category.
  Future<int> createCategory({
    required int ledgerId,
    required String name,
    required int type,
    String? icon,
    int? parentId,
    int sortOrder = 0,
  });

  /// Update a category.
  Future<void> updateCategory(Category category);

  /// Delete a category.
  Future<void> deleteCategory(int id);
}
