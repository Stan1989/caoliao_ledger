import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/core/providers/database_provider.dart';
import 'package:caoliao_ledger/core/repositories/ledger_repository.dart';
import 'package:caoliao_ledger/features/settings/presentation/settings_page.dart';

class _FakeLedgerRepository implements LedgerRepository {
  int? deletedId;
  bool throwOnDelete = false;

  @override
  Future<int> createLedger({
    required String name,
    String? icon,
    String currency = 'CNY',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteLedger(int id) async {
    if (throwOnDelete) throw Exception('delete failed');
    deletedId = id;
  }

  @override
  Future<List<Ledger>> getAll() async => [];

  @override
  Future<Ledger?> getById(int id) async {
    final now = DateTime.now();
    return Ledger(
      id: id,
      name: '测试账本',
      currency: 'CNY',
      createdAt: now,
      syncStatus: 0,
      updatedAt: now,
    );
  }

  @override
  Future<void> updateLedger(Ledger ledger) async {}

  @override
  Stream<List<Ledger>> watchAll() => const Stream.empty();
}

void main() {
  Future<void> _pumpSettings(
    WidgetTester tester, {
    required ProviderContainer container,
    required GoRouter router,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> _scrollToDeleteAction(WidgetTester tester) async {
    final scrollableFinder = find.byType(Scrollable).first;
    final deleteButtonFinder = find.widgetWithText(FilledButton, '删除当前账本');
    await tester.scrollUntilVisible(
      deleteButtonFinder,
      300,
      scrollable: scrollableFinder,
    );
    await tester.pumpAndSettle();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/ledger/select',
          builder: (context, state) =>
              const Scaffold(body: Text('ledger-select')),
        ),
      ],
    );
  }

  testWidgets(
    'shows delete-current-ledger action only when active ledger exists',
    (tester) async {
      final fakeRepo = _FakeLedgerRepository();
      final container = ProviderContainer(
        overrides: [ledgerRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      final router = _buildRouter();
      addTearDown(router.dispose);

      await _pumpSettings(tester, container: container, router: router);
      expect(find.text('删除当前账本'), findsNothing);

      container.read(activeLedgerIdProvider.notifier).set(1);
      await _pumpSettings(tester, container: container, router: router);
      await _scrollToDeleteAction(tester);

      expect(find.widgetWithText(FilledButton, '删除当前账本'), findsOneWidget);
    },
  );

  testWidgets(
    'confirm delete clears active ledger and navigates to ledger select',
    (tester) async {
      final fakeRepo = _FakeLedgerRepository();
      final container = ProviderContainer(
        overrides: [ledgerRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      container.read(activeLedgerIdProvider.notifier).set(1);

      final router = _buildRouter();
      addTearDown(router.dispose);

      await _pumpSettings(tester, container: container, router: router);

      await _scrollToDeleteAction(tester);

      await tester.tap(find.widgetWithText(FilledButton, '删除当前账本'));
      await tester.pumpAndSettle();

      expect(find.text('删除'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(fakeRepo.deletedId, 1);
      expect(container.read(activeLedgerIdProvider), isNull);
      expect(find.text('ledger-select'), findsOneWidget);
    },
  );

  testWidgets('cancel delete keeps state unchanged', (tester) async {
    final fakeRepo = _FakeLedgerRepository();
    final container = ProviderContainer(
      overrides: [ledgerRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    container.read(activeLedgerIdProvider.notifier).set(1);

    final router = _buildRouter();
    addTearDown(router.dispose);

    await _pumpSettings(tester, container: container, router: router);

    await _scrollToDeleteAction(tester);

    await tester.tap(find.widgetWithText(FilledButton, '删除当前账本'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(fakeRepo.deletedId, isNull);
    expect(container.read(activeLedgerIdProvider), 1);
    expect(find.widgetWithText(FilledButton, '删除当前账本'), findsOneWidget);
  });
}
