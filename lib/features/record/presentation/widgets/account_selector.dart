import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_provider.dart';

/// Account selector BottomSheet — grouped by account type.
class AccountSelector extends ConsumerWidget {
  final void Function(int id, String name) onSelected;

  const AccountSelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            '选择账户',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '还没有账户',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请先在资产页面添加账户',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }

              // Group by type
              final grouped = <AccountType, List<Account>>{};
              for (final a in accounts) {
                final type = AccountType.fromValue(a.type);
                grouped.putIfAbsent(type, () => []).add(a);
              }

              return ListView(
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          entry.key.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                      ...entry.value.map(
                        (account) => ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            child: Icon(
                              _accountIcon(entry.key),
                              size: 18,
                            ),
                          ),
                          title: Text(account.name),
                          subtitle: account.cardLastFour != null
                              ? Text('**** ${account.cardLastFour}')
                              : null,
                          trailing: Text(
                            '¥${AppTheme.formatDisplayAmount(account.balance)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () {
                            onSelected(account.id, account.name);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
          ),
        ),
      ],
    );
  }

  IconData _accountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.bankCard:
        return Icons.credit_card;
      case AccountType.creditCard:
        return Icons.credit_score;
      case AccountType.wallet:
        return Icons.account_balance_wallet_outlined;
      case AccountType.receivable:
        return Icons.request_quote_outlined;
      case AccountType.liability:
        return Icons.money_off_outlined;
      case AccountType.investment:
        return Icons.trending_up;
      case AccountType.other:
        return Icons.account_balance_outlined;
    }
  }
}
