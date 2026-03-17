import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/models/enums.dart';
import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/features/transaction_flow/presentation/flow_page.dart';

Transaction _txn({
  required int type,
  String? note,
  int? categoryId,
  int accountId = 1,
  int? toAccountId,
}) {
  final now = DateTime(2026, 3, 16, 10, 0, 0);
  return Transaction(
    id: 1,
    ledgerId: 1,
    type: type,
    amount: 10,
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    memberId: null,
    projectId: null,
    merchant: null,
    note: note,
    transactionDate: now,
    createdAt: now,
    syncStatus: 0,
    remoteId: null,
    updatedAt: now,
  );
}

void main() {
  group('buildFlowItemTitle', () {
    test('expense/income use trimmed note when note is not blank', () {
      final expense = _txn(type: TransactionType.expense.value, note: ' 午饭 ');
      final income = _txn(type: TransactionType.income.value, note: '工资');

      expect(buildFlowItemTitle(expense, const {}, const {}), '午饭');
      expect(buildFlowItemTitle(income, const {}, const {}), '工资');
    });

    test('expense/income fallback to subcategory when note is blank', () {
      final expense = _txn(
        type: TransactionType.expense.value,
        note: '   ',
        categoryId: 11,
      );
      final income = _txn(
        type: TransactionType.income.value,
        note: '',
        categoryId: 22,
      );

      expect(
        buildFlowItemTitle(expense, const {11: '餐饮-午餐'}, const {11}),
        '餐饮-午餐',
      );
      expect(
        buildFlowItemTitle(income, const {22: '工资-奖金'}, const {22}),
        '工资-奖金',
      );
    });

    test('expense/income fallback to type default when no subcategory', () {
      final expense = _txn(
        type: TransactionType.expense.value,
        note: null,
        categoryId: 10,
      );
      final income = _txn(
        type: TransactionType.income.value,
        note: ' ',
        categoryId: 20,
      );

      expect(buildFlowItemTitle(expense, const {10: '餐饮'}, const {}), '支出');
      expect(buildFlowItemTitle(income, const {20: '工资'}, const {}), '收入');
    });

    test('transfer title is always fixed to 转账', () {
      final transferWithNote = _txn(
        type: TransactionType.transfer.value,
        note: '任意备注',
        toAccountId: 2,
      );
      final transferNoNote = _txn(
        type: TransactionType.transfer.value,
        note: null,
        toAccountId: 2,
      );

      expect(buildFlowItemTitle(transferWithNote, const {}, const {}), '转账');
      expect(buildFlowItemTitle(transferNoNote, const {}, const {}), '转账');
    });
  });

  group('matchesAccountFilter', () {
    test('returns true when no account filter is set', () {
      final txn = _txn(type: TransactionType.expense.value, accountId: 5);
      expect(matchesAccountFilter(txn, const {}), isTrue);
    });

    test('matches source account and transfer destination account', () {
      final normalTxn = _txn(type: TransactionType.expense.value, accountId: 5);
      final transferTxn = _txn(
        type: TransactionType.transfer.value,
        accountId: 3,
        toAccountId: 9,
      );

      expect(matchesAccountFilter(normalTxn, const {5}), isTrue);
      expect(matchesAccountFilter(transferTxn, const {9}), isTrue);
      expect(matchesAccountFilter(transferTxn, const {7}), isFalse);
    });
  });
}
