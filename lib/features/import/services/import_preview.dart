import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../models/import_row.dart';
import '../services/import_service.dart';

/// Preview statistics for an import operation.
class ImportPreviewResult {
  const ImportPreviewResult({
    required this.expenseCount,
    required this.incomeCount,
    required this.transferCount,
    required this.adjustmentCount,
    required this.newAccounts,
    required this.newCategories,
    required this.newMembers,
    required this.newProjects,
    required this.duplicateCount,
  });

  final int expenseCount;
  final int incomeCount;
  final int transferCount;
  final int adjustmentCount;
  final List<String> newAccounts;
  final List<String> newCategories;
  final List<String> newMembers;
  final List<String> newProjects;
  final int duplicateCount;

  int get totalRows =>
      expenseCount + incomeCount + transferCount + adjustmentCount;
}

/// Analyzes parsed import data against the database to produce preview stats.
class ImportPreview {
  ImportPreview(this._db);

  final AppDatabase _db;

  /// Generate a preview of what the import would do.
  Future<ImportPreviewResult> analyze(int ledgerId, ImportData data) async {
    // Count rows per type.
    final expenseCount = data.expenses.length;
    final incomeCount = data.incomes.length;
    final transferCount = data.transfers.length;
    final adjustmentCount = data.adjustments.length;

    // Collect unique entity names.
    final accountNames = <String>{};
    final parentCategoryKeys = <String>{}; // "type:name"
    final subCategoryKeys = <String>{}; // "type:parent:name"
    final memberNames = <String>{};
    final projectNames = <String>{};

    for (final row in data.rows) {
      accountNames.add(row.account1);
      if (row.account2 != null && row.account2!.isNotEmpty) {
        accountNames.add(row.account2!);
      }
      if (row.category.isNotEmpty) {
        final catType = _categoryTypeForSheet(row.sheetType);
        parentCategoryKeys.add('$catType:${row.category}');
        if (row.subcategory != null && row.subcategory!.isNotEmpty) {
          subCategoryKeys
              .add('$catType:${row.category}:${row.subcategory!}');
        }
      }
      if (row.member != null && row.member!.isNotEmpty) {
        memberNames.add(row.member!);
      }
      if (row.project != null && row.project!.isNotEmpty) {
        projectNames.add(row.project!);
      }
    }
    // Extra accounts.
    for (final name in ImportService.extraAccounts.keys) {
      accountNames.add(name);
    }

    // Check which accounts are new.
    final newAccounts = <String>[];
    for (final name in accountNames) {
      final existing = await _db.accountDao.getByName(ledgerId, name);
      if (existing == null) newAccounts.add(name);
    }

    // Check which parent categories are new.
    final newCategories = <String>[];
    for (final key in parentCategoryKeys) {
      final parts = key.split(':');
      final type = int.parse(parts[0]);
      final name = parts[1];
      final existing =
          await _db.categoryDao.getByNameAndType(ledgerId, name, type);
      if (existing == null) newCategories.add(name);
    }
    // Check subcategories too (for display).
    for (final key in subCategoryKeys) {
      final parts = key.split(':');
      final type = int.parse(parts[0]);
      final parentName = parts[1];
      final name = parts[2];
      final parent = await _db.categoryDao.getByNameAndType(
        ledgerId,
        parentName,
        type,
      );
      if (parent != null) {
        final existing =
            await _db.categoryDao.getByNameAndParent(name, parent.id);
        if (existing == null) newCategories.add('$parentName > $name');
      } else {
        // Parent is also new, so subcategory is definitely new.
        newCategories.add('$parentName > $name');
      }
    }

    // Check which members are new.
    final newMembers = <String>[];
    for (final name in memberNames) {
      final existing = await _db.memberDao.getByName(ledgerId, name);
      if (existing == null) newMembers.add(name);
    }

    // Check which projects are new.
    final newProjects = <String>[];
    for (final name in projectNames) {
      final existing = await _db.projectDao.getByName(ledgerId, name);
      if (existing == null) newProjects.add(name);
    }

    // Estimate duplicates — check phase 2 rows only.
    var duplicateCount = 0;
    final phase2Rows = [...data.expenses, ...data.incomes, ...data.transfers];

    // Build temporary account lookup for dedup check.
    final accountLookup = <String, int>{};
    for (final name in accountNames) {
      final existing = await _db.accountDao.getByName(ledgerId, name);
      if (existing != null) accountLookup[name] = existing.id;
    }

    // Build category lookup for dedup check.
    final categoryLookup = <String, int>{};
    for (final key in parentCategoryKeys) {
      final parts = key.split(':');
      final type = int.parse(parts[0]);
      final name = parts[1];
      final existing =
          await _db.categoryDao.getByNameAndType(ledgerId, name, type);
      if (existing != null) categoryLookup['$type::$name'] = existing.id;
    }
    for (final key in subCategoryKeys) {
      final parts = key.split(':');
      final type = int.parse(parts[0]);
      final parentName = parts[1];
      final name = parts[2];
      final parent = await _db.categoryDao.getByNameAndType(
        ledgerId,
        parentName,
        type,
      );
      if (parent != null) {
        final existing =
            await _db.categoryDao.getByNameAndParent(name, parent.id);
        if (existing != null) {
          categoryLookup['$type:$parentName:$name'] = existing.id;
        }
      }
    }

    for (final row in phase2Rows) {
      final accountId = accountLookup[row.account1];
      if (accountId == null) continue; // new account → can't be duplicate

      final catType = _categoryTypeForSheet(row.sheetType);
      int? categoryId;
      if (row.category.isNotEmpty) {
        if (row.subcategory != null && row.subcategory!.isNotEmpty) {
          categoryId =
              categoryLookup['$catType:${row.category}:${row.subcategory!}'];
        } else {
          categoryId = categoryLookup['$catType::${row.category}'];
        }
      }

      final existing = await _db.transactionDao.findDuplicate(
        ledgerId,
        row.date,
        row.amount,
        accountId,
        categoryId,
      );
      if (existing != null) duplicateCount++;
    }

    return ImportPreviewResult(
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      transferCount: transferCount,
      adjustmentCount: adjustmentCount,
      newAccounts: newAccounts,
      newCategories: newCategories,
      newMembers: newMembers,
      newProjects: newProjects,
      duplicateCount: duplicateCount,
    );
  }

  static int _categoryTypeForSheet(SheetType sheetType) {
    switch (sheetType) {
      case SheetType.income:
        return CategoryType.income.value;
      case SheetType.expense:
      case SheetType.transfer:
      case SheetType.balanceAdjustment:
      case SheetType.receivableAdjustment:
      case SheetType.liabilityAdjustment:
        return CategoryType.expense.value;
    }
  }
}
