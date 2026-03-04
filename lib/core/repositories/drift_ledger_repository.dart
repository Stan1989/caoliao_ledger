import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import 'ledger_repository.dart';

/// Drift-backed implementation of [LedgerRepository].
class DriftLedgerRepository implements LedgerRepository {
  final AppDatabase _db;

  DriftLedgerRepository(this._db);

  @override
  Stream<List<Ledger>> watchAll() => _db.ledgerDao.watchAll();

  @override
  Future<List<Ledger>> getAll() => _db.ledgerDao.getAll();

  @override
  Future<Ledger?> getById(int id) => _db.ledgerDao.getById(id);

  @override
  Future<int> createLedger({
    required String name,
    String? icon,
    String currency = 'CNY',
  }) async {
    final now = DateTime.now();
    final ledgerId = await _db.ledgerDao.createLedger(
      LedgersCompanion.insert(
        name: name,
        icon: Value(icon),
        currency: Value(currency),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Seed default categories
    await _seedDefaultCategories(ledgerId);

    // Seed default member "我" (admin)
    await _db.memberDao.createMember(
      MembersCompanion.insert(
        ledgerId: ledgerId,
        name: '我',
        role: MemberRole.admin.value,
        updatedAt: Value(now),
      ),
    );

    return ledgerId;
  }

  @override
  Future<void> updateLedger(Ledger ledger) async {
    await _db.ledgerDao.updateLedger(ledger);
  }

  @override
  Future<void> deleteLedger(int id) async {
    await _db.transaction(() async {
      await _db.transactionDao.deleteByLedger(id);
      await _db.accountDao.deleteByLedger(id);
      await _db.categoryDao.deleteByLedger(id);
      await _db.memberDao.deleteByLedger(id);
      await _db.projectDao.deleteByLedger(id);
      await _db.ledgerDao.deleteLedger(id);
    });
  }

  /// Seed default expense and income categories for a new ledger.
  Future<void> _seedDefaultCategories(int ledgerId) async {
    final now = DateTime.now();
    int sortOrder = 0;

    // --- Expense categories ---
    final expenseType = CategoryType.expense.value;

    final expenseCategories = <String, List<String>>{
      '食品酒水': ['饮食堂食', '早午晚餐', '烟酒茶', '水果零食'],
      '行车交通': ['公共交通', '打车租车', '私家车费用', '加油', '停车费'],
      '居家生活': ['日用百货', '水电煤气', '房租', '物业管理', '维修保养', '房产供款'],
      '交流通讯': ['话费', '上网费', '邮递费'],
      '休闲娱乐': ['休闲玩乐', '宠物', '电影节目'],
      '人情往来': ['送礼请客', '孝敬长辈', '还人钱物', '慈善捐款'],
      '医疗保健': ['药品费', '保健费', '美容费', '治疗费'],
      '学习进阶': ['数码装备', '书报杂志', '培训进阶', '学校学费', '学习用品'],
      '衣服饰品': ['鞋帽服装', '手表首饰', '配饰', '箱包皮具'],
      '金融保险': ['银行手续', '按揭利息', '投资亏损', '消费贷款', '赔偿罚款', '利息支出'],
      '其他杂项': ['各种支出', '意外丢失', '烂账损失'],
      '临时大项': ['装修配套', '各种大项'],
    };

    for (final entry in expenseCategories.entries) {
      final parentId = await _db.categoryDao.createCategory(
        CategoriesCompanion.insert(
          ledgerId: ledgerId,
          name: entry.key,
          type: expenseType,
          sortOrder: Value(sortOrder++),
          updatedAt: Value(now),
        ),
      );

      int childSort = 0;
      for (final sub in entry.value) {
        await _db.categoryDao.createCategory(
          CategoriesCompanion.insert(
            ledgerId: ledgerId,
            name: sub,
            type: expenseType,
            parentId: Value(parentId),
            sortOrder: Value(childSort++),
            updatedAt: Value(now),
          ),
        );
      }
    }

    // --- Income categories ---
    final incomeType = CategoryType.income.value;
    sortOrder = 0;

    final incomeCategories = <String, List<String>>{
      '职业收入': ['工资收入', '加班收入', '奖金收入', '兼职收入', '经营所得'],
      '其他收入': ['投资收入', '利息收入', '礼金收入', '中奖收入', '意外来钱', '公积金提取', '红包', '退款'],
    };

    for (final entry in incomeCategories.entries) {
      final parentId = await _db.categoryDao.createCategory(
        CategoriesCompanion.insert(
          ledgerId: ledgerId,
          name: entry.key,
          type: incomeType,
          sortOrder: Value(sortOrder++),
          updatedAt: Value(now),
        ),
      );

      int childSort = 0;
      for (final sub in entry.value) {
        await _db.categoryDao.createCategory(
          CategoriesCompanion.insert(
            ledgerId: ledgerId,
            name: sub,
            type: incomeType,
            parentId: Value(parentId),
            sortOrder: Value(childSort++),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }
}
