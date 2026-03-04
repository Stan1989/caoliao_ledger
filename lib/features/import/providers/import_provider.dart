import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/import_row.dart';
import '../services/excel_parser.dart';
import '../services/import_preview.dart';
import '../services/import_service.dart';

/// Import workflow states.
enum ImportStatus {
  idle,
  parsing,
  previewing,
  importing,
  done,
  error,
}

/// State for the import workflow.
class ImportState {
  const ImportState({
    this.status = ImportStatus.idle,
    this.fileName,
    this.importData,
    this.preview,
    this.result,
    this.errorMessage,
    this.processedCount = 0,
    this.totalCount = 0,
    this.phaseDescription = '',
    this.skipDuplicates = false,
  });

  final ImportStatus status;
  final String? fileName;
  final ImportData? importData;
  final ImportPreviewResult? preview;
  final ImportResult? result;
  final String? errorMessage;
  final int processedCount;
  final int totalCount;
  final String phaseDescription;
  final bool skipDuplicates;

  ImportState copyWith({
    ImportStatus? status,
    String? fileName,
    ImportData? importData,
    ImportPreviewResult? preview,
    ImportResult? result,
    String? errorMessage,
    int? processedCount,
    int? totalCount,
    String? phaseDescription,
    bool? skipDuplicates,
  }) {
    return ImportState(
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      importData: importData ?? this.importData,
      preview: preview ?? this.preview,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      phaseDescription: phaseDescription ?? this.phaseDescription,
      skipDuplicates: skipDuplicates ?? this.skipDuplicates,
    );
  }
}

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  /// Toggle skip duplicates setting.
  void setSkipDuplicates(bool value) {
    state = state.copyWith(skipDuplicates: value);
  }

  /// Pick an xlsx file and parse + preview it.
  Future<void> pickAndPreview() async {
    final ledgerId = ref.read(activeLedgerIdProvider);
    if (ledgerId == null) {
      state = state.copyWith(
        status: ImportStatus.error,
        errorMessage: '请先选择一个账本',
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return; // user cancelled

      final file = result.files.first;
      if (file.bytes == null) {
        state = state.copyWith(
          status: ImportStatus.error,
          errorMessage: '无法读取文件数据',
        );
        return;
      }

      state = state.copyWith(
        status: ImportStatus.parsing,
        fileName: file.name,
      );

      // Parse Excel.
      final parser = ExcelParser();
      final importData = parser.parse(file.bytes!);

      if (importData.rows.isEmpty) {
        state = state.copyWith(
          status: ImportStatus.error,
          errorMessage: '文件中没有找到可导入的数据',
        );
        return;
      }

      // Generate preview.
      state = state.copyWith(status: ImportStatus.previewing);
      final db = ref.read(appDatabaseProvider);
      final previewService = ImportPreview(db);
      final preview = await previewService.analyze(ledgerId, importData);

      state = state.copyWith(
        status: ImportStatus.previewing,
        importData: importData,
        preview: preview,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        errorMessage: '解析文件失败：$e',
      );
    }
  }

  /// Execute the import after user confirms.
  Future<void> confirmImport() async {
    final ledgerId = ref.read(activeLedgerIdProvider);
    final data = state.importData;
    if (ledgerId == null || data == null) return;

    state = state.copyWith(
      status: ImportStatus.importing,
      totalCount: data.totalCount,
      processedCount: 0,
    );

    try {
      final db = ref.read(appDatabaseProvider);
      final service = ImportService(db);

      final result = await service.import(
        ledgerId,
        data,
        skipDuplicates: state.skipDuplicates,
        onProgress: (processed, total, phase) {
          state = state.copyWith(
            processedCount: processed,
            totalCount: total,
            phaseDescription: phase,
          );
        },
      );

      state = state.copyWith(
        status: ImportStatus.done,
        result: result,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        errorMessage: '导入失败：$e',
      );
    }
  }

  /// Reset to idle state.
  void reset() {
    state = const ImportState();
  }
}

final importProvider =
    NotifierProvider<ImportNotifier, ImportState>(ImportNotifier.new);
