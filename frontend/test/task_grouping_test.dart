import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/da_sistemare.dart';
import 'package:brotherapp/data/balance_calculator.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/task_models.dart';
import 'package:brotherapp/features/tasks/task_expense_flow.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);

  HouseholdTask task({
    required String id,
    required String title,
    DateTime? due,
    bool done = false,
    DateTime? doneAt,
  }) {
    return HouseholdTask(
      id: id,
      title: title,
      dueDate: due,
      done: done,
      doneAt: doneAt,
    );
  }

  test('taskDueKind splits overdue, 7-day window and later', () {
    expect(
      taskDueKind(task(id: '1', title: 'a', due: DateTime(2026, 9, 4)), now: now),
      TaskDueKind.overdue,
    );
    expect(
      taskDueKind(task(id: '2', title: 'b', due: DateTime(2026, 9, 5)), now: now),
      TaskDueKind.dueSoon,
    );
    expect(
      taskDueKind(task(id: '3', title: 'c', due: DateTime(2026, 9, 12)), now: now),
      TaskDueKind.dueSoon,
    );
    expect(
      taskDueKind(task(id: '4', title: 'd', due: DateTime(2026, 9, 13)), now: now),
      TaskDueKind.upcoming,
    );
    expect(
      taskDueKind(task(id: '5', title: 'e'), now: now),
      TaskDueKind.none,
    );
  });

  test('groupTasks fills the four buckets and keeps 10 recent done', () {
    final tasks = [
      task(id: 'o', title: 'Scaduta', due: DateTime(2026, 9, 1)),
      task(id: 's', title: 'Presto', due: DateTime(2026, 9, 10)),
      task(id: 'u', title: 'Dopo', due: DateTime(2026, 10, 1)),
      task(id: 'n', title: 'Senza'),
      for (var i = 0; i < 12; i++)
        task(
          id: 'd$i',
          title: 'Fatta $i',
          done: true,
          doneAt: DateTime(2026, 8, 1).add(Duration(days: i)),
        ),
    ];
    final buckets = groupTasks(tasks, now: now);
    expect(buckets.overdueOrSoon.map((t) => t.id), ['o', 's']);
    expect(buckets.upcoming.single.id, 'u');
    expect(buckets.undated.single.id, 'n');
    expect(buckets.recentlyDone.length, 10);
    expect(buckets.recentlyDone.first.id, 'd11');
  });

  test('reminderAt is 09:00 of due minus days', () {
    expect(
      reminderAt(
        dueDate: DateTime(2026, 9, 30, 18),
        reminderDaysBefore: 3,
      ),
      DateTime(2026, 9, 27, 9),
    );
    expect(
      reminderAt(dueDate: DateTime(2026, 9, 30), reminderDaysBefore: 0),
      DateTime(2026, 9, 30, 9),
    );
    expect(
      reminderAt(dueDate: DateTime(2026, 9, 30), reminderDaysBefore: null),
      isNull,
    );
    expect(
      reminderAt(
        dueDate: DateTime(2026, 9, 30),
        reminderDaysBefore: 0,
        hour: 7,
      ),
      DateTime(2026, 9, 30, 7),
    );
  });

  test('taskValidationError rejects empty and too-long titles', () {
    expect(taskValidationError(title: '  '), isNotNull);
    expect(taskValidationError(title: 'Pagare Tari'), isNull);
    expect(taskValidationError(title: 'x' * 201), isNotNull);
    expect(
      taskValidationError(
        title: 'Ok',
        dueDate: DateTime.now().add(const Duration(days: 400)),
      ),
      isNotNull,
    );
  });

  test('resolveLinkedExpenseId prefers the existing expense', () {
    expect(
      resolveLinkedExpenseId(formExpenseId: 'e1', taskLinkedExpenseId: 'e2'),
      'e1',
    );
    expect(
      resolveLinkedExpenseId(formExpenseId: '', taskLinkedExpenseId: 'e2'),
      'e2',
    );
    expect(resolveLinkedExpenseId(), isNull);
  });

  test('daSistemareItems mixes unpaid expenses and soon tasks, max 3', () {
    final expenses = [
      Expense(
        id: 'e1',
        description: 'Bolletta',
        amountDueCents: 1000,
        date: DateTime(2026, 9, 1),
        categoryId: 'bollette',
        status: ExpenseStatus.daPagare,
      ),
      Expense(
        id: 'e2',
        description: 'Già pagata',
        amountDueCents: 1000,
        date: DateTime(2026, 8, 1),
        categoryId: 'bollette',
        status: ExpenseStatus.pagato,
      ),
    ];
    final tasks = [
      task(id: 't1', title: 'Notaio', due: DateTime(2026, 9, 8)),
      task(id: 't2', title: 'Lontano', due: DateTime(2026, 12, 1)),
      task(id: 't3', title: 'Fatta', due: DateTime(2026, 9, 2), done: true),
    ];
    final items = daSistemareItems(
      expenses: expenses,
      tasks: tasks,
      now: now,
      limit: 3,
    );
    expect(items.length, 2);
    expect(items.first.expense?.id, 'e1');
    expect(items.last.task?.id, 't1');
  });

  test('personal list is hidden from the other person, shared items stay', () {
    const campagna = TaskList(
      id: 'c',
      name: 'Campagna',
      ownerUid: 'demo-roberto',
    );
    const casa = TaskList(id: 's', name: 'Casa');
    final tasks = [
      HouseholdTask(
        id: 'terra',
        title: 'Comprare la terra',
        listId: 'c',
        listOwnerUid: 'demo-roberto',
      ),
      HouseholdTask(
        id: 'lampadine',
        title: 'Lampadine',
        listId: 's',
      ),
      task(id: 'singola', title: 'Chiamare il notaio'),
    ];

    expect(
      HouseholdTask(
        id: 'terra',
        title: 'Comprare la terra',
        listId: 'c',
        listOwnerUid: 'demo-roberto',
      ).isVisibleTo('demo-laura'),
      isFalse,
    );
    expect(
      HouseholdTask(
        id: 'terra',
        title: 'Comprare la terra',
        listId: 'c',
        listOwnerUid: 'demo-roberto',
      ).isVisibleTo('demo-roberto'),
      isTrue,
    );

    final forRob = groupTasksByList(
      tasks: tasks,
      lists: const [campagna, casa],
      viewerUid: 'demo-roberto',
    );
    expect(forRob.map((s) => s.list?.name).toList(), ['Campagna', 'Casa', null]);
    expect(forRob.first.items.single.id, 'terra');

    final forLau = groupTasksByList(
      tasks: tasks,
      lists: const [campagna, casa],
      viewerUid: 'demo-laura',
    );
    expect(forLau.map((s) => s.list?.id).toList(), ['s', null]);
    expect(
      forLau.expand((s) => s.items).map((t) => t.id),
      isNot(contains('terra')),
    );
  });

  test('marking done sinks the item so open ones stay on top', () {
    const campagna = TaskList(id: 'c', name: 'Campagna');
    final tasks = [
      HouseholdTask(
        id: 'carriola',
        title: 'Comprare una carriola',
        listId: 'c',
        done: true,
        doneAt: DateTime(2026, 9, 5, 10),
      ),
      HouseholdTask(
        id: 'muratore',
        title: 'Andare dal muratore',
        listId: 'c',
      ),
      HouseholdTask(
        id: 'terra',
        title: 'Comprare la terra',
        listId: 'c',
        dueDate: DateTime(2026, 9, 10),
      ),
    ];
    final items = groupTasksByList(
      tasks: tasks,
      lists: const [campagna],
      viewerUid: 'demo-roberto',
    ).single.items;
    expect(items.map((t) => t.id).toList(), ['terra', 'muratore', 'carriola']);
  });

  test('taskListValidationError rejects empty names', () {
    expect(taskListValidationError('  '), isNotNull);
    expect(taskListValidationError('Campagna'), isNull);
    expect(taskListValidationError('x' * 81), isNotNull);
  });
}
