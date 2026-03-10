import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/database_provider.dart';
import '../../import/providers/export_provider.dart';

/// Settings / "我的" page.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _exporting = false;
  bool _deletingLedger = false;

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);

    try {
      final notifier = ref.read(exportProvider.notifier);
      final filePath = await notifier.exportToExcel();

      if (!mounted) return;
      setState(() => _exporting = false);

      final state = ref.read(exportProvider);

      if (filePath != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出成功'),
            content: Text('共导出 ${state.rowCount} 条记录'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('关闭'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  SharePlus.instance.share(
                    ShareParams(files: [XFile(filePath)]),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('分享文件'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出失败'),
            content: Text(state.errorMessage ?? '未知错误'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }

      notifier.reset();
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出失败'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteCurrentLedger() async {
    final activeLedgerId = ref.read(activeLedgerIdProvider);
    if (activeLedgerId == null || _deletingLedger) return;

    final repo = ref.read(ledgerRepositoryProvider);
    final ledger = await repo.getById(activeLedgerId);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除当前账本'),
        content: Text(
          '删除账本「${ledger?.name ?? activeLedgerId.toString()}」？\n\n'
          '此操作将删除该账本下的所有本地数据（账户、交易记录、分类、成员、项目），且不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingLedger = true);
    try {
      await repo.deleteLedger(activeLedgerId);
      ref.read(activeLedgerIdProvider.notifier).set(null);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账本已删除')));
      context.go('/ledger/select');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    } finally {
      if (mounted) setState(() => _deletingLedger = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLedgerId = ref.watch(activeLedgerIdProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('我的')),
          body: ListView(
            children: [
              const SizedBox(height: 16),
              // Profile section
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text('用户'),
                  subtitle: const Text('本地用户'),
                ),
              ),
              const SizedBox(height: 16),
              // Ledger management
              _SettingsSection(
                title: '账本管理',
                children: [
                  _SettingsTile(
                    icon: Icons.people_outline,
                    title: '成员管理',
                    subtitle: '管理账本成员与角色',
                    onTap: () => context.push('/members'),
                  ),
                  _SettingsTile(
                    icon: Icons.folder_outlined,
                    title: '项目管理',
                    subtitle: '管理记账项目',
                    onTap: () => context.push('/projects'),
                  ),
                  _SettingsTile(
                    icon: Icons.bar_chart,
                    title: '报表统计',
                    subtitle: '按账号、项目、分类统计收支',
                    onTap: () => context.push('/report'),
                  ),
                  _SettingsTile(
                    icon: Icons.category_outlined,
                    title: '分类管理',
                    subtitle: '管理收支分类与子分类',
                    onTap: () => context.push('/category-management'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Settings items
              _SettingsSection(
                title: '记账设置',
                children: [
                  _SettingsTile(
                    icon: Icons.tune,
                    title: '记账字段配置',
                    subtitle: '自定义记账页面显示的字段',
                    onTap: () {
                      // TODO: Implement field customization
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SettingsSection(
                title: '数据管理',
                children: [
                  _SettingsTile(
                    icon: Icons.file_download_outlined,
                    title: '导出 CSV',
                    subtitle: '将记录导出为 CSV 文件',
                    onTap: () {
                      // TODO: Implement CSV export
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.table_chart_outlined,
                    title: '导出 Excel',
                    subtitle: '将记录导出为 Excel 文件',
                    onTap: () => _exportExcel(),
                  ),
                  _SettingsTile(
                    icon: Icons.file_upload_outlined,
                    title: '导入 Excel',
                    subtitle: '从钱迹 App 导入 Excel 数据',
                    onTap: () => context.push('/import'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SettingsSection(
                title: '关于',
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: '关于草料记账',
                    subtitle: 'v1.0.0',
                    onTap: () => context.push('/about'),
                  ),
                ],
              ),
              if (activeLedgerId != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _deletingLedger ? null : _deleteCurrentLedger,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除当前账本'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_exporting || _deletingLedger)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
