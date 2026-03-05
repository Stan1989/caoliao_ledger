import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../providers/record_form_provider.dart';
import 'widgets/calculator_keyboard.dart';
import 'widgets/category_picker.dart';
import 'widgets/account_selector.dart';
import 'widgets/member_selector.dart';
import 'widgets/project_selector.dart';

/// Record page — add or edit expense, income, or transfer.
class RecordPage extends ConsumerStatefulWidget {
  /// If non-null, the page opens in edit mode for this transaction.
  final int? transactionId;

  const RecordPage({super.key, this.transactionId});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  final _noteController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = false;

  bool get _isEditMode => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    if (_isEditMode) {
      _loadTransaction();
    }
  }

  Future<void> _loadTransaction() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final txn = await repo.getById(widget.transactionId!);
      if (txn == null || !mounted) return;

      // Resolve category name
      String? categoryName;
      if (txn.categoryId != null) {
        final catRepo = ref.read(categoryRepositoryProvider);
        final cat = await catRepo.getById(txn.categoryId!);
        categoryName = cat?.name;
      }

      // Resolve account name
      final accRepo = ref.read(accountRepositoryProvider);
      final acc = await accRepo.getById(txn.accountId);
      final accountName = acc?.name ?? '';

      // Resolve toAccount name
      String? toAccountName;
      if (txn.toAccountId != null) {
        final toAcc = await accRepo.getById(txn.toAccountId!);
        toAccountName = toAcc?.name;
      }

      final txnType = TransactionType.fromValue(txn.type);

      // Resolve member name
      String? memberName;
      if (txn.memberId != null) {
        final db = ref.read(appDatabaseProvider);
        final member = await db.memberDao.getById(txn.memberId!);
        memberName = member?.name;
      }

      // Resolve project name
      String? projectName;
      if (txn.projectId != null) {
        final db = ref.read(appDatabaseProvider);
        final project = await db.projectDao.getById(txn.projectId!);
        projectName = project?.name;
      }

      ref.read(recordFormProvider.notifier).loadTransaction(
            type: txnType,
            amount: txn.amount,
            categoryId: txn.categoryId,
            categoryName: categoryName,
            accountId: txn.accountId,
            accountName: accountName,
            toAccountId: txn.toAccountId,
            toAccountName: toAccountName,
            memberId: txn.memberId,
            memberName: memberName,
            projectId: txn.projectId,
            projectName: projectName,
            note: txn.note,
            transactionDate: txn.transactionDate,
          );

      // Sync TabController to loaded type
      _tabController.removeListener(_onTabChanged);
      _tabController.index = txnType.index;
      _tabController.addListener(_onTabChanged);

      // Sync note controller
      _noteController.text = txn.note ?? '';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final type = TransactionType.values[_tabController.index];
      ref.read(recordFormProvider.notifier).setType(type);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final form = ref.read(recordFormProvider);
    final errors = <String>[];

    if (form.amount <= 0) errors.add('请输入金额');
    if (form.type != TransactionType.transfer && form.categoryId == null) {
      errors.add('请选择分类');
    }
    if (form.accountId == null) errors.add('请选择账户');
    if (form.memberId == null) errors.add('请选择成员');
    if (form.type == TransactionType.transfer) {
      if (form.toAccountId == null) errors.add('请选择转入账户');
      if (form.accountId == form.toAccountId) {
        errors.add('转出和转入账户不能相同');
      }
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完善必填信息')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);

      if (_isEditMode) {
        // --- Edit mode: update existing transaction ---
        final oldTxn = await repo.getById(widget.transactionId!);
        if (oldTxn == null) throw Exception('交易记录不存在');

        final updated = oldTxn.copyWith(
          type: form.type.value,
          amount: form.amount,
          categoryId: Value(form.categoryId),
          accountId: form.accountId!,
          toAccountId: Value(form.toAccountId),
          memberId: Value(form.memberId),
          projectId: Value(form.projectId),
          note: Value(form.note),
          transactionDate: form.transactionDate,
        );

        await repo.updateTransaction(updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改成功')),
          );
          context.pop();
        }
      } else {
        // --- Create mode: new transaction ---
        final ledgerId = ref.read(activeLedgerIdProvider)!;

        await repo.createTransaction(
          ledgerId: ledgerId,
          type: form.type.value,
          amount: form.amount,
          categoryId: form.categoryId,
          accountId: form.accountId!,
          toAccountId: form.toAccountId,
          memberId: form.memberId,
          projectId: form.projectId,
          note: form.note,
          transactionDate: form.transactionDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('记账成功')),
          );
          ref.read(recordFormProvider.notifier).reset();
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go('/transactions');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确认删除此交易记录？删除后不可恢复。'),
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

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteTransaction(widget.transactionId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final form = ref.watch(recordFormProvider);
    final isTransfer = form.type == TransactionType.transfer;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditMode ? '编辑交易' : '记账'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // Disable tab switching in edit mode
          onTap: _isEditMode ? (_) {
            _tabController.index = form.type.index;
          } : null,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
            Tab(text: '转账'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Amount display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Text(
              '¥ ${form.amount > 0 ? AppTheme.formatDisplayAmount(form.amount) : '0.00'}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.amountColor(form.type.value),
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          // Form fields
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                if (!isTransfer)
                  _FormRow(
                    icon: Icons.category,
                    label: '分类',
                    value: form.categoryName ?? '请选择',
                    onTap: () => _showCategoryPicker(context),
                  ),
                if (isTransfer) ...[
                  _FormRow(
                    icon: Icons.account_balance_wallet,
                    label: '转出账户',
                    value: form.accountName ?? '请选择',
                    onTap: () => _showAccountSelector(context, isFrom: true),
                  ),
                  _FormRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '转入账户',
                    value: form.toAccountName ?? '请选择',
                    onTap: () => _showAccountSelector(context, isFrom: false),
                  ),
                ] else
                  _FormRow(
                    icon: Icons.account_balance_wallet,
                    label: '账户',
                    value: form.accountName ?? '请选择',
                    onTap: () => _showAccountSelector(context, isFrom: true),
                  ),
                _FormRow(
                  icon: Icons.person_outline,
                  label: '成员',
                  value: form.memberName ?? '请选择',
                  onTap: () => _showMemberSelector(context),
                ),
                _FormRow(
                  icon: Icons.folder_outlined,
                  label: '项目',
                  value: form.projectName ?? '无',
                  onTap: () => _showProjectSelector(context),
                ),
                _FormRow(
                  icon: Icons.access_time,
                  label: '时间',
                  value: _formatDate(form.transactionDate),
                  onTap: () => _showDateTimePicker(context),
                ),
                _FormRow(
                  icon: Icons.edit_note,
                  label: '备注',
                  value: form.note ?? '无',
                  onTap: () => _showNoteInput(context),
                ),
              ],
            ),
          ),
          // Calculator keyboard
          CalculatorKeyboard(
            onValueChanged: (value) {
              ref.read(recordFormProvider.notifier).setAmount(value);
            },
            onDone: _save,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: CategoryPicker(
          type: ref.read(recordFormProvider).type == TransactionType.income
              ? CategoryType.income
              : CategoryType.expense,
          onSelected: (id, name) {
            ref.read(recordFormProvider.notifier).setCategory(id, name);
          },
        ),
      ),
    );
  }

  void _showAccountSelector(BuildContext context, {required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: AccountSelector(
          onSelected: (id, name) {
            if (isFrom) {
              ref.read(recordFormProvider.notifier).setAccount(id, name);
            } else {
              ref.read(recordFormProvider.notifier).setToAccount(id, name);
            }
          },
        ),
      ),
    );
  }

  void _showMemberSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: MemberSelector(
          onSelected: (id, name) {
            ref.read(recordFormProvider.notifier).setMember(id, name);
          },
        ),
      ),
    );
  }

  void _showProjectSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: ProjectSelector(
          onSelected: (id, name) {
            if (id == null) {
              ref.read(recordFormProvider.notifier).clearProject();
            } else {
              ref.read(recordFormProvider.notifier).setProject(id, name!);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showDateTimePicker(BuildContext context) async {
    final form = ref.read(recordFormProvider);
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: form.transactionDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(form.transactionDate),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Don't allow future dates
    final result = combined.isAfter(now) ? now : combined;
    ref.read(recordFormProvider.notifier).setDate(result);
  }

  void _showNoteInput(BuildContext context) {
    final form = ref.read(recordFormProvider);
    _noteController.text = form.note ?? '';

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
          children: [
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '添加备注...',
              ),
              autofocus: true,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(recordFormProvider.notifier)
                        .setNote(_noteController.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: const Text('确定'),
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

class _FormRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FormRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
