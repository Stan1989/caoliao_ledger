import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../models/import_row.dart';
import 'excel_constants.dart';

/// Export result returned by [ExcelExporter.export].
class ExcelExportResult {
  const ExcelExportResult({required this.filePath, required this.rowCount});
  final String filePath;
  final int rowCount;
}

/// Exports transactions to an .xlsx file in 钱迹 format.
///
/// The exported file uses the same sheet names, column order, and data format
/// as the import module ([ExcelParser]), so exported files can be re-imported.
class ExcelExporter {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Export [transactions] to an .xlsx file.
  ///
  /// Requires lookup maps for resolving foreign-key IDs to display names:
  /// - [accountNames]: accountId → account name
  /// - [categoryNames]: categoryId → category name
  /// - [parentCategoryNames]: categoryId → parent category name (for sub-categories)
  /// - [memberNames]: memberId → member name
  /// - [projectNames]: projectId → project name
  /// - [ledgerName]: the name of the ledger (used in filename)
  /// - [currency]: the ledger currency (default 'CNY')
  Future<ExcelExportResult> export({
    required List<Transaction> transactions,
    required Map<int, String> accountNames,
    required Map<int, String> categoryNames,
    required Map<int, String> parentCategoryNames,
    required Map<int, String> memberNames,
    required Map<int, String> projectNames,
    required String ledgerName,
    String currency = 'CNY',
  }) async {
    final excel = Excel.createExcel();

    // Group transactions by type
    final expenses = <Transaction>[];
    final incomes = <Transaction>[];
    final transfers = <Transaction>[];
    final adjustments = <Transaction>[];

    for (final t in transactions) {
      switch (TransactionType.fromValue(t.type)) {
        case TransactionType.expense:
          expenses.add(t);
        case TransactionType.income:
          incomes.add(t);
        case TransactionType.transfer:
          transfers.add(t);
        case TransactionType.balanceAdjustment:
          adjustments.add(t);
      }
    }

    // Create sheets (always create all three to match import format)
    _fillSheet(
      excel,
      SheetType.expense.sheetName,
      expenses,
      SheetType.expense,
      accountNames: accountNames,
      categoryNames: categoryNames,
      parentCategoryNames: parentCategoryNames,
      memberNames: memberNames,
      projectNames: projectNames,
      currency: currency,
    );
    _fillSheet(
      excel,
      SheetType.income.sheetName,
      incomes,
      SheetType.income,
      accountNames: accountNames,
      categoryNames: categoryNames,
      parentCategoryNames: parentCategoryNames,
      memberNames: memberNames,
      projectNames: projectNames,
      currency: currency,
    );
    _fillSheet(
      excel,
      SheetType.transfer.sheetName,
      transfers,
      SheetType.transfer,
      accountNames: accountNames,
      categoryNames: categoryNames,
      parentCategoryNames: parentCategoryNames,
      memberNames: memberNames,
      projectNames: projectNames,
      currency: currency,
    );
    _fillSheet(
      excel,
      SheetType.balanceAdjustment.sheetName,
      adjustments,
      SheetType.balanceAdjustment,
      accountNames: accountNames,
      categoryNames: categoryNames,
      parentCategoryNames: parentCategoryNames,
      memberNames: memberNames,
      projectNames: projectNames,
      currency: currency,
    );

    // Remove default "Sheet1" if it exists and is empty
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save to file
    final dir = await getTemporaryDirectory();
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = '草料记账_${ledgerName}_$now.xlsx';
    final filePath = '${dir.path}/$fileName';

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    await File(filePath).writeAsBytes(bytes);

    final rowCount =
      expenses.length + incomes.length + transfers.length + adjustments.length;
    return ExcelExportResult(filePath: filePath, rowCount: rowCount);
  }

  void _fillSheet(
    Excel excel,
    String sheetName,
    List<Transaction> transactions,
    SheetType sheetType, {
    required Map<int, String> accountNames,
    required Map<int, String> categoryNames,
    required Map<int, String> parentCategoryNames,
    required Map<int, String> memberNames,
    required Map<int, String> projectNames,
    required String currency,
  }) {
    final sheet = excel[sheetName];

    // Write header row
    for (var col = 0; col < ExcelConstants.columnHeaders.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(ExcelConstants.columnHeaders[col]);
    }

    // Write data rows
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final rowIndex = i + 1; // skip header

      // Type label
      final typeLabel = sheetType.sheetName;

      // Category / subcategory resolution
      String categoryName = '';
      String? subcategoryName;
      if (t.categoryId != null) {
        final catName = categoryNames[t.categoryId!];
        final parentName = parentCategoryNames[t.categoryId!];
        if (parentName != null) {
          // This is a subcategory
          categoryName = parentName;
          subcategoryName = catName;
        } else {
          categoryName = catName ?? '';
        }
      }

      // Account names
      final account1 = accountNames[t.accountId] ?? '';
      final account2 =
          t.toAccountId != null ? accountNames[t.toAccountId!] : null;

      // Member name
      final memberName =
          t.memberId != null ? memberNames[t.memberId!] : null;

      // Project name
      final projectName =
          t.projectId != null ? projectNames[t.projectId!] : null;

      final cells = <int, CellValue>{
        ExcelConstants.colType: TextCellValue(typeLabel),
        ExcelConstants.colDate:
            TextCellValue(_dateFormat.format(t.transactionDate)),
        ExcelConstants.colCategory: TextCellValue(categoryName),
        ExcelConstants.colAccount1: TextCellValue(account1),
        ExcelConstants.colCurrency: TextCellValue(currency),
        ExcelConstants.colAmount: DoubleCellValue(t.amount),
      };

      if (subcategoryName != null) {
        cells[ExcelConstants.colSubcategory] =
            TextCellValue(subcategoryName);
      }
      if (account2 != null) {
        cells[ExcelConstants.colAccount2] = TextCellValue(account2);
      }
      if (memberName != null) {
        cells[ExcelConstants.colMember] = TextCellValue(memberName);
      }
      if (t.merchant != null && t.merchant!.isNotEmpty) {
        cells[ExcelConstants.colMerchant] = TextCellValue(t.merchant!);
      }
      if (projectName != null) {
        cells[ExcelConstants.colProject] = TextCellValue(projectName);
      }
      if (t.note != null && t.note!.isNotEmpty) {
        cells[ExcelConstants.colNote] = TextCellValue(t.note!);
      }

      for (final entry in cells.entries) {
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: entry.key, rowIndex: rowIndex))
            .value = entry.value;
      }
    }
  }
}
