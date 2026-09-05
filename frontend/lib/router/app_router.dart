import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_scaffold.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_providers.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefresh(ref);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final auth = ref.read(authSessionProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading || auth.isRefreshing) {
        return null;
      }

      final session = auth.valueOrNull ?? const AuthSession.unknown();
      final loggingIn = loc == '/login';
      final privatePage = loc == '/privata';

      switch (session.status) {
        case AuthStatus.unknown:
          return loggingIn ? null : '/login';
        case AuthStatus.signedOut:
          return loggingIn ? null : '/login';
        case AuthStatus.unauthorized:
          return privatePage ? null : '/privata';
        case AuthStatus.authorized:
          if (loggingIn || privatePage) return '/';
          return null;
      }
    },
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
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    _sub = ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
  late final ProviderSubscription<AsyncValue<AuthSession>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
