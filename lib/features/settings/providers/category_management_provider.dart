import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

/// State for the category management page.
class CategoryManagementState {
  final int selectedType; // 0 = expense, 1 = income
  final Set<int> expandedIds; // IDs of expanded first-level categories
  final bool isReordering;

  const CategoryManagementState({
    this.selectedType = 0,
    this.expandedIds = const {},
    this.isReordering = false,
  });

  CategoryManagementState copyWith({
    int? selectedType,
    Set<int>? expandedIds,
    bool? isReordering,
  }) {
    return CategoryManagementState(
      selectedType: selectedType ?? this.selectedType,
      expandedIds: expandedIds ?? this.expandedIds,
      isReordering: isReordering ?? this.isReordering,
    );
  }
}

class CategoryManagementNotifier extends Notifier<CategoryManagementState> {
  @override
  CategoryManagementState build() => const CategoryManagementState();

  AppDatabase get _db => ref.read(appDatabaseProvider);

  void setType(int type) {
    state = state.copyWith(selectedType: type, expandedIds: {});
  }

  void toggleExpand(int categoryId) {
    final ids = Set<int>.from(state.expandedIds);
    if (ids.contains(categoryId)) {
      ids.remove(categoryId);
    } else {
      ids.add(categoryId);
    }
    state = state.copyWith(expandedIds: ids);
  }

  void collapseAll() {
    state = state.copyWith(expandedIds: {});
  }

  /// Add a first-level category.
  Future<void> addCategory({
    required int ledgerId,
    required String name,
    String? icon,
  }) async {
    // Get current max sortOrder for this type
    final existing = await _db.categoryDao.getByLedger(ledgerId);
    final sameTypePrimary = existing
        .where((c) => c.type == state.selectedType && c.parentId == null)
        .toList();
    final maxSort = sameTypePrimary.isEmpty
        ? 0
        : sameTypePrimary
            .map((c) => c.sortOrder)
            .reduce((a, b) => a > b ? a : b);

    await _db.categoryDao.createCategory(CategoriesCompanion(
      ledgerId: Value(ledgerId),
      name: Value(name),
      icon: Value(icon),
      type: Value(state.selectedType),
      parentId: const Value.absent(),
      sortOrder: Value(maxSort + 1),
    ));
  }

  /// Add a subcategory under a parent.
  Future<void> addSubcategory({
    required int ledgerId,
    required int parentId,
    required String name,
  }) async {
    final existing = await _db.categoryDao.getSubcategories(parentId);
    final maxSort = existing.isEmpty
        ? 0
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);

    await _db.categoryDao.createCategory(CategoriesCompanion(
      ledgerId: Value(ledgerId),
      name: Value(name),
      type: Value(state.selectedType),
      parentId: Value(parentId),
      sortOrder: Value(maxSort + 1),
    ));
  }

  /// Update category name.
  Future<void> updateCategoryName(Category category, String newName) async {
    final updated = category.copyWith(name: newName);
    await _db.categoryDao.updateCategory(updated);
  }

  /// Reorder first-level categories.
  Future<void> reorderPrimaryCategories(
      List<Category> categories, int oldIndex, int newIndex) async {
    final list = List<Category>.from(categories);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final updated = <Category>[];
    for (var i = 0; i < list.length; i++) {
      updated.add(list[i].copyWith(sortOrder: i));
    }
    await _db.categoryDao.updateSortOrders(updated);
  }

  /// Reorder subcategories within a parent.
  Future<void> reorderSubcategories(
      List<Category> subcategories, int oldIndex, int newIndex) async {
    final list = List<Category>.from(subcategories);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final updated = <Category>[];
    for (var i = 0; i < list.length; i++) {
      updated.add(list[i].copyWith(sortOrder: i));
    }
    await _db.categoryDao.updateSortOrders(updated);
  }

  /// Check if a category can be deleted (no transactions linked).
  /// Returns the transaction count. 0 means safe to delete.
  Future<int> canDeleteCategory(int categoryId) async {
    return _db.transactionDao.countByCategory(categoryId);
  }

  /// Check if a first-level category can be deleted
  /// (no transactions on it or any of its children).
  Future<int> canDeletePrimaryCategory(int categoryId) async {
    var total = await _db.transactionDao.countByCategory(categoryId);
    final children = await _db.categoryDao.getSubcategories(categoryId);
    for (final child in children) {
      total += await _db.transactionDao.countByCategory(child.id);
    }
    return total;
  }

  /// Delete a category (simple, no children).
  Future<void> deleteCategory(int id) async {
    await _db.categoryDao.deleteCategory(id);
  }

  /// Delete a first-level category and all its children.
  Future<void> deletePrimaryCategoryWithChildren(int id) async {
    await _db.categoryDao.deleteCategoryWithChildren(id);
    // Remove from expanded set if present
    final ids = Set<int>.from(state.expandedIds)..remove(id);
    state = state.copyWith(expandedIds: ids);
  }
}

final categoryManagementProvider =
    NotifierProvider<CategoryManagementNotifier, CategoryManagementState>(
  CategoryManagementNotifier.new,
);
