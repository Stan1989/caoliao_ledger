import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caoliao_ledger/core/database/app_database.dart';
import 'package:caoliao_ledger/core/providers/database_provider.dart';
import 'package:caoliao_ledger/features/project/presentation/project_page.dart';

void main() {
  testWidgets('renders project names and expense totals for active and archived projects', (tester) async {
    final now = DateTime(2026, 5, 13, 10);
    final activeProject = Project(
      id: 1,
      ledgerId: 1,
      name: '旅行',
      isArchived: false,
      syncStatus: 0,
      remoteId: null,
      updatedAt: now,
    );
    final archivedProject = Project(
      id: 2,
      ledgerId: 1,
      name: '装修',
      isArchived: true,
      syncStatus: 0,
      remoteId: null,
      updatedAt: now,
    );

    final container = ProviderContainer(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => Stream.value([activeProject, archivedProject]),
        ),
        projectExpenseTotalsProvider.overrideWith(
          (ref) => Stream.value({1: 150.0, 2: 0.0}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeLedgerIdProvider.notifier).set(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectPage()),
      ),
    );
    await tester.pump();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('装修'), findsOneWidget);
    expect(find.text('支出 ¥150.00'), findsOneWidget);
    expect(find.text('支出 ¥0.00'), findsOneWidget);
    expect(find.text('已归档'), findsOneWidget);
  });
}