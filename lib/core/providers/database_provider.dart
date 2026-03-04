import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/report_dao.dart';
import '../repositories/ledger_repository.dart';
import '../repositories/drift_ledger_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/drift_account_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/drift_category_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/drift_transaction_repository.dart';

/// Singleton AppDatabase provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Currently active ledger ID.
class ActiveLedgerIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final activeLedgerIdProvider =
    NotifierProvider<ActiveLedgerIdNotifier, int?>(ActiveLedgerIdNotifier.new);

/// Ledger repository provider.
final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftLedgerRepository(db);
});

/// Account repository provider.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAccountRepository(db);
});

/// Category repository provider.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftCategoryRepository(db);
});

/// Transaction repository provider.
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftTransactionRepository(db);
});

/// Watch all ledgers stream.
final ledgersProvider = StreamProvider<List<Ledger>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAll();
});

/// Watch accounts for the active ledger.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(accountRepositoryProvider).watchNonArchived(ledgerId);
});

/// Watch all accounts (including archived) for the active ledger.
final allAccountsProvider = StreamProvider<List<Account>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(accountRepositoryProvider).watchByLedger(ledgerId);
});

/// Watch expense categories for the active ledger.
final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(categoryRepositoryProvider).watchByLedgerAndType(ledgerId, 0);
});

/// Watch income categories for the active ledger.
final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(categoryRepositoryProvider).watchByLedgerAndType(ledgerId, 1);
});

/// Watch subcategories for a specific parent.
final subcategoriesProvider =
    StreamProvider.family<List<Category>, int>((ref, parentId) {
  return ref.watch(categoryRepositoryProvider).watchSubcategories(parentId);
});

/// Watch members for the active ledger.
final membersProvider = StreamProvider<List<Member>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(appDatabaseProvider).memberDao.watchByLedger(ledgerId);
});

/// Watch all projects (including archived) for the active ledger.
final projectsProvider = StreamProvider<List<Project>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(appDatabaseProvider).projectDao.watchByLedger(ledgerId);
});

/// Watch only active (non-archived) projects for the active ledger.
final activeProjectsProvider = StreamProvider<List<Project>>((ref) {
  final ledgerId = ref.watch(activeLedgerIdProvider);
  if (ledgerId == null) return const Stream.empty();
  return ref.watch(appDatabaseProvider).projectDao.watchNonArchived(ledgerId);
});

/// ReportDao provider for aggregation queries.
final reportDaoProvider = Provider<ReportDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.reportDao;
});
