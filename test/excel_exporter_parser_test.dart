import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/features/import/models/import_row.dart';
import 'package:caoliao_ledger/features/import/services/excel_exporter.dart';
import 'package:caoliao_ledger/features/import/services/excel_parser.dart';

Transaction _txn({
  required int id,
  required int type,
  required DateTime date,
  required double amount,
  required int accountId,
  int? toAccountId,
  int? categoryId,
  String? note,
}) {
  return Transaction(
    id: id,
    ledgerId: 1,
    type: type,
    amount: amount,
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    memberId: null,
    projectId: null,
    merchant: null,
    note: note,
    transactionDate: date,
    createdAt: date,
    syncStatus: 0,
    remoteId: null,
    updatedAt: date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('export uses minute precision datetime and includes balance sheet', () async {
    final exporter = ExcelExporter();
    final at = DateTime(2026, 3, 17, 9, 7);

    final txns = <Transaction>[
      _txn(
        id: 1,
        type: TransactionType.expense.value,
        date: at,
        amount: 18.5,
        accountId: 1,
        categoryId: 11,
        note: '早餐',
      ),
      _txn(
        id: 2,
        type: TransactionType.balanceAdjustment.value,
        date: at,
        amount: 1000,
        accountId: 1,
        note: '对账',
      ),
    ];

    final result = await exporter.export(
      transactions: txns,
      accountNames: const {1: '现金'},
      categoryNames: const {11: '餐饮-早餐'},
      parentCategoryNames: const {11: '餐饮'},
      memberNames: const {},
      projectNames: const {},
      ledgerName: '测试账本',
    );

    final bytes = await File(result.filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    expect(excel.tables.containsKey(SheetType.expense.sheetName), isTrue);
    expect(excel.tables.containsKey(SheetType.balanceAdjustment.sheetName), isTrue);

    final expenseSheet = excel.tables[SheetType.expense.sheetName]!;
    final dateCell = expenseSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
        .value;
    expect(dateCell.toString(), '2026-03-17 09:07');

    expect(result.rowCount, 2);
  });

  test('parser preserves minute precision and balance-adjustment sheet type', () {
    final excel = Excel.createExcel();
    final sheet = excel[SheetType.balanceAdjustment.sheetName];

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = TextCellValue('交易类型');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        .value = TextCellValue('日期');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
        .value = TextCellValue('账户1');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0))
        .value = TextCellValue('金额');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 0))
        .value = TextCellValue('备注');

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = TextCellValue('余额变更');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
        .value = TextCellValue('2026-03-17 09:07');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1))
        .value = TextCellValue('现金');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1))
        .value = DoubleCellValue(1000);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 1))
        .value = TextCellValue('对账');

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    expect(bytes, isNotNull);

    final parser = ExcelParser();
    final parsed = parser.parse(bytes!);

    expect(parsed.rows.length, 1);
    final row = parsed.rows.first;
    expect(row.sheetType, SheetType.balanceAdjustment);
    expect(row.date.year, 2026);
    expect(row.date.month, 3);
    expect(row.date.day, 17);
    expect(row.date.hour, 9);
    expect(row.date.minute, 7);
    expect(row.account1, '现金');
    expect(row.amount, 1000);
    expect(row.note, '对账');
  });
}
