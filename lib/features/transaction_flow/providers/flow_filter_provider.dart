import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter state for the flow page.
class FlowFilterState {
  const FlowFilterState({
    this.dateRange,
    this.accountIds = const {},
    this.memberIds = const {},
    this.projectIds = const {},
    this.minAmount,
  });

  final DateTimeRange? dateRange;
  final Set<int> accountIds;
  final Set<int> memberIds;
  final Set<int> projectIds;
  final double? minAmount;

  bool get isActive =>
      dateRange != null ||
      accountIds.isNotEmpty ||
      memberIds.isNotEmpty ||
      projectIds.isNotEmpty ||
      minAmount != null;

  FlowFilterState copyWith({
    DateTimeRange? Function()? dateRange,
    Set<int>? accountIds,
    Set<int>? memberIds,
    Set<int>? projectIds,
    double? Function()? minAmount,
  }) {
    return FlowFilterState(
      dateRange: dateRange != null ? dateRange() : this.dateRange,
      accountIds: accountIds ?? this.accountIds,
      memberIds: memberIds ?? this.memberIds,
      projectIds: projectIds ?? this.projectIds,
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
        FlowFilterNotifier.new);
