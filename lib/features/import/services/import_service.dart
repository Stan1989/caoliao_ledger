import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../models/import_row.dart';

/// Result of an import operation.
class ImportResult {
  ImportResult({
    this.importedCount = 0,
    this.skippedDuplicates = 0,
    this.newAccounts = 0,
    this.newCategories = 0,
    this.newMembers = 0,
    this.newProjects = 0,
  });

  int importedCount;
  int skippedDuplicates;
  int newAccounts;
  int newCategories;
  int newMembers;
  int newProjects;
}

/// Progress callback: (processedCount, totalCount, phaseDescription).
typedef ImportProgressCallback = void Function(int processed, int total, String phase);

/// Orchestrates the three-phase import of Excel data into the database.
class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  /// Hardcoded account name → AccountType mapping.
  static const Map<String, AccountType> accountTypeMapping = {
    '广发银行9854': AccountType.creditCard,
    '中国工商银行5702': AccountType.bankCard,
    '微信钱包': AccountType.wallet,
    '支付宝余额': AccountType.wallet,
    '天天基金': AccountType.investment,
    '公司报销': AccountType.receivable,
    '公司垫付': AccountType.receivable,
    '房贷-公积金贷款': AccountType.liability,
    '房贷-商业贷款': AccountType.liability,
  };

  /// Extra accounts to create regardless of Excel contents.
  static const Map<String, AccountType> extraAccounts = {
    '公司垫付': AccountType.receivable,
  };

  /// Execute the full three-phase import.
  Future<ImportResult> import(
    int ledgerId,
    ImportData data, {
    ImportProgressCallback? onProgress,
    bool skipDuplicates = false,
  }) async {
    final result = ImportResult();
    final totalRows = data.totalCount;

    // ── Phase 0: Create Missing Entities ──
    onProgress?.call(0, totalRows, '正在创建关联实体...');
    final lookups = await _phase0CreateEntities(ledgerId, data, result);

    // ── Phase 1: Import all rows in chronological order ──
    // Merge all record types and sort by date asc.
    // For same date: adjustments use type priority
    // (liabilityAdjustment → receivableAdjustment → balanceAdjustment last).
    const adjustmentPriority = {
      SheetType.liabilityAdjustment: 0,
      SheetType.receivableAdjustment: 1,
      SheetType.balanceAdjustment: 2,
    };
    final allRows = [...data.rows]..sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      // Within same date, adjustments sort by type priority
      final pa = adjustmentPriority[a.sheetType] ?? 9;
      final pb = adjustmentPriority[b.sheetType] ?? 9;
      return pa.compareTo(pb);
    });

    onProgress?.call(0, totalRows, '正在导入数据...');
    var processed = 0;
    for (final row in allRows) {
      if (row.sheetType.isAdjustment) {
        await _importAdjustment(ledgerId, row, lookups);
        result.importedCount++;
      } else {
        if (skipDuplicates) {
          final isDuplicate = await _checkDuplicate(ledgerId, row, lookups);
          if (isDuplicate) {
            result.skippedDuplicates++;
            processed++;
            onProgress?.call(processed, totalRows, '正在导入数据...');
            continue;
          }
        }
        await _importTransaction(ledgerId, row, lookups);
        result.importedCount++;
      }
      processed++;
      onProgress?.call(processed, totalRows, '正在导入数据...');
    }

    return result;
  }

  // ━━━ Phase 0: Entity Creation ━━━

  Future<_EntityLookups> _phase0CreateEntities(
    int ledgerId,
    ImportData data,
    ImportResult result,
  ) async {
    // Collect unique names from all rows.
    final accountNames = <String>{};
    final categoryKeys = <_CategoryKey>{};
    final memberNames = <String>{};
    final projectNames = <String>{};

    for (final row in data.rows) {
      accountNames.add(row.account1);
      if (row.account2 != null && row.account2!.isNotEmpty) {
        accountNames.add(row.account2!);
      }
      if (row.category.isNotEmpty) {
        final catType = _categoryTypeForSheet(row.sheetType);
        categoryKeys.add(_CategoryKey(row.category, null, catType));
        if (row.subcategory != null && row.subcategory!.isNotEmpty) {
          categoryKeys.add(
            _CategoryKey(row.subcategory!, row.category, catType),
          );
        }
      }
      if (row.member != null && row.member!.isNotEmpty) {
        memberNames.add(row.member!);
      }
      if (row.project != null && row.project!.isNotEmpty) {
        projectNames.add(row.project!);
      }
    }

    // Add extra accounts.
    for (final name in extraAccounts.keys) {
      accountNames.add(name);
    }

    // Create missing accounts.
    final accountLookup = <String, int>{};
    final accountTypeLookup = <int, AccountType>{};
    for (final name in accountNames) {
      final existing = await _db.accountDao.getByName(ledgerId, name);
      if (existing != null) {
        accountLookup[name] = existing.id;
        accountTypeLookup[existing.id] = AccountType.fromValue(existing.type);
      } else {
        final type = accountTypeMapping[name] ?? AccountType.other;
        final id = await _db.accountDao.createAccount(AccountsCompanion(
          ledgerId: Value(ledgerId),
          name: Value(name),
          type: Value(type.value),
          balance: const Value(0.0),
        ));
        accountLookup[name] = id;
        accountTypeLookup[id] = type;
        result.newAccounts++;
      }
    }

    // Create missing members.
    final memberLookup = <String, int>{};
    for (final name in memberNames) {
      final existing = await _db.memberDao.getByName(ledgerId, name);
      if (existing != null) {
        memberLookup[name] = existing.id;
      } else {
        final role = name == 'StanZhao'
            ? MemberRole.admin.value
            : MemberRole.member.value;
        final id = await _db.memberDao.createMember(MembersCompanion(
          ledgerId: Value(ledgerId),
          name: Value(name),
          role: Value(role),
        ));
        memberLookup[name] = id;
        result.newMembers++;
      }
    }

    // Create missing projects.
    final projectLookup = <String, int>{};
    for (final name in projectNames) {
      final existing = await _db.projectDao.getByName(ledgerId, name);
      if (existing != null) {
        projectLookup[name] = existing.id;
      } else {
        final id = await _db.projectDao.createProject(ProjectsCompanion(
          ledgerId: Value(ledgerId),
          name: Value(name),
        ));
        projectLookup[name] = id;
        result.newProjects++;
      }
    }

    // Create missing categories (parents first, then children).
    final categoryLookup = <String, int>{}; // "type:parentName:name" → id
    // First pass: parent categories.
    for (final key in categoryKeys.where((k) => k.parentName == null)) {
      final catType = key.type;
      final existing = await _db.categoryDao.getByNameAndType(
        ledgerId,
        key.name,
        catType,
      );
      if (existing != null) {
        categoryLookup[_catLookupKey(catType, null, key.name)] = existing.id;
      } else {
        final id = await _db.categoryDao.createCategory(CategoriesCompanion(
          ledgerId: Value(ledgerId),
          name: Value(key.name),
          type: Value(catType),
        ));
        categoryLookup[_catLookupKey(catType, null, key.name)] = id;
        result.newCategories++;
      }
    }
    // Second pass: subcategories.
    for (final key in categoryKeys.where((k) => k.parentName != null)) {
      final catType = key.type;
      final parentId =
          categoryLookup[_catLookupKey(catType, null, key.parentName!)];
      if (parentId == null) continue; // parent should exist from first pass

      final existing = await _db.categoryDao.getByNameAndParent(
        key.name,
        parentId,
      );
      if (existing != null) {
        categoryLookup[_catLookupKey(catType, key.parentName, key.name)] =
            existing.id;
      } else {
        final id = await _db.categoryDao.createCategory(CategoriesCompanion(
          ledgerId: Value(ledgerId),
          name: Value(key.name),
          type: Value(catType),
          parentId: Value(parentId),
        ));
        categoryLookup[_catLookupKey(catType, key.parentName, key.name)] = id;
        result.newCategories++;
      }
    }

    return _EntityLookups(
      accounts: accountLookup,
      accountTypes: accountTypeLookup,
      categories: categoryLookup,
      members: memberLookup,
      projects: projectLookup,
    );
  }

  // ━━━ Phase 1: Balance Adjustments ━━━

  Future<void> _importAdjustment(
    int ledgerId,
    ImportRow row,
    _EntityLookups lookups,
  ) async {
    final accountId = lookups.accounts[row.account1];
    if (accountId == null) return;

    final categoryId = _resolveCategoryId(row, lookups);

    // Create a balanceAdjustment transaction.
    await _db.transactionDao.createTransaction(TransactionsCompanion(
      ledgerId: Value(ledgerId),
      type: Value(TransactionType.balanceAdjustment.value),
      amount: Value(row.amount),
      accountId: Value(accountId),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      memberId: _resolveOptionalId(row.member, lookups.members),
      projectId: _resolveOptionalId(row.project, lookups.projects),
      merchant: row.merchant != null
          ? Value(row.merchant!)
          : const Value.absent(),
      note: row.note != null ? Value(row.note!) : const Value.absent(),
      transactionDate: Value(row.date),
    ));

    // Set the account balance to this amount.
    await _db.accountDao.updateBalance(accountId, row.amount);
  }

  // ━━━ Phase 2: Regular Transactions ━━━

  Future<bool> _checkDuplicate(
    int ledgerId,
    ImportRow row,
    _EntityLookups lookups,
  ) async {
    final accountId = lookups.accounts[row.account1];
    if (accountId == null) return false;

    final categoryId = _resolveCategoryId(row, lookups);

    final existing = await _db.transactionDao.findDuplicate(
      ledgerId,
      row.date,
      row.amount,
      accountId,
      categoryId,
    );
    return existing != null;
  }

  Future<void> _importTransaction(
    int ledgerId,
    ImportRow row,
    _EntityLookups lookups,
  ) async {
    final accountId = lookups.accounts[row.account1];
    if (accountId == null) return;

    final transactionType = _transactionTypeForSheet(row.sheetType);
    final categoryId = _resolveCategoryId(row, lookups);
    final toAccountId = row.account2 != null
        ? lookups.accounts[row.account2!]
        : null;

    await _db.transactionDao.createTransaction(TransactionsCompanion(
      ledgerId: Value(ledgerId),
      type: Value(transactionType.value),
      amount: Value(row.amount),
      accountId: Value(accountId),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      toAccountId:
          toAccountId != null ? Value(toAccountId) : const Value.absent(),
      memberId: _resolveOptionalId(row.member, lookups.members),
      projectId: _resolveOptionalId(row.project, lookups.projects),
      merchant: row.merchant != null
          ? Value(row.merchant!)
          : const Value.absent(),
      note: row.note != null ? Value(row.note!) : const Value.absent(),
      transactionDate: Value(row.date),
    ));

    // Update account balances based on transaction type.
    // For liability accounts (creditCard, liability), balance semantics are
    // inverted: positive balance = debt owed, so signs flip.
    final isSourceLiability =
        lookups.accountTypes[accountId]?.isLiability ?? false;
    switch (transactionType) {
      case TransactionType.expense:
        // Normal: -amount (balance decreases). Liability: +amount (debt increases).
        await _db.accountDao.adjustBalance(
            accountId, isSourceLiability ? row.amount : -row.amount);
      case TransactionType.income:
        // Normal: +amount (balance increases). Liability: -amount (debt decreases).
        await _db.accountDao.adjustBalance(
            accountId, isSourceLiability ? -row.amount : row.amount);
      case TransactionType.transfer:
        await _db.accountDao.adjustBalance(
            accountId, isSourceLiability ? row.amount : -row.amount);
        if (toAccountId != null) {
          final isDestLiability =
              lookups.accountTypes[toAccountId]?.isLiability ?? false;
          await _db.accountDao.adjustBalance(
              toAccountId, isDestLiability ? -row.amount : row.amount);
        }
      case TransactionType.balanceAdjustment:
        break; // handled by _importAdjustment
    }
  }

  // ━━━ Helpers ━━━

  int? _resolveCategoryId(ImportRow row, _EntityLookups lookups) {
    if (row.category.isEmpty) return null;
    final catType = _categoryTypeForSheet(row.sheetType);

    // If subcategory exists, use it; otherwise use the parent category.
    if (row.subcategory != null && row.subcategory!.isNotEmpty) {
      return lookups
          .categories[_catLookupKey(catType, row.category, row.subcategory!)];
    }
    return lookups.categories[_catLookupKey(catType, null, row.category)];
  }

  Value<int?> _resolveOptionalId(String? name, Map<String, int> lookup) {
    if (name == null || name.isEmpty) return const Value.absent();
    final id = lookup[name];
    return id != null ? Value(id) : const Value.absent();
  }

  static int _categoryTypeForSheet(SheetType sheetType) {
    switch (sheetType) {
      case SheetType.income:
        return CategoryType.income.value; // 1
      case SheetType.expense:
      case SheetType.transfer:
      case SheetType.balanceAdjustment:
      case SheetType.receivableAdjustment:
      case SheetType.liabilityAdjustment:
        return CategoryType.expense.value; // 0
    }
  }

  static TransactionType _transactionTypeForSheet(SheetType sheetType) {
    switch (sheetType) {
      case SheetType.expense:
        return TransactionType.expense;
      case SheetType.income:
        return TransactionType.income;
      case SheetType.transfer:
        return TransactionType.transfer;
      case SheetType.balanceAdjustment:
      case SheetType.receivableAdjustment:
      case SheetType.liabilityAdjustment:
        return TransactionType.balanceAdjustment;
    }
  }

  static String _catLookupKey(int type, String? parentName, String name) =>
      '$type:${parentName ?? ''}:$name';
}

// ━━━ Internal Data Classes ━━━

class _EntityLookups {
  const _EntityLookups({
    required this.accounts,
    required this.accountTypes,
    required this.categories,
    required this.members,
    required this.projects,
  });

  final Map<String, int> accounts;
  final Map<int, AccountType> accountTypes; // accountId → AccountType
  final Map<String, int> categories; // key: "type:parentName:name"
  final Map<String, int> members;
  final Map<String, int> projects;
}

class _CategoryKey {
  const _CategoryKey(this.name, this.parentName, this.type);

  final String name;
  final String? parentName;
  final int type;

  @override
  bool operator ==(Object other) =>
      other is _CategoryKey &&
      name == other.name &&
      parentName == other.parentName &&
      type == other.type;

  @override
  int get hashCode => Object.hash(name, parentName, type);
}
