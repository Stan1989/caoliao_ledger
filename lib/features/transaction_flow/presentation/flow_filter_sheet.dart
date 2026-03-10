import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../providers/flow_filter_provider.dart';

/// Show the filter bottom sheet and return the updated filter state (or null if dismissed).
Future<FlowFilterState?> showFlowFilterSheet(
  BuildContext context, {
  required FlowFilterState current,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<FlowFilterState>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FlowFilterSheet(initial: current, ref: ref),
  );
}

class _FlowFilterSheet extends StatefulWidget {
  final FlowFilterState initial;
  final WidgetRef ref;

  const _FlowFilterSheet({required this.initial, required this.ref});

  @override
  State<_FlowFilterSheet> createState() => _FlowFilterSheetState();
}

class _FlowFilterSheetState extends State<_FlowFilterSheet> {
  late DateTimeRange? _dateRange;
  late Set<int> _accountIds;
  late Set<int> _memberIds;
  late Set<int> _projectIds;
  late Set<TransactionType> _transactionTypes;
  late double? _minAmount;

  static const _amountPresets = [
    (1000.0, '>¥1,000'),
    (3000.0, '>¥3,000'),
    (5000.0, '>¥5,000'),
    (10000.0, '>¥10,000'),
  ];

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initial.dateRange;
    _accountIds = Set.from(widget.initial.accountIds);
    _memberIds = Set.from(widget.initial.memberIds);
    _projectIds = Set.from(widget.initial.projectIds);
    _transactionTypes = Set.from(widget.initial.transactionTypes);
    _minAmount = widget.initial.minAmount;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = widget.ref.watch(allAccountsProvider);
    final membersAsync = widget.ref.watch(membersProvider);
    final projectsAsync = widget.ref.watch(projectsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('筛选条件', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                        _accountIds = {};
                        _memberIds = {};
                        _projectIds = {};
                        _transactionTypes = {};
                        _minAmount = null;
                      });
                    },
                    child: const Text('重置'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Date range
                  _SectionHeader(label: '时间范围'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _dateRange != null
                                ? '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}'
                                : '全部时间',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          if (_dateRange != null)
                            GestureDetector(
                              onTap: () => setState(() => _dateRange = null),
                              child: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Accounts
                  _SectionHeader(label: '账户'),
                  const SizedBox(height: 8),
                  accountsAsync.when(
                    data: (accounts) => _buildChips<Account>(
                      items: accounts,
                      selectedIds: _accountIds,
                      getId: (a) => a.id,
                      getLabel: (a) => a.name,
                      onToggle: (id) =>
                          setState(() => _toggleSet(_accountIds, id)),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('加载失败'),
                  ),
                  const SizedBox(height: 16),
                  // Members
                  _SectionHeader(label: '成员'),
                  const SizedBox(height: 8),
                  membersAsync.when(
                    data: (members) => _buildChips<Member>(
                      items: members,
                      selectedIds: _memberIds,
                      getId: (m) => m.id,
                      getLabel: (m) => m.name,
                      onToggle: (id) =>
                          setState(() => _toggleSet(_memberIds, id)),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('加载失败'),
                  ),
                  const SizedBox(height: 16),
                  // Projects
                  _SectionHeader(label: '项目'),
                  const SizedBox(height: 8),
                  projectsAsync.when(
                    data: (projects) => _buildChips<Project>(
                      items: projects,
                      selectedIds: _projectIds,
                      getId: (p) => p.id,
                      getLabel: (p) => p.name,
                      onToggle: (id) =>
                          setState(() => _toggleSet(_projectIds, id)),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('加载失败'),
                  ),
                  const SizedBox(height: 16),
                  // Transaction types
                  _SectionHeader(label: '流水类型'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: TransactionType.values
                        .where((t) => t != TransactionType.balanceAdjustment)
                        .map((type) {
                          final label = switch (type) {
                            TransactionType.expense => '支出',
                            TransactionType.income => '收入',
                            TransactionType.transfer => '转账',
                            TransactionType.balanceAdjustment => '余额变更',
                          };
                          return FilterChip(
                            label: Text(label),
                            selected: _transactionTypes.contains(type),
                            onSelected: (_) => setState(
                              () => _toggleSet(_transactionTypes, type),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // Amount filter
                  _SectionHeader(label: '金额范围'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _amountPresets.map((preset) {
                      final (value, label) = preset;
                      final selected = _minAmount == value;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _minAmount = selected ? null : value;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      FlowFilterState(
                        dateRange: _dateRange,
                        accountIds: _accountIds,
                        memberIds: _memberIds,
                        projectIds: _projectIds,
                        transactionTypes: _transactionTypes,
                        minAmount: _minAmount,
                      ),
                    );
                  },
                  child: const Text('确认'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _toggleSet<T>(Set<T> set, T id) {
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
  }

  Widget _buildChips<T>({
    required List<T> items,
    required Set<int> selectedIds,
    required int Function(T) getId,
    required String Function(T) getLabel,
    required ValueChanged<int> onToggle,
  }) {
    if (items.isEmpty) {
      return Text('暂无数据', style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        final id = getId(item);
        return FilterChip(
          label: Text(getLabel(item)),
          selected: selectedIds.contains(id),
          onSelected: (_) => onToggle(id),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleSmall);
  }
}
