import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// About page displaying app metadata.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _author = 'baozi';
  static const String _releaseDate = '2026-03-03';
  static const String _repoUrl = 'https://github.com/Stan1989/caoliao_ledger';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于草料记账')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '...';
          final buildNumber = snapshot.data?.buildNumber ?? '';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.menu_book_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '草料记账',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              _InfoTile(
                icon: Icons.tag,
                label: '版本',
                value: buildNumber.isNotEmpty
                    ? 'v$version+$buildNumber'
                    : 'v$version',
              ),
              const Divider(height: 1),
              const _InfoTile(
                icon: Icons.calendar_today,
                label: '发布日期',
                value: _releaseDate,
              ),
              const Divider(height: 1),
              const _InfoTile(
                icon: Icons.person,
                label: '作者',
                value: _author,
              ),
              const Divider(height: 1),
              _InfoTile(
                icon: Icons.code,
                label: '项目地址',
                value: 'GitHub',
                onTap: () => launchUrl(
                  Uri.parse(_repoUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      onTap: onTap,
    );
  }
}
