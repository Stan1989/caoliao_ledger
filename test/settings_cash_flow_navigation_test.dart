import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caoliao_ledger/features/cash_flow_analysis/presentation/cash_flow_analysis_page.dart';
import 'package:caoliao_ledger/features/settings/presentation/settings_page.dart';

void main() {
  Future<void> pumpSettings(
    WidgetTester tester, {
    required GoRouter router,
  }) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/cash-flow-analysis',
          builder: (context, state) => const CashFlowAnalysisPage(),
        ),
      ],
    );
  }

  testWidgets('shows cash-flow analysis entry and navigates to page', (
    tester,
  ) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpSettings(tester, router: router);

    expect(find.text('现金流分析'), findsOneWidget);
    expect(find.text('查看流入、流出与净现金流变化'), findsOneWidget);

    await tester.tap(find.text('现金流分析').first);
    await tester.pumpAndSettle();

    expect(find.byType(CashFlowAnalysisPage), findsOneWidget);
    expect(find.text('现金流分析'), findsWidgets);
  });
}