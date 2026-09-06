import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_scaffold.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/boot_page.dart';
import '../features/auth/private_app_page.dart';
import '../features/common/placeholder_page.dart';
import '../features/export/export_page.dart';
import '../features/home/home_page.dart';
import '../features/report/report_page.dart';
import '../features/settings/activity_page.dart';
import '../features/settings/appearance_page.dart';
import '../features/settings/catalog_page.dart';
import '../features/settings/participants_page.dart';
import '../features/settings/property_form_page.dart';
import '../features/settings/reminders_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/trash_page.dart';
import '../features/expenses/expense_detail_page.dart';
import '../features/expenses/expense_form_page.dart';
import '../features/expenses/expenses_list_page.dart';
import '../features/tasks/task_form_page.dart';
import '../features/tasks/tasks_page.dart';
import '../features/transfers/transfer_form_page.dart';
import '../features/transfers/transfers_list_page.dart';
import '../features/import_excel/import_excel_page.dart';
import 'auth_redirect.dart';
import 'navigator_keys.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefresh(ref);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: bootLocation,
    refreshListenable: authRefresh,
    observers: [_ClearSnackBarsObserver()],
    redirect: (context, state) {
      return authRedirect(
        auth: ref.read(authSessionProvider),
        loc: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: bootLocation,
        builder: (context, state) => const BootPage(),
      ),
      GoRoute(
        path: loginLocation,
        builder: (context, state) => const BootPage(),
      ),
      GoRoute(
        path: privateLocation,
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
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ExpenseFormPage(
                      prefill: state.extra is ExpenseFormPrefill
                          ? state.extra as ExpenseFormPrefill
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ExpenseDetailPage(
                      id: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'modifica',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => ExpenseFormPage(
                          id: state.pathParameters['id'],
                          prefill: state.extra is ExpenseFormPrefill
                              ? state.extra as ExpenseFormPrefill
                              : null,
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
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra;
                      String? listId;
                      if (extra is Map && extra['listId'] is String) {
                        listId = extra['listId'] as String;
                      }
                      return TaskFormPage(initialListId: listId);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => TaskFormPage(
                      id: state.pathParameters['id'],
                    ),
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
                routes: [
                  GoRoute(
                    path: 'partecipanti',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ParticipantsPage(),
                  ),
                  GoRoute(
                    path: 'immobili',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const CatalogPage(kind: CatalogKind.properties),
                    routes: [
                      GoRoute(
                        path: 'nuovo',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const PropertyFormPage(),
                      ),
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => PropertyFormPage(
                          id: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'categorie',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const CatalogPage(kind: CatalogKind.categories),
                  ),
                  GoRoute(
                    path: 'aspetto',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AppearancePage(),
                  ),
                  GoRoute(
                    path: 'promemoria',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const RemindersPage(),
                  ),
                  GoRoute(
                    path: 'attivita',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ActivityPage(),
                  ),
                  GoRoute(
                    path: 'cestino',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const TrashPage(),
                  ),
                ],
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

class _ClearSnackBarsObserver extends NavigatorObserver {
  void _clear() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.clearSnackBars();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _clear();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _clear();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _clear();
}
