import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

/// Ledger selection & creation page.
class LedgerSelectPage extends ConsumerStatefulWidget {
  const LedgerSelectPage({super.key});

  @override
  ConsumerState<LedgerSelectPage> createState() => _LedgerSelectPageState();
}

class _LedgerSelectPageState extends ConsumerState<LedgerSelectPage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createLedger() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账本名称')),
      );
      return;
    }

    final repo = ref.read(ledgerRepositoryProvider);
    final ledgerId = await repo.createLedger(name: name);
    ref.read(activeLedgerIdProvider.notifier).set(ledgerId);

    if (mounted) {
      _nameController.clear();
      context.go('/home');
    }
  }

  Future<void> _selectLedger(Ledger ledger) async {
    ref.read(activeLedgerIdProvider.notifier).set(ledger.id);
    context.go('/home');
  }

  Future<void> _confirmDeleteLedger(Ledger ledger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账本'),
        content: Text(
          '删除账本「${ledger.name}」？\n\n'
          '此操作将删除该账本下的所有数据（账户、交易记录、分类、成员、项目），且不可恢复。',
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

    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final activeLedgerId = ref.read(activeLedgerIdProvider);
      await repo.deleteLedger(ledger.id);

      if (activeLedgerId == ledger.id) {
        ref.read(activeLedgerIdProvider.notifier).set(null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建账本'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '账本名称',
            hintText: '例如：我的账本',
          ),
          autofocus: true,
          onSubmitted: (_) => _createLedger(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createLedger();
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgersAsync = ref.watch(ledgersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('选择账本')),
      body: ledgersAsync.when(
        data: (ledgers) {
          if (ledgers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有账本',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '创建一个账本开始记账吧',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('创建账本'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ledgers.length,
            itemBuilder: (context, index) {
              final ledger = ledgers[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(ledger.name.characters.first),
                  ),
                  title: Text(ledger.name),
                  subtitle: Text(ledger.currency),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectLedger(ledger),
                  onLongPress: () => _confirmDeleteLedger(ledger),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: ledgersAsync.maybeWhen(
        data: (ledgers) => ledgers.isNotEmpty
            ? FloatingActionButton(
                onPressed: _showCreateDialog,
                child: const Icon(Icons.add),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}
