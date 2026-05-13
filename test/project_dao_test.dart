import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/core/models/enums.dart';

void main() {
  test('watchExpenseTotalsByLedger returns expense-only totals per project', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime(2026, 5, 13, 10);
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '测试账本', updatedAt: Value(now)),
        );
    final accountId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            ledgerId: ledgerId,
            name: '现金',
            type: AccountType.cash.value,
            updatedAt: Value(now),
          ),
        );
    final tripProjectId = await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            ledgerId: ledgerId,
            name: '旅行',
            updatedAt: Value(now),
          ),
        );
    final emptyProjectId = await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            ledgerId: ledgerId,
            name: '空项目',
            updatedAt: Value(now),
          ),
        );

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: TransactionType.expense.value,
            amount: 120,
            accountId: accountId,
            projectId: Value(tripProjectId),
            transactionDate: now,
            updatedAt: Value(now),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: TransactionType.expense.value,
            amount: 30,
            accountId: accountId,
            projectId: Value(tripProjectId),
            transactionDate: now,
            updatedAt: Value(now),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: TransactionType.income.value,
            amount: 999,
            accountId: accountId,
            projectId: Value(tripProjectId),
            transactionDate: now,
            updatedAt: Value(now),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: TransactionType.transfer.value,
            amount: 888,
            accountId: accountId,
            projectId: Value(tripProjectId),
            transactionDate: now,
            updatedAt: Value(now),
          ),
        );

    final totals = await db.projectDao.watchExpenseTotalsByLedger(ledgerId).first;

    expect(totals[tripProjectId], 150);
    expect(totals[emptyProjectId], 0);
  });
}