import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/task_models.dart';
import 'package:brotherapp/data/task_repository.dart';

void main() {
  test('in-memory repository save, done, undo, soft delete', () async {
    final repo = TaskRepository();
    addTearDown(repo.dispose);

    final lengths = <int>[];
    final sub = repo.watchTasks().listen((list) => lengths.add(list.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(lengths.last, 0);

    final saved = await repo.save(
      draft: const HouseholdTask(
        id: '',
        title: 'Portare documenti al notaio',
        assigneeUid: 'demo-roberto',
        reminderDaysBefore: 1,
        createExpenseOnDone: true,
      ),
      actorUid: 'demo-roberto',
    );
    await pumpEventQueue();
    expect(saved.id, isNotEmpty);
    expect(lengths.last, 1);

    final done = await repo.setDone(
      task: saved,
      done: true,
      actorUid: 'demo-laura',
    );
    await pumpEventQueue();
    expect(done.done, isTrue);
    expect(done.doneBy, 'demo-laura');
    expect(done.doneAt, isNotNull);

    final reopened = await repo.setDone(
      task: done,
      done: false,
      actorUid: 'demo-laura',
    );
    await pumpEventQueue();
    expect(reopened.done, isFalse);
    expect(reopened.doneAt, isNull);
    expect(reopened.doneBy, isNull);

    await repo.softDelete(saved.id, 'demo-roberto');
    await pumpEventQueue();
    expect(lengths.last, 0);

    await repo.restore(saved.id, 'demo-roberto');
    await pumpEventQueue();
    expect(lengths.last, 1);
    expect(
      (await repo.watchTasks().first).single.createExpenseOnDone,
      isTrue,
    );
  });

  test('saveList and task listId stay in memory', () async {
    final repo = TaskRepository();
    addTearDown(repo.dispose);

    final list = await repo.saveList(
      draft: const TaskList(
        id: '',
        name: 'Campagna',
        ownerUid: 'demo-roberto',
      ),
      actorUid: 'demo-roberto',
    );
    expect(list.id, isNotEmpty);
    expect(list.isPersonal, isTrue);

    final task = await repo.save(
      draft: HouseholdTask(
        id: '',
        title: 'Comprare la terra',
        listId: list.id,
        listOwnerUid: list.ownerUid,
      ),
      actorUid: 'demo-roberto',
    );
    expect(task.listId, list.id);
    expect(task.listOwnerUid, 'demo-roberto');
    expect(task.isVisibleTo('demo-laura'), isFalse);
    expect((await repo.watchLists().first).single.name, 'Campagna');
  });

  test('soft-delete lists and restore several at once', () async {
    final repo = TaskRepository();
    addTearDown(repo.dispose);

    final a = await repo.saveList(
      draft: const TaskList(id: '', name: 'Appartamento'),
      actorUid: 'demo-roberto',
    );
    final b = await repo.saveList(
      draft: const TaskList(id: '', name: 'Campagna'),
      actorUid: 'demo-roberto',
    );
    await pumpEventQueue();
    expect((await repo.watchLists().first).length, 2);

    await repo.softDeleteLists([a.id, b.id], 'demo-roberto');
    await pumpEventQueue();
    expect((await repo.watchLists().first), isEmpty);

    await repo.restoreLists([a.id, b.id], 'demo-roberto');
    await pumpEventQueue();
    expect(
      (await repo.watchLists().first).map((l) => l.name).toSet(),
      {'Appartamento', 'Campagna'},
    );
  });
}
