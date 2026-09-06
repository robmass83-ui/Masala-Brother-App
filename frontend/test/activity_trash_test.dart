import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/activity_models.dart';
import 'package:brotherapp/data/activity_repository.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/expense_repository.dart';
import 'package:brotherapp/data/task_models.dart';
import 'package:brotherapp/data/task_repository.dart';

void main() {
  test('expense save and restore appear in activity and trash', () async {
    final activity = ActivityRepository();
    final expenses = ExpenseRepository(activity: activity);
    addTearDown(activity.dispose);
    addTearDown(expenses.dispose);

    final saved = await expenses.save(
      draft: Expense(
        id: '',
        description: 'Bolletta luce',
        amountDueCents: 12000,
        date: DateTime(2026, 9, 1),
        categoryId: 'bollette',
      ),
      actorUid: 'rob',
      robUid: 'rob',
      lauUid: 'lau',
    );

    var log = await activity.watchActivity().first;
    expect(log.single.type, ActivityType.expenseCreated);
    expect(log.single.summary, contains('Bolletta luce'));

    await expenses.softDelete(saved.id, 'rob');
    expect((await expenses.watchExpenses().first), isEmpty);
    final trash = await expenses.watchDeleted().first;
    expect(trash.single.id, saved.id);

    await expenses.restore(saved.id, 'lau');
    expect((await expenses.watchExpenses().first).single.id, saved.id);
    expect((await expenses.watchDeleted().first), isEmpty);
    log = await activity.watchActivity().first;
    expect(log.first.type, ActivityType.expenseRestored);
  });

  test('task setDone logs done not a generic update', () async {
    final activity = ActivityRepository();
    final tasks = TaskRepository(activity: activity);
    addTearDown(activity.dispose);
    addTearDown(tasks.dispose);

    final saved = await tasks.save(
      draft: const HouseholdTask(id: '', title: 'Chiamare notaio'),
      actorUid: 'lau',
    );
    await tasks.setDone(task: saved, done: true, actorUid: 'lau');
    final log = await activity.watchActivity().first;
    expect(
      log.map((e) => e.type),
      containsAll([ActivityType.taskCreated, ActivityType.taskDone]),
    );
    expect(log.any((e) => e.type == ActivityType.taskUpdated), isFalse);
  });
}
