import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backup/drive_backup.dart';
import '../core/utils/money_format.dart';
import '../features/auth/auth_providers.dart';
import 'activity_models.dart';
import 'activity_repository.dart';
import 'balance_calculator.dart';
import 'expense_list_filter.dart';
import 'expense_models.dart';
import 'expense_repository.dart';
import 'household_repository.dart';
import 'report_aggregator.dart';
import 'report_period.dart';
import 'task_models.dart';
import 'task_repository.dart';
import 'transfer_models.dart';
import 'transfer_repository.dart';
import 'trash_models.dart';

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  return Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
});

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  final repo = HouseholdRepository(firestore: ref.watch(firestoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final repo = ActivityRepository(firestore: ref.watch(firestoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final repo = ExpenseRepository(
    firestore: ref.watch(firestoreProvider),
    activity: ref.watch(activityRepositoryProvider),
  )..onMoneyChanged =
      () => ref.read(driveBackupProvider.notifier).notifyMoneyChanged();
  ref.onDispose(repo.dispose);
  return repo;
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final repo = TransferRepository(
    firestore: ref.watch(firestoreProvider),
    activity: ref.watch(activityRepositoryProvider),
  )..onMoneyChanged =
      () => ref.read(driveBackupProvider.notifier).notifyMoneyChanged();
  ref.onDispose(repo.dispose);
  return repo;
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final repo = TaskRepository(
    firestore: ref.watch(firestoreProvider),
    activity: ref.watch(activityRepositoryProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchExpenses();
});

final transfersProvider = StreamProvider<List<Transfer>>((ref) {
  return ref.watch(transferRepositoryProvider).watchTransfers();
});

final expenseProvider = StreamProvider.family<Expense?, String>((ref, id) {
  return ref.watch(expenseRepositoryProvider).watchExpense(id);
});

final tasksProvider = StreamProvider<List<HouseholdTask>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTasks();
});

final taskListsProvider = StreamProvider<List<TaskList>>((ref) {
  return ref.watch(taskRepositoryProvider).watchLists();
});

final visibleTasksProvider = Provider<List<HouseholdTask>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.user?.uid;
  final tasks = ref.watch(tasksProvider).valueOrNull ?? const <HouseholdTask>[];
  return tasks.where((t) => t.isVisibleTo(uid)).toList();
});

final visibleTaskListsProvider = Provider<List<TaskList>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.user?.uid;
  final lists = ref.watch(taskListsProvider).valueOrNull ?? const <TaskList>[];
  return lists.where((l) => l.isVisibleTo(uid)).toList();
});

final taskProvider = StreamProvider.family<HouseholdTask?, String>((ref, id) {
  return ref.watch(taskRepositoryProvider).watchTask(id);
});

final categoriesProvider = StreamProvider<List<CatalogCategory>>((ref) {
  return ref.watch(householdRepositoryProvider).watchCategories();
});

final propertiesProvider = StreamProvider<List<CatalogProperty>>((ref) {
  return ref.watch(householdRepositoryProvider).watchProperties();
});

final _allCategoriesProvider = StreamProvider<List<CatalogCategory>>((ref) {
  return ref
      .watch(householdRepositoryProvider)
      .watchCategories(includeArchived: true);
});

final _allPropertiesProvider = StreamProvider<List<CatalogProperty>>((ref) {
  return ref
      .watch(householdRepositoryProvider)
      .watchProperties(includeArchived: true);
});

/// id → name for every category, archived ones included: an old expense
/// filed under an archived category still shows its name, not a raw id.
final categoryNamesProvider = Provider<Map<String, String>>((ref) {
  final all = ref.watch(_allCategoriesProvider).valueOrNull ??
      ref.watch(categoriesProvider).valueOrNull ??
      const <CatalogCategory>[];
  return {for (final x in all) x.id: x.name};
});

/// Same as [categoryNamesProvider], for properties.
final propertyNamesProvider = Provider<Map<String, String>>((ref) {
  final all = ref.watch(_allPropertiesProvider).valueOrNull ??
      ref.watch(propertiesProvider).valueOrNull ??
      const <CatalogProperty>[];
  return {for (final x in all) x.id: x.name};
});

final expenseListFilterProvider =
    StateProvider<ExpenseListFilter>((ref) => const ExpenseListFilter());

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.currentYear());

final reportSnapshotProvider = Provider<ReportSnapshot>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
  final transfers = ref.watch(transfersProvider).valueOrNull ?? const [];
  final tasks = ref.watch(visibleTasksProvider);
  final cats = ref.watch(categoryNamesProvider);
  final props = ref.watch(propertyNamesProvider);
  return const ReportAggregator().build(
    expenses: expenses,
    transfers: transfers,
    tasks: tasks,
    period: period,
    categoryNames: cats,
    propertyNames: props,
  );
});

final balanceProvider = Provider<BalanceSnapshot>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final household = session?.household;
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
  final transfers = ref.watch(transfersProvider).valueOrNull ?? const [];
  const calc = BalanceCalculator();
  return calc.calculate(
    expenses: expenses.map((e) => e.toBalanceInput()).toList(),
    transfers: transfers.map((t) => t.toBalanceInput()).toList(),
    robUid: household?.robUid ?? 'rob',
    lauUid: household?.lauUid ?? 'lau',
  );
});

/// Whether the balance can be trusted yet: while expenses or transfers are
/// still loading (or failed) the balance would wrongly read "in pari".
enum BalanceReadiness { loading, ready, failed }

final balanceReadinessProvider = Provider<BalanceReadiness>((ref) {
  final expenses = ref.watch(expensesProvider);
  final transfers = ref.watch(transfersProvider);
  if (expenses.hasError || transfers.hasError) return BalanceReadiness.failed;
  if (!expenses.hasValue || !transfers.hasValue) return BalanceReadiness.loading;
  return BalanceReadiness.ready;
});

final activityProvider = StreamProvider<List<ActivityEntry>>((ref) {
  return ref.watch(activityRepositoryProvider).watchActivity();
});

final deletedExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchDeleted();
});

final deletedTransfersProvider = StreamProvider<List<Transfer>>((ref) {
  return ref.watch(transferRepositoryProvider).watchDeleted();
});

final deletedTasksProvider = StreamProvider<List<HouseholdTask>>((ref) {
  return ref.watch(taskRepositoryProvider).watchDeleted();
});

final deletedTaskListsProvider = StreamProvider<List<TaskList>>((ref) {
  return ref.watch(taskRepositoryProvider).watchDeletedLists();
});

/// Ids of the other person's "solo mia" tasks and lists (live or trashed):
/// they must not surface in the Cestino or in Attività.
final hiddenPrivateIdsProvider = Provider<Set<String>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.user?.uid;
  final tasks = [
    ...ref.watch(tasksProvider).valueOrNull ?? const <HouseholdTask>[],
    ...ref.watch(deletedTasksProvider).valueOrNull ?? const <HouseholdTask>[],
  ];
  final lists = [
    ...ref.watch(taskListsProvider).valueOrNull ?? const <TaskList>[],
    ...ref.watch(deletedTaskListsProvider).valueOrNull ?? const <TaskList>[],
  ];
  return {
    for (final t in tasks)
      if (!t.isVisibleTo(uid)) t.id,
    for (final l in lists)
      if (!l.isVisibleTo(uid)) l.id,
  };
});

final visibleActivityProvider = Provider<AsyncValue<List<ActivityEntry>>>((ref) {
  final hidden = ref.watch(hiddenPrivateIdsProvider);
  return ref.watch(activityProvider).whenData(
        (items) => [
          for (final e in items)
            if (!hidden.contains(e.refId)) e,
        ],
      );
});

final trashItemsProvider = Provider<List<TrashItem>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.user?.uid;
  final expenses =
      ref.watch(deletedExpensesProvider).valueOrNull ?? const <Expense>[];
  final transfers =
      ref.watch(deletedTransfersProvider).valueOrNull ?? const <Transfer>[];
  final tasks =
      ref.watch(deletedTasksProvider).valueOrNull ?? const <HouseholdTask>[];
  final lists =
      ref.watch(deletedTaskListsProvider).valueOrNull ?? const <TaskList>[];
  final items = <TrashItem>[
    for (final e in expenses)
      if (e.deletedAt != null)
        TrashItem(
          kind: TrashKind.expense,
          id: e.id,
          title: e.description,
          deletedAt: e.deletedAt!,
          subtitle: MoneyFormat.fromCents(e.amountDueCents),
        ),
    for (final t in transfers)
      if (t.deletedAt != null)
        TrashItem(
          kind: TrashKind.transfer,
          id: t.id,
          title: 'Bonifico ${MoneyFormat.fromCents(t.amountCents)}',
          deletedAt: t.deletedAt!,
        ),
    for (final t in tasks)
      if (t.deletedAt != null && t.isVisibleTo(uid))
        TrashItem(
          kind: TrashKind.task,
          id: t.id,
          title: t.title,
          deletedAt: t.deletedAt!,
        ),
    for (final l in lists)
      if (l.deletedAt != null && l.isVisibleTo(uid))
        TrashItem(
          kind: TrashKind.taskList,
          id: l.id,
          title: l.name,
          deletedAt: l.deletedAt!,
          subtitle: 'Lista',
        ),
  ]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  return items;
});
