/// Shared constants for Excel import/export in 钱迹 format.
///
/// Column definitions and sheet names are shared between `ExcelParser` (import)
/// and `ExcelExporter` (export) to ensure format consistency.
class ExcelConstants {
  ExcelConstants._();

  // ---------------------------------------------------------------------------
  // Column headers (row 0)
  // ---------------------------------------------------------------------------
  static const List<String> columnHeaders = [
    '交易类型', // 0
    '日期', // 1
    '分类', // 2
    '子分类', // 3
    '账户1', // 4
    '账户2', // 5
    '账户币种', // 6
    '金额', // 7
    '成员', // 8
    '商家', // 9
    '项目分类', // 10
    '项目', // 11
    '记账人', // 12
    '备注', // 13
  ];

  // ---------------------------------------------------------------------------
  // Column indices
  // ---------------------------------------------------------------------------
  static const int colType = 0;
  static const int colDate = 1;
  static const int colCategory = 2;
  static const int colSubcategory = 3;
  static const int colAccount1 = 4;
  static const int colAccount2 = 5;
  static const int colCurrency = 6;
  static const int colAmount = 7;
  static const int colMember = 8;
  static const int colMerchant = 9;
  static const int colProjectCategory = 10;
  static const int colProject = 11;
  static const int colRecorder = 12;
  static const int colNote = 13;

  /// Total number of columns.
  static const int columnCount = 14;
}
