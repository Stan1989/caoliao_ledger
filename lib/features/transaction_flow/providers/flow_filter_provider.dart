import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';

const Set<TransactionType> kFlowSelectableTypes = {
  TransactionType.expense,
  TransactionType.income,
  TransactionType.transfer,
};

String flowFilterTypeSummary(Set<TransactionType> selectedTypes) {
  if (selectedTypes.isEmpty ||
      selectedTypes.length == kFlowSelectableTypes.length) {
    return '全部';
  }

  const ordered = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.transfer,
  ];
  final names = ordered.where(selectedTypes.contains).map((type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
      case TransactionType.balanceAdjustment:
        return '余额变更';
    }
  }).toList();
  return names.join(', ');
}

bool matchesFlowFilterTransactionType(FlowFilterState filter, int rawType) {
  if (filter.transactionTypes.isEmpty) {
    return true;
  }
  return filter.transactionTypes.contains(TransactionType.fromValue(rawType));
}

/// Filter state for the flow page.
class FlowFilterState {
  const FlowFilterState({
    this.dateRange,
    this.accountIds = const {},
    this.memberIds = const {},
    this.projectIds = const {},
    this.transactionTypes = const {},
    this.minAmount,
  });

  final DateTimeRange? dateRange;
  final Set<int> accountIds;
  final Set<int> memberIds;
  final Set<int> projectIds;
  final Set<TransactionType> transactionTypes;
  final double? minAmount;

  bool get isActive =>
      dateRange != null ||
      accountIds.isNotEmpty ||
      memberIds.isNotEmpty ||
      projectIds.isNotEmpty ||
      transactionTypes.isNotEmpty ||
      minAmount != null;

  /// True when date range or min amount is set — these override month navigation.
  bool get hasDateOverride => dateRange != null || minAmount != null;

  FlowFilterState copyWith({
    DateTimeRange? Function()? dateRange,
    Set<int>? accountIds,
    Set<int>? memberIds,
    Set<int>? projectIds,
    Set<TransactionType>? transactionTypes,
    double? Function()? minAmount,
  }) {
    return FlowFilterState(
      dateRange: dateRange != null ? dateRange() : this.dateRange,
      accountIds: accountIds ?? this.accountIds,
      memberIds: memberIds ?? this.memberIds,
      projectIds: projectIds ?? this.projectIds,
      transactionTypes: transactionTypes ?? this.transactionTypes,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
    );
  }
}

/// Notifier for flow filter state.
class FlowFilterNotifier extends Notifier<FlowFilterState> {
  @override
  FlowFilterState build() => const FlowFilterState();

  void setDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: () => range);
  }

  void setMinAmount(double? amount) {
    state = state.copyWith(minAmount: () => amount);
  }

  void toggleAccount(int id) {
    final updated = Set<int>.from(state.accountIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(accountIds: updated);
  }

  void toggleMember(int id) {
    final updated = Set<int>.from(state.memberIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(memberIds: updated);
  }

  void toggleProject(int id) {
    final updated = Set<int>.from(state.projectIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(projectIds: updated);
  }

  void setFilter(FlowFilterState filter) {
    state = filter;
  }

  void reset() {
    state = const FlowFilterState();
  }
}

/// Filter provider for the bottom tab FlowPage.
final flowFilterProvider =
    NotifierProvider<FlowFilterNotifier, FlowFilterState>(
      FlowFilterNotifier.new,
    );
