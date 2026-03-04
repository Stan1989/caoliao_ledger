/// Represents a single parsed row from the Excel import file.
class ImportRow {
  const ImportRow({
    required this.sheetType,
    required this.date,
    required this.category,
    this.subcategory,
    required this.account1,
    this.account2,
    this.currency,
    required this.amount,
    this.member,
    this.merchant,
    this.projectCategory,
    this.project,
    this.recorder,
    this.note,
  });

  /// The sheet this row came from (determines transaction type).
  final SheetType sheetType;
  final DateTime date;
  final String category;
  final String? subcategory;
  final String account1;
  final String? account2;
  final String? currency;
  final double amount;
  final String? member;
  final String? merchant;
  final String? projectCategory;
  final String? project;
  final String? recorder;
  final String? note;
}

/// Maps Excel sheet names to import types.
enum SheetType {
  expense('支出'),
  income('收入'),
  transfer('转账'),
  balanceAdjustment('余额变更'),
  receivableAdjustment('债权变更'),
  liabilityAdjustment('负债变更');

  const SheetType(this.sheetName);
  final String sheetName;

  static SheetType? fromSheetName(String name) {
    for (final type in SheetType.values) {
      if (type.sheetName == name) return type;
    }
    return null;
  }

  /// Whether this sheet type represents a balance adjustment.
  bool get isAdjustment =>
      this == balanceAdjustment ||
      this == receivableAdjustment ||
      this == liabilityAdjustment;
}

/// Parsed result from the Excel file.
class ImportData {
  const ImportData({required this.rows});

  final List<ImportRow> rows;

  List<ImportRow> get expenses =>
      rows.where((r) => r.sheetType == SheetType.expense).toList();
  List<ImportRow> get incomes =>
      rows.where((r) => r.sheetType == SheetType.income).toList();
  List<ImportRow> get transfers =>
      rows.where((r) => r.sheetType == SheetType.transfer).toList();
  List<ImportRow> get adjustments =>
      rows.where((r) => r.sheetType.isAdjustment).toList();

  int get totalCount => rows.length;
}
