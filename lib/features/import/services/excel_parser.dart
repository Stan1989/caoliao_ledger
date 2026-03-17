import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart' as xml;

import '../models/import_row.dart';
import 'excel_constants.dart';

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
    final dateValue = _cellValue(row, ExcelConstants.colDate);
    final amountValue = _cellValue(row, ExcelConstants.colAmount);
    final account1 = _cellValue(row, ExcelConstants.colAccount1);
    final category = _cellValue(row, ExcelConstants.colCategory);

    // Skip rows with missing essential fields.
    if (dateValue == null || amountValue == null || account1 == null) {
      return null;
    }

    final date = _parseDate(row, ExcelConstants.colDate);
    final amount = _parseAmount(row, ExcelConstants.colAmount);
    if (date == null || amount == null) return null;

    return ImportRow(
      sheetType: sheetType,
      date: date,
      category: category ?? '',
      subcategory: _cellValue(row, ExcelConstants.colSubcategory),
      account1: account1,
      account2: _cellValue(row, ExcelConstants.colAccount2),
      currency: _cellValue(row, ExcelConstants.colCurrency),
      amount: amount,
      member: _cellValue(row, ExcelConstants.colMember),
      merchant: _cellValue(row, ExcelConstants.colMerchant),
      projectCategory: _cellValue(row, ExcelConstants.colProjectCategory),
      project: _cellValue(row, ExcelConstants.colProject),
      recorder: _cellValue(row, ExcelConstants.colRecorder),
      note: _cellValue(row, ExcelConstants.colNote),
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
    if (value is DateTimeCellValue) {
      return value.asDateTimeLocal();
    }
    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    // Try parsing as string (e.g. "2024-01-15" or "2024/01/15").
    final text = value.toString().trim();
    if (text.isEmpty) return null;

    // Try standard formats.
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    // Try explicit minute precision format.
    final normalized = text.replaceAll('/', '-');
    final minuteParts = normalized.split(' ');
    if (minuteParts.length == 2) {
      final dateParts = minuteParts[0].split('-');
      final timeParts = minuteParts[1].split(':');
      if (dateParts.length == 3 && timeParts.length >= 2) {
        final y = int.tryParse(dateParts[0]);
        final m = int.tryParse(dateParts[1]);
        final d = int.tryParse(dateParts[2]);
        final h = int.tryParse(timeParts[0]);
        final min = int.tryParse(timeParts[1]);
        if (y != null && m != null && d != null && h != null && min != null) {
          return DateTime(y, m, d, h, min);
        }
      }
    }

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
