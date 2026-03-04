import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';

/// State for the record form.
class RecordFormState {
  final TransactionType type;
  final double amount;
  final int? categoryId;
  final String? categoryName;
  final int? accountId;
  final String? accountName;
  final int? toAccountId;
  final String? toAccountName;
  final int? memberId;
  final String? memberName;
  final int? projectId;
  final String? projectName;
  final String? note;
  final DateTime transactionDate;

  const RecordFormState({
    this.type = TransactionType.expense,
    this.amount = 0,
    this.categoryId,
    this.categoryName,
    this.accountId,
    this.accountName,
    this.toAccountId,
    this.toAccountName,
    this.memberId,
    this.memberName,
    this.projectId,
    this.projectName,
    this.note,
    required this.transactionDate,
  });

  RecordFormState copyWith({
    TransactionType? type,
    double? amount,
    int? categoryId,
    String? categoryName,
    int? accountId,
    String? accountName,
    int? toAccountId,
    String? toAccountName,
    int? memberId,
    String? memberName,
    int? projectId,
    String? projectName,
    String? note,
    DateTime? transactionDate,
    bool clearCategory = false,
    bool clearToAccount = false,
    bool clearProject = false,
  }) {
    return RecordFormState(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName:
          clearCategory ? null : (categoryName ?? this.categoryName),
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      toAccountId:
          clearToAccount ? null : (toAccountId ?? this.toAccountId),
      toAccountName:
          clearToAccount ? null : (toAccountName ?? this.toAccountName),
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      projectName: clearProject ? null : (projectName ?? this.projectName),
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
    );
  }
}

/// Notifier for record form state.
class RecordFormNotifier extends Notifier<RecordFormState> {
  @override
  RecordFormState build() {
    return RecordFormState(transactionDate: DateTime.now());
  }

  void setType(TransactionType type) {
    state = state.copyWith(type: type, clearCategory: true);
  }

  void setAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  void setCategory(int id, String name) {
    state = state.copyWith(categoryId: id, categoryName: name);
  }

  void setAccount(int id, String name) {
    state = state.copyWith(accountId: id, accountName: name);
  }

  void setToAccount(int id, String name) {
    state = state.copyWith(toAccountId: id, toAccountName: name);
  }

  void setDate(DateTime date) {
    state = state.copyWith(transactionDate: date);
  }

  void setNote(String? note) {
    state = state.copyWith(note: note);
  }

  void setMember(int id, String name) {
    state = state.copyWith(memberId: id, memberName: name);
  }

  void setProject(int id, String name) {
    state = state.copyWith(projectId: id, projectName: name);
  }

  void clearProject() {
    state = state.copyWith(clearProject: true);
  }

  /// Load an existing transaction into the form for editing.
  void loadTransaction({
    required TransactionType type,
    required double amount,
    int? categoryId,
    String? categoryName,
    required int accountId,
    required String accountName,
    int? toAccountId,
    String? toAccountName,
    int? memberId,
    String? memberName,
    int? projectId,
    String? projectName,
    String? note,
    required DateTime transactionDate,
  }) {
    state = RecordFormState(
      type: type,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      accountId: accountId,
      accountName: accountName,
      toAccountId: toAccountId,
      toAccountName: toAccountName,
      memberId: memberId,
      memberName: memberName,
      projectId: projectId,
      projectName: projectName,
      note: note,
      transactionDate: transactionDate,
    );
  }

  void reset() {
    // Keep type, category, account, note — only reset amount and time
    state = state.copyWith(amount: 0, transactionDate: DateTime.now());
  }
}

/// Provider for the record form.
final recordFormProvider =
    NotifierProvider<RecordFormNotifier, RecordFormState>(
  RecordFormNotifier.new,
);
