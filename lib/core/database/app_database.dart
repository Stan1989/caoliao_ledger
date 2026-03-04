import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/ledgers.dart';
import 'tables/accounts.dart';
import 'tables/categories.dart';
import 'tables/transactions.dart';
import 'tables/attachments.dart';
import 'tables/members.dart';
import 'tables/projects.dart';
import 'daos/ledger_dao.dart';
import 'daos/account_dao.dart';
import 'daos/category_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/attachment_dao.dart';
import 'daos/member_dao.dart';
import 'daos/project_dao.dart';
import 'daos/report_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Ledgers,
    Accounts,
    Categories,
    Transactions,
    Attachments,
    Members,
    Projects,
  ],
  daos: [
    LedgerDao,
    AccountDao,
    CategoryDao,
    TransactionDao,
    AttachmentDao,
    MemberDao,
    ProjectDao,
    ReportDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations go here.
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'caoliao_ledger.sqlite'));

    // Fix for Android: ensure the bundled libsqlite3.so can be found.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file);
  });
}
