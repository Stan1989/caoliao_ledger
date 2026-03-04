import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart' as xml;

import '../models/import_row.dart';

/// Parses an xlsx file's bytes into structured [ImportData].
class ExcelParser {
  /// Parse Excel bytes into [ImportData].
  ///
  /// Reads all recognized sheets (支出, 收入, 转账, 余额变更, 债权变更, 负债变更)
  /// and maps each data row (skipping header) to an [ImportRow].
  ImportData parse(List<int> bytes) {
    // Preprocess: strip built-in numFmt entries (ID < 164) from styles.xml
    // to work around excel package bug that rejects them.
    final fixedBytes = _fixNumFmtIds(bytes);
    final excel = Excel.decodeBytes(fixedBytes);
    final rows = <ImportRow>[];

    for (final sheetName in excel.tables.keys) {
      final sheetType = SheetType.fromSheetName(sheetName);
      if (sheetType == null) continue; // skip unrecognized sheets

      final sheet = excel.tables[sheetName]!;
      if (sheet.maxRows <= 1) continue; // skip empty or header-only sheets

      // Skip row 0 (header). Parse rows 1..maxRows-1.
      for (var i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        final parsed = _parseRow(row, sheetType);
        if (parsed != null) rows.add(parsed);
      }
    }

    return ImportData(rows: rows);
  }

  /// Fix xlsx bytes by removing built-in numFmt entries (ID < 164) from
  /// xl/styles.xml. The `excel` package v4.0.6 throws on these.
  List<int> _fixNumFmtIds(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final stylesFile = archive.findFile('xl/styles.xml');
      if (stylesFile == null) return bytes;

      final rawBytes = stylesFile.content as List<int>;
      final stylesContent = utf8.decode(rawBytes);
      final doc = xml.XmlDocument.parse(stylesContent);

      var modified = false;
      for (final numFmts in doc.findAllElements('numFmts')) {
        final toRemove = <xml.XmlElement>[];
        for (final numFmt in numFmts.findElements('numFmt')) {
          final idStr = numFmt.getAttribute('numFmtId');
          if (idStr != null) {
            final id = int.tryParse(idStr);
            if (id != null && id < 164) {
              toRemove.add(numFmt);
            }
          }
        }
        for (final el in toRemove) {
          el.parent?.children.remove(el);
          modified = true;
        }
        // Update count attribute.
        if (modified) {
          final remaining = numFmts.findElements('numFmt').length;
          numFmts.setAttribute('count', remaining.toString());
        }
      }

      if (!modified) return bytes;

      // Re-encode the archive with the fixed styles.xml.
      final fixedContent = doc.toXmlString();
      final fixedUtf8 = utf8.encode(fixedContent);
      final newArchive = Archive();
      for (final file in archive) {
        if (file.name == 'xl/styles.xml') {
          final data = Uint8List.fromList(fixedUtf8);
          newArchive.addFile(ArchiveFile(file.name, data.length, data));
        } else {
          newArchive.addFile(file);
        }
      }
      return ZipEncoder().encode(newArchive)!;
    } catch (_) {
      // If preprocessing fails, return original bytes and let the parser
      // handle the error naturally.
      return bytes;
    }
  }

  ImportRow? _parseRow(List<Data?> row, SheetType sheetType) {
    // Column mapping (0-indexed):
    // 0: 交易类型  1: 日期  2: 分类  3: 子分类  4: 账户1
    // 5: 账户2  6: 账户币种  7: 金额  8: 成员  9: 商家
    // 10: 项目分类  11: 项目  12: 记账人  13: 备注

    final dateValue = _cellValue(row, 1);
    final amountValue = _cellValue(row, 7);
    final account1 = _cellValue(row, 4);
    final category = _cellValue(row, 2);

    // Skip rows with missing essential fields.
    if (dateValue == null || amountValue == null || account1 == null) {
      return null;
    }

    final date = _parseDate(row, 1);
    final amount = _parseAmount(row, 7);
    if (date == null || amount == null) return null;

    return ImportRow(
      sheetType: sheetType,
      date: date,
      category: category ?? '',
      subcategory: _cellValue(row, 3),
      account1: account1,
      account2: _cellValue(row, 5),
      currency: _cellValue(row, 6),
      amount: amount,
      member: _cellValue(row, 8),
      merchant: _cellValue(row, 9),
      projectCategory: _cellValue(row, 10),
      project: _cellValue(row, 11),
      recorder: _cellValue(row, 12),
      note: _cellValue(row, 13),
    );
  }

  /// Extract cell text value, trimmed. Returns null if empty.
  String? _cellValue(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null) return null;
    final value = cell.value;
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Parse a date from a cell. Handles Excel date values and text dates.
  DateTime? _parseDate(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null) return null;
    final value = cell.value;
    if (value == null) return null;

    // The excel package may return DateCellValue or a string.
    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    // Try parsing as string (e.g. "2024-01-15" or "2024/01/15").
    final text = value.toString().trim();
    if (text.isEmpty) return null;

    // Try standard formats.
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    // Try "yyyy/MM/dd" format.
    final parts = text.split('/');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }

    return null;
  }

  /// Parse an amount value. Handles numeric cells and text with commas.
  double? _parseAmount(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null) return null;
    final value = cell.value;
    if (value == null) return null;

    if (value is DoubleCellValue) {
      return value.value;
    }
    if (value is IntCellValue) {
      return value.value.toDouble();
    }

    // Strip commas from text values (e.g., "1,911.72" → "1911.72").
    final text = value.toString().trim().replaceAll(',', '');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
