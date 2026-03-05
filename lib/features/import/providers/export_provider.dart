import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../services/excel_exporter.dart';

/// Export state with status tracking.
enum ExportStatus { idle, exporting, success, error }

class ExportState {
  const ExportState({
    this.status = ExportStatus.idle,
    this.filePath,
    this.rowCount = 0,
    this.errorMessage,
  });

  final ExportStatus status;
  final String? filePath;
  final int rowCount;
  final String? errorMessage;

  ExportState copyWith({
    ExportStatus? status,
    String? filePath,
    int? rowCount,
    String? errorMessage,
  }) {
    return ExportState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      rowCount: rowCount ?? this.rowCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier that handles Excel export workflow.
class ExportNotifier extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  /// Export all transactions for the active ledger to an Excel file.
  /// Returns the file path on success, null on failure.
  Future<String?> exportToExcel() async {
    state = const ExportState(status: ExportStatus.exporting);

    try {
      final ledgerId = ref.read(activeLedgerIdProvider);
      if (ledgerId == null) {
        state = const ExportState(
          status: ExportStatus.error,
          errorMessage: '请先选择账本',
        );
        return null;
      }

      // Get all transactions for this ledger
      final txnRepo = ref.read(transactionRepositoryProvider);
      final transactions = await txnRepo.getByLedgerAndDateRange(
        ledgerId,
        DateTime(2000),
        DateTime(2100),
      );

      if (transactions.isEmpty) {
        state = const ExportState(
          status: ExportStatus.error,
          errorMessage: '当前账本无交易数据',
        );
        return null;
      }

      // Build name lookup maps
      final db = ref.read(appDatabaseProvider);
      final accounts = await db.accountDao.getByLedger(ledgerId);
      final categories = await db.categoryDao.getByLedger(ledgerId);
      final members = await db.memberDao.watchByLedger(ledgerId).first;
      final projects = await db.projectDao.watchByLedger(ledgerId).first;
      final ledger = await ref.read(ledgerRepositoryProvider).getById(ledgerId);

      final accountNames = <int, String>{};
      for (final a in accounts) {
        accountNames[a.id] = a.name;
      }

      final categoryNames = <int, String>{};
      final parentCategoryNames = <int, String>{};
      for (final c in categories) {
        categoryNames[c.id] = c.name;
        if (c.parentId != null) {
          // Find parent name
          final parent = categories.where((p) => p.id == c.parentId).firstOrNull;
          if (parent != null) {
            parentCategoryNames[c.id] = parent.name;
          }
        }
      }

      final memberNames = <int, String>{};
      for (final m in members) {
        memberNames[m.id] = m.name;
      }

      final projectNames = <int, String>{};
      for (final p in projects) {
        projectNames[p.id] = p.name;
      }

      final ledgerName = ledger?.name ?? '账本';

      // Export
      final exporter = ExcelExporter();
      final result = await exporter.export(
        transactions: transactions,
        accountNames: accountNames,
        categoryNames: categoryNames,
        parentCategoryNames: parentCategoryNames,
        memberNames: memberNames,
        projectNames: projectNames,
        ledgerName: ledgerName,
      );

      state = ExportState(
        status: ExportStatus.success,
        filePath: result.filePath,
        rowCount: result.rowCount,
      );
      return result.filePath;
    } catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        errorMessage: '导出失败：$e',
      );
      return null;
    }
  }

  void reset() {
    state = const ExportState();
  }
}

final exportProvider =
    NotifierProvider<ExportNotifier, ExportState>(ExportNotifier.new);
