import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../services/record_defaults_service.dart';

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
  /// Whether the form is in edit mode (editing an existing transaction).
  bool _isEditing = false;

  /// Version counter for async load operations (race condition guard).
  int _loadVersion = 0;

  @override
  RecordFormState build() {
    // Start with empty form, then async-load defaults.
    final initial = RecordFormState(transactionDate: DateTime.now());
    _isEditing = false;
    _loadVersion = 0;
    // Schedule default loading after build completes.
    Future.microtask(() => _loadDefaults(initial.type));
    return initial;
  }

  /// Async-load persisted defaults for [type] and fill into state.
  Future<void> _loadDefaults(TransactionType type) async {
    final version = ++_loadVersion;

    final ledgerId = ref.read(activeLedgerIdProvider);
    if (ledgerId == null) return;

    final service = ref.read(recordDefaultsServiceProvider);
    final db = ref.read(appDatabaseProvider);

    final defaults = await service.loadAndValidate(ledgerId, type, db);
    if (defaults == null) return;

    // Race guard: discard if a newer load was triggered.
    if (_loadVersion != version) return;

    state = state.copyWith(
      categoryId: defaults.categoryId,
      categoryName: defaults.categoryName,
      accountId: defaults.accountId,
      accountName: defaults.accountName,
      toAccountId: defaults.toAccountId,
      toAccountName: defaults.toAccountName,
      memberId: defaults.memberId,
      memberName: defaults.memberName,
      projectId: defaults.projectId,
      projectName: defaults.projectName,
    );
  }

  /// Persist current form selections as defaults (only in create mode).
  Future<void> _saveDefaults() async {
    if (_isEditing) return;

    final ledgerId = ref.read(activeLedgerIdProvider);
    if (ledgerId == null) return;

    final service = ref.read(recordDefaultsServiceProvider);
    final s = state;

    await service.save(
      ledgerId,
      s.type,
      RecordDefaultsData(
        categoryId: s.categoryId,
        categoryName: s.categoryName,
        accountId: s.accountId,
        accountName: s.accountName,
        toAccountId: s.toAccountId,
        toAccountName: s.toAccountName,
        memberId: s.memberId,
        memberName: s.memberName,
        projectId: s.projectId,
        projectName: s.projectName,
      ),
    );
  }

  void setType(TransactionType type) {
    state = state.copyWith(type: type, clearCategory: true);
    // Load defaults for the new type.
    _loadDefaults(type);
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
    _isEditing = true;
    // Bump version to cancel any pending async default loads.
    _loadVersion++;
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

  /// Called after a successful save. Persists defaults (create mode only),
  /// then resets amount and date.
  Future<void> onSaveSuccess() async {
    await _saveDefaults();
    state = state.copyWith(amount: 0, transactionDate: DateTime.now());
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
