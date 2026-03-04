import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/database_provider.dart';
import '../features/ledger/presentation/ledger_select_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/transaction_flow/presentation/flow_page.dart';
import '../features/record/presentation/record_page.dart';
import '../features/asset/presentation/asset_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/about_page.dart';
import '../features/settings/presentation/category_management_page.dart';
import '../features/report/presentation/report_page.dart' as report;
import '../features/member/presentation/member_page.dart';
import '../features/project/presentation/project_page.dart';
import '../features/import/presentation/import_page.dart';
import 'shell_page.dart';

/// Navigation key for root navigator.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider.
final routerProvider = Provider<GoRouter>((ref) {
  final activeLedgerId = ref.watch(activeLedgerIdProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isSelectingLedger = state.matchedLocation == '/ledger/select';
      if (activeLedgerId == null && !isSelectingLedger) {
        return '/ledger/select';
      }
      if (activeLedgerId != null && state.matchedLocation == '/') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/ledger/select',
        builder: (context, state) => const LedgerSelectPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const FlowPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/record',
                builder: (context, state) => const RecordPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/assets',
                builder: (context, state) => const AssetPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/record/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecordPage(transactionId: id);
        },
      ),
      GoRoute(
        path: '/members',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MemberPage(),
      ),
      GoRoute(
        path: '/projects',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProjectPage(),
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/report',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const report.ReportPage(),
      ),
      GoRoute(
        path: '/category-management',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoryManagementPage(),
      ),
      GoRoute(
        path: '/import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ImportPage(),
      ),
      GoRoute(
        path: '/account/:id/transactions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final name = state.uri.queryParameters['name'];
          return FlowPage(accountId: id, accountName: name);
        },
      ),
    ],
  );
});
