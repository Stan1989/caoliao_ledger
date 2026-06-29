import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../app/theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/database_provider.dart';

/// Sort members by the given [mode], using [expenseTotals] for amount sorting.
List<Member> _sortMembers(
  List<Member> members,
  Map<int, double> expenseTotals,
  MemberSortMode mode,
) {
  final sorted = List<Member>.from(members);
  switch (mode) {
    case MemberSortMode.nameAsc:
      sorted.sort((a, b) => a.name.compareTo(b.name));
    case MemberSortMode.nameDesc:
      sorted.sort((a, b) => b.name.compareTo(a.name));
    case MemberSortMode.amountAsc:
      sorted.sort((a, b) =>
          (expenseTotals[a.id] ?? 0).compareTo(expenseTotals[b.id] ?? 0));
    case MemberSortMode.amountDesc:
      sorted.sort((a, b) =>
          (expenseTotals[b.id] ?? 0).compareTo(expenseTotals[a.id] ?? 0));
  }
  return sorted;
}

/// Member management page.
class MemberPage extends ConsumerWidget {
  const MemberPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(activeLedgerIdProvider);
    if (ledgerId == null) {
      return const Scaffold(
        body: Center(child: Text('请先选择账本')),
      );
    }

    final membersAsync = ref.watch(membersProvider);
    final expenseTotalsAsync = ref.watch(memberExpenseTotalsProvider);
    final sortMode = ref.watch(memberSortModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成员管理'),
        actions: [
          PopupMenuButton<MemberSortMode>(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            initialValue: sortMode,
            onSelected: (mode) {
              ref.read(memberSortModeProvider.notifier).set(mode);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: MemberSortMode.nameAsc,
                child: Text('名称升序'),
              ),
              const PopupMenuItem(
                value: MemberSortMode.nameDesc,
                child: Text('名称降序'),
              ),
              const PopupMenuItem(
                value: MemberSortMode.amountAsc,
                child: Text('金额升序'),
              ),
              const PopupMenuItem(
                value: MemberSortMode.amountDesc,
                child: Text('金额降序'),
              ),
            ],
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (members) {
          return expenseTotalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (expenseTotals) {
              final sorted = _sortMembers(members, expenseTotals, sortMode);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...sorted.map(
                    (m) {
                      final expenseTotal = expenseTotals[m.id] ?? 0;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(m.name.characters.first),
                          ),
                          title: Text(m.name),
                          subtitle: Text(
                            '支出 ¥${AppTheme.formatDisplayAmount(expenseTotal)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: m.role == MemberRole.admin.value
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              m.role == MemberRole.admin.value
                                  ? '管理员'
                                  : '成员',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          onTap: () => _showEditMember(context, ref, m),
                          onLongPress: () =>
                              _confirmDeleteMember(context, ref, m),
                        ),
                      );
                    },
                  ),
                  // Robot placeholder
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.smart_toy_outlined),
                      ),
                      title: const Text('自动记账机器人'),
                      subtitle: Text(
                        '敬请期待',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMember(context, ref, ledgerId),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showEditMember(BuildContext context, WidgetRef ref, Member member) {
    final nameController = TextEditingController(text: member.name);
    int selectedRole = member.role;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('编辑成员',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '成员名称',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text('角色', style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: MemberRole.admin.value,
                    label: const Text('管理员'),
                  ),
                  ButtonSegment(
                    value: MemberRole.member.value,
                    label: const Text('成员'),
                  ),
                ],
                selected: {selectedRole},
                onSelectionChanged: (values) {
                  setSheetState(() => selectedRole = values.first);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final updated = member.copyWith(
                        name: name,
                        role: selectedRole,
                        updatedAt: DateTime.now(),
                      );
                      await ref
                          .read(appDatabaseProvider)
                          .memberDao
                          .updateMember(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMember(
      BuildContext context, WidgetRef ref, Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除成员'),
        content: const Text('确认删除此成员？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(appDatabaseProvider).memberDao.deleteMember(member.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
    }
  }

  void _showAddMember(BuildContext context, WidgetRef ref, int ledgerId) {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('添加成员',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '成员名称',
                hintText: '例如：老婆、老公、孩子',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    await ref
                        .read(appDatabaseProvider)
                        .memberDao
                        .createMember(
                          MembersCompanion.insert(
                            ledgerId: ledgerId,
                            name: name,
                            role: MemberRole.member.value,
                            updatedAt: Value(DateTime.now()),
                          ),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
