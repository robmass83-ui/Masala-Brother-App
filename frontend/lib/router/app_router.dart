import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_scaffold.dart';
import '../features/auth/login_page.dart';
import '../features/auth/private_app_page.dart';
import '../features/common/placeholder_page.dart';
import '../features/export/export_page.dart';
import '../features/home/home_page.dart';
import '../features/report/report_page.dart';
import '../features/settings/settings_page.dart';
import '../features/expenses/expense_detail_page.dart';
import '../features/expenses/expense_form_page.dart';
import '../features/expenses/expenses_list_page.dart';
import '../features/tasks/task_form_page.dart';
import '../features/tasks/tasks_page.dart';
import '../features/transfers/transfer_form_page.dart';
import '../features/transfers/transfers_list_page.dart';
import '../features/import_excel/import_excel_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({String initialLocation = '/login'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/privata',
        builder: (context, state) => const PrivateAppPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/spese',
                builder: (context, state) => const ExpensesListPage(),
                routes: [
                  GoRoute(
                    path: 'nuova',
                    builder: (context, state) => const ExpenseFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ExpenseDetailPage(
                      id: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'modifica',
                        builder: (context, state) => ExpenseFormPage(
                          id: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dafare',
                builder: (context, state) => const TasksPage(),
                routes: [
                  GoRoute(
                    path: 'nuova',
                    builder: (context, state) => const TaskFormPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/altro',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/bonifici',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TransfersListPage(),
        routes: [
          GoRoute(
            path: 'nuovo',
            builder: (context, state) => const TransferFormPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/rendiconto',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReportPage(),
      ),
      GoRoute(
        path: '/esporta',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExportPage(),
      ),
      GoRoute(
        path: '/importa',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ImportExcelPage(),
      ),
      GoRoute(
        path: '/placeholder',
        builder: (context, state) =>
            const PlaceholderPage(title: 'Placeholder'),
      ),
    ],
  );
}
