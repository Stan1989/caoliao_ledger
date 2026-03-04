import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_provider.dart';

/// Two-step category picker BottomSheet.
class CategoryPicker extends ConsumerStatefulWidget {
  final CategoryType type;
  final void Function(int id, String name)? onSelected;

  const CategoryPicker({
    super.key,
    required this.type,
    this.onSelected,
  });

  @override
  ConsumerState<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<CategoryPicker> {
  Category? _selectedParent;
  bool _showSubcategories = false;

  @override
  Widget build(BuildContext context) {
    final categoriesStream = widget.type == CategoryType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _showSubcategories && _selectedParent != null
              ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _showSubcategories = false;
                          _selectedParent = null;
                        });
                      },
                    ),
                    Text(
                      _selectedParent!.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '选择分类',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: _showSubcategories && _selectedParent != null
              ? _buildSubcategories()
              : categoriesStream.when(
                  data: (categories) => _buildCategoryGrid(categories),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败：$e')),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(List<Category> categories) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryGridItem(
          name: cat.name,
          icon: cat.icon,
          onTap: () => _onParentTap(cat),
        );
      },
    );
  }

  void _onParentTap(Category parent) async {
    // Check if has subcategories
    final subs = await ref
        .read(categoryRepositoryProvider)
        .getSubcategories(parent.id);

    if (subs.isEmpty) {
      // No subcategories — select directly
      widget.onSelected?.call(parent.id, parent.name);
      if (mounted) Navigator.pop(context);
    } else {
      // Has subcategories — show step 2
      setState(() {
        _selectedParent = parent;
        _showSubcategories = true;
      });
    }
  }

  Widget _buildSubcategories() {
    final subsStream =
        ref.watch(subcategoriesProvider(_selectedParent!.id));

    return subsStream.when(
      data: (subs) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: subs.length,
        itemBuilder: (context, index) {
          final sub = subs[index];
          return _CategoryGridItem(
            name: sub.name,
            icon: sub.icon,
            onTap: () {
              final displayName = '${_selectedParent!.name} > ${sub.name}';
              widget.onSelected?.call(sub.id, displayName);
              Navigator.pop(context);
            },
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
    );
  }
}

class _CategoryGridItem extends StatelessWidget {
  final String name;
  final String? icon;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.name,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              icon ?? name.characters.first,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
