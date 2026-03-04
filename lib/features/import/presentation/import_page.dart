import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/import_provider.dart';

/// Main import page with file selection, preview, progress, and result.
class ImportPage extends ConsumerWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importProvider);
    final notifier = ref.read(importProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入 Excel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            notifier.reset();
            context.pop();
          },
        ),
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ImportState state,
    ImportNotifier notifier,
  ) {
    switch (state.status) {
      case ImportStatus.idle:
        return _IdleView(onPick: notifier.pickAndPreview);
      case ImportStatus.parsing:
        return const _LoadingView(message: '正在解析文件...');
      case ImportStatus.previewing:
        return _PreviewView(
          state: state,
          onConfirm: notifier.confirmImport,
          onCancel: notifier.reset,
          onSkipDuplicatesChanged: notifier.setSkipDuplicates,
        );
      case ImportStatus.importing:
        return _ImportingView(state: state);
      case ImportStatus.done:
        return _ResultView(state: state, onDone: notifier.reset);
      case ImportStatus.error:
        return _ErrorView(
          message: state.errorMessage ?? '未知错误',
          onRetry: notifier.reset,
        );
    }
  }
}

/// Idle state — show file pick button.
class _IdleView extends StatelessWidget {
  const _IdleView({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.file_upload_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '导入钱迹 Excel 数据',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '选择从钱迹 App 导出的 .xlsx 文件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading / parsing state.
class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

/// Preview state — show stats and confirm/cancel buttons.
class _PreviewView extends StatelessWidget {
  const _PreviewView({
    required this.state,
    required this.onConfirm,
    required this.onCancel,
    required this.onSkipDuplicatesChanged,
  });

  final ImportState state;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<bool> onSkipDuplicatesChanged;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview;
    if (preview == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.description, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.fileName ?? '',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '共 ${preview.totalRows} 条记录',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Transaction counts
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('交易明细', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                _StatRow(label: '支出', count: preview.expenseCount),
                _StatRow(label: '收入', count: preview.incomeCount),
                _StatRow(label: '转账', count: preview.transferCount),
                _StatRow(label: '余额变更', count: preview.adjustmentCount),
                if (preview.duplicateCount > 0) ...[
                  const Divider(),
                  _StatRow(
                    label: '重复跳过',
                    count: preview.duplicateCount,
                    color: theme.colorScheme.error,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // New entities
        if (preview.newAccounts.isNotEmpty ||
            preview.newCategories.isNotEmpty ||
            preview.newMembers.isNotEmpty ||
            preview.newProjects.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('将自动创建', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (preview.newAccounts.isNotEmpty)
                    _EntityChips(
                      label: '账户',
                      items: preview.newAccounts,
                    ),
                  if (preview.newCategories.isNotEmpty)
                    _EntityChips(
                      label: '分类',
                      items: preview.newCategories,
                    ),
                  if (preview.newMembers.isNotEmpty)
                    _EntityChips(
                      label: '成员',
                      items: preview.newMembers,
                    ),
                  if (preview.newProjects.isNotEmpty)
                    _EntityChips(
                      label: '项目',
                      items: preview.newProjects,
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),

        // Dedup toggle
        SwitchListTile(
          title: const Text('跳过重复记录'),
          subtitle: const Text('开启后将跳过已存在的相同记录'),
          value: state.skipDuplicates,
          onChanged: onSkipDuplicatesChanged,
        ),
        const SizedBox(height: 12),

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onConfirm,
                child: const Text('确认导入'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Importing progress state.
class _ImportingView extends StatelessWidget {
  const _ImportingView({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.totalCount > 0
        ? state.processedCount / state.totalCount
        : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 24),
            Text(
              state.phaseDescription,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '已处理 ${state.processedCount} / ${state.totalCount} 条',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress > 0 ? progress : null),
          ],
        ),
      ),
    );
  }
}

/// Result / done state.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.state, required this.onDone});

  final ImportState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (result == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('导入完成', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _StatRow(label: '成功导入', count: result.importedCount),
                    if (state.skipDuplicates)
                      _StatRow(label: '跳过重复', count: result.skippedDuplicates),
                    _StatRow(label: '新建账户', count: result.newAccounts),
                    _StatRow(label: '新建分类', count: result.newCategories),
                    _StatRow(label: '新建成员', count: result.newMembers),
                    _StatRow(label: '新建项目', count: result.newProjects),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onDone,
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper: a row showing "label: count".
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.count,
    this.color,
  });

  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper: chips showing entity names.
class _EntityChips extends StatelessWidget {
  const _EntityChips({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label (${items.length})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map((name) => Chip(
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
