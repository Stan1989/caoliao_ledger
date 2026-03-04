import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../providers/category_management_provider.dart';

/// Category management page — supports CRUD, expand/collapse, drag-reorder,
/// delete protection for both expense and income categories.
class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryManagementProvider);
    final notifier = ref.read(categoryManagementProvider.notifier);
    final ledgerId = ref.watch(activeLedgerIdProvider);

    if (ledgerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('分类管理')),
        body: const Center(child: Text('请先选择账本')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: Column(
        children: [
          // Expense / Income segmented button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('支出')),
                ButtonSegment(value: 1, label: Text('收入')),
              ],
              selected: {state.selectedType},
              onSelectionChanged: (sel) => notifier.setType(sel.first),
            ),
          ),
          // Category list
          Expanded(
            child: _CategoryList(
              ledgerId: ledgerId,
              type: state.selectedType,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(context, ref, ledgerId),
        icon: const Icon(Icons.add),
        label: const Text('添加一级分类'),
      ),
    );
  }
}

/// Displays first-level categories as a reorderable list with expandable
/// sub-categories.
class _CategoryList extends ConsumerWidget {
  final int ledgerId;
  final int type;

  const _CategoryList({required this.ledgerId, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryManagementProvider);
    final notifier = ref.read(categoryManagementProvider.notifier);

    // Watch first-level categories for this type
    final categories = type == 0
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('暂无分类，点击右下角按钮添加'),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          onReorderStart: (_) {
            // Auto-collapse all on drag start
            notifier.collapseAll();
          },
          onReorder: (oldIndex, newIndex) {
            notifier.reorderPrimaryCategories(items, oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final category = items[index];
            final isExpanded = state.expandedIds.contains(category.id);

            return _PrimaryCategoryTile(
              key: ValueKey(category.id),
              category: category,
              isExpanded: isExpanded,
              ledgerId: ledgerId,
            );
          },
        );
      },
    );
  }
}

/// A single first-level category tile with expand/collapse, edit, delete,
/// and subcategory management.
class _PrimaryCategoryTile extends ConsumerWidget {
  final Category category;
  final bool isExpanded;
  final int ledgerId;

  const _PrimaryCategoryTile({
    super.key,
    required this.category,
    required this.isExpanded,
    required this.ledgerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(categoryManagementProvider.notifier);
    final subcategories = ref.watch(subcategoriesProvider(category.id));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            _iconFromName(category.icon),
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(category.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () =>
                    _showEditCategorySheet(context, ref, category),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () =>
                    _confirmDeletePrimary(context, ref, category),
              ),
              // Expand/collapse indicator
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
            ],
          ),
          onTap: () => notifier.toggleExpand(category.id),
        ),
        // Subcategories (when expanded)
        if (isExpanded)
          subcategories.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('加载子分类失败: $e'),
            ),
            data: (subs) => _SubcategorySection(
              parentCategory: category,
              subcategories: subs,
              ledgerId: ledgerId,
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Shows subcategories as a reorderable list within a parent, plus an
/// "add subcategory" button at the bottom.
class _SubcategorySection extends ConsumerWidget {
  final Category parentCategory;
  final List<Category> subcategories;
  final int ledgerId;

  const _SubcategorySection({
    required this.parentCategory,
    required this.subcategories,
    required this.ledgerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(categoryManagementProvider.notifier);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subcategories.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subcategories.length,
              onReorder: (oldIndex, newIndex) {
                notifier.reorderSubcategories(
                    subcategories, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final sub = subcategories[index];
                return ListTile(
                  key: ValueKey(sub.id),
                  contentPadding: const EdgeInsets.only(left: 56, right: 8),
                  title: Text(sub.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () =>
                            _showEditCategorySheet(context, ref, sub),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () =>
                            _confirmDeleteSub(context, ref, sub),
                      ),
                      const Icon(Icons.drag_handle, size: 18),
                    ],
                  ),
                );
              },
            ),
          // Add subcategory button
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            leading: Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            title: Text(
              '添加子分类',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
              ),
            ),
            onTap: () => _showAddSubcategorySheet(
                context, ref, ledgerId, parentCategory.id),
          ),
        ],
      ),
    );
  }
}

// ---- Bottom Sheets & Dialogs ----

/// Show bottom sheet to add a first-level category.
void _showAddCategorySheet(
    BuildContext context, WidgetRef ref, int ledgerId) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '添加一级分类',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '分类名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入分类名称')),
                );
                return;
              }
              ref
                  .read(categoryManagementProvider.notifier)
                  .addCategory(ledgerId: ledgerId, name: name);
              Navigator.of(ctx).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    ),
  );
}

/// Show bottom sheet to add a subcategory.
void _showAddSubcategorySheet(
    BuildContext context, WidgetRef ref, int ledgerId, int parentId) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '添加子分类',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '子分类名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入分类名称')),
                );
                return;
              }
              ref.read(categoryManagementProvider.notifier).addSubcategory(
                    ledgerId: ledgerId,
                    parentId: parentId,
                    name: name,
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    ),
  );
}

/// Show edit category bottom sheet.
void _showEditCategorySheet(
    BuildContext context, WidgetRef ref, Category category) {
  final controller = TextEditingController(text: category.name);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '编辑分类',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '分类名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入分类名称')),
                );
                return;
              }
              ref
                  .read(categoryManagementProvider.notifier)
                  .updateCategoryName(category, name);
              Navigator.of(ctx).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    ),
  );
}

/// Confirm and delete a first-level category (cascade check).
Future<void> _confirmDeletePrimary(
    BuildContext context, WidgetRef ref, Category category) async {
  final notifier = ref.read(categoryManagementProvider.notifier);
  final count = await notifier.canDeletePrimaryCategory(category.id);

  if (!context.mounted) return;

  if (count > 0) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('无法删除'),
        content: Text('该分类及其子分类下共有 $count 条记录，无法删除'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${category.name}」及其所有子分类吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.deletePrimaryCategoryWithChildren(category.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Confirm and delete a subcategory (simple check).
Future<void> _confirmDeleteSub(
    BuildContext context, WidgetRef ref, Category category) async {
  final notifier = ref.read(categoryManagementProvider.notifier);
  final count = await notifier.canDeleteCategory(category.id);

  if (!context.mounted) return;

  if (count > 0) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('无法删除'),
        content: Text('该分类下有 $count 条记录，无法删除'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${category.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteCategory(category.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ---- Helpers ----

/// Map icon name string to IconData. Falls back to category icon.
IconData _iconFromName(String? name) {
  if (name == null || name.isEmpty) return Icons.category;
  // Common icon mapping — extend as needed
  const map = {
    'food': Icons.restaurant,
    'transport': Icons.directions_bus,
    'shopping': Icons.shopping_cart,
    'entertainment': Icons.movie,
    'medical': Icons.local_hospital,
    'education': Icons.school,
    'salary': Icons.account_balance_wallet,
    'investment': Icons.trending_up,
    'gift': Icons.card_giftcard,
    'home': Icons.home,
  };
  return map[name] ?? Icons.category;
}
