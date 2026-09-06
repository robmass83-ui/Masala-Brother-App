import 'balance_calculator.dart';
import 'expense_models.dart';
import 'task_models.dart';

class DaSistemareItem {
  DaSistemareItem.expense(Expense expense)
      : expense = expense,
        task = null,
        sortDate = expense.date;

  DaSistemareItem.task(HouseholdTask task)
      : expense = null,
        task = task,
        sortDate = task.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);

  final Expense? expense;
  final HouseholdTask? task;
  final DateTime sortDate;
}

/// Unpaid/partial expenses plus open tasks due within 7 days (incl. overdue).
List<DaSistemareItem> daSistemareItems({
  required List<Expense> expenses,
  required List<HouseholdTask> tasks,
  DateTime? now,
  int limit = 3,
}) {
  final n = now ?? DateTime.now();
  final items = <DaSistemareItem>[
    for (final e in expenses)
      if (e.status != ExpenseStatus.pagato) DaSistemareItem.expense(e),
    for (final t in tasks)
      if (!t.done)
        if (taskDueKind(t, now: n) == TaskDueKind.overdue ||
            taskDueKind(t, now: n) == TaskDueKind.dueSoon)
          DaSistemareItem.task(t),
  ]..sort((a, b) => a.sortDate.compareTo(b.sortDate));
  if (items.length <= limit) return items;
  return items.take(limit).toList();
}
