/// Transaction type: expense, income, transfer, or balance adjustment.
enum TransactionType {
  expense(0),
  income(1),
  transfer(2),
  balanceAdjustment(3);

  const TransactionType(this.value);
  final int value;

  static TransactionType fromValue(int value) {
    return TransactionType.values.firstWhere((e) => e.value == value);
  }
}

/// Account type classification.
enum AccountType {
  cash(0),
  bankCard(1),
  creditCard(2),
  wallet(3),
  receivable(4),
  liability(5),
  investment(6),
  other(7);

  const AccountType(this.value);
  final int value;

  static AccountType fromValue(int value) {
    return AccountType.values.firstWhere((e) => e.value == value);
  }

  /// Whether this account type represents a liability (debt owed).
  /// Liability accounts have inverted balance semantics: positive balance = debt.
  bool get isLiability => this == AccountType.creditCard || this == AccountType.liability;

  String get label {
    switch (this) {
      case AccountType.cash:
        return '现金';
      case AccountType.bankCard:
        return '银行卡';
      case AccountType.creditCard:
        return '信用卡';
      case AccountType.wallet:
        return '虚拟钱包';
      case AccountType.receivable:
        return '债权';
      case AccountType.liability:
        return '负债';
      case AccountType.investment:
        return '投资';
      case AccountType.other:
        return '其他';
    }
  }
}

/// Category type: expense or income.
enum CategoryType {
  expense(0),
  income(1);

  const CategoryType(this.value);
  final int value;

  static CategoryType fromValue(int value) {
    return CategoryType.values.firstWhere((e) => e.value == value);
  }
}

/// Member role within a ledger.
enum MemberRole {
  admin(0),
  member(1);

  const MemberRole(this.value);
  final int value;

  static MemberRole fromValue(int value) {
    return MemberRole.values.firstWhere((e) => e.value == value);
  }
}

/// Sync status for cloud sync reservation.
enum SyncStatus {
  synced(0),
  pending(1),
  conflict(2);

  const SyncStatus(this.value);
  final int value;

  static SyncStatus fromValue(int value) {
    return SyncStatus.values.firstWhere((e) => e.value == value);
  }
}
