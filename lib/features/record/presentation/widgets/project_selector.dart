import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';

/// BottomSheet project selector for the record page.
///
/// Shows only non-archived projects. Includes a "无项目" option at the top.
class ProjectSelector extends ConsumerWidget {
  final void Function(int? id, String? name) onSelected;

  const ProjectSelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(activeProjectsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            '选择项目',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            data: (projects) {
              return ListView(
                children: [
                  // "无项目" option
                  ListTile(
                    leading: const CircleAvatar(
                      radius: 18,
                      child: Icon(Icons.block, size: 18),
                    ),
                    title: const Text('无项目'),
                    onTap: () {
                      onSelected(null, null);
                      Navigator.pop(context);
                    },
                  ),
                  if (projects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          '暂无活跃项目',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                  else
                    ...projects.map(
                      (p) => ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          child: Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(p.name),
                        onTap: () {
                          onSelected(p.id, p.name);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
          ),
        ),
      ],
    );
  }
}
