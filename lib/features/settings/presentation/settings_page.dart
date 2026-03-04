import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings / "我的" page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
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
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                onTap: () {
                  // TODO: Implement Excel export
                },
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
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

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
