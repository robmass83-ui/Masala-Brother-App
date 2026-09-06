import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import 'activity_models.dart';
import 'activity_repository.dart';
import 'task_models.dart';
import 'trash_models.dart';

class TaskRepository {
  TaskRepository({
    FirebaseFirestore? firestore,
    this.activity,
  }) : _db = firestore;

  final FirebaseFirestore? _db;
  final ActivityRepository? activity;
  final _uuid = const Uuid();
  final _memory = <String, HouseholdTask>{};
  final _memoryCtrl = StreamController<List<HouseholdTask>>.broadcast();
  final _deletedCtrl = StreamController<List<HouseholdTask>>.broadcast();
  final _listMemory = <String, TaskList>{};
  final _listCtrl = StreamController<List<TaskList>>.broadcast();
  final _deletedListCtrl = StreamController<List<TaskList>>.broadcast();

  bool get _live => _db != null;

  CollectionReference<Map<String, dynamic>> get _col => _db!
      .collection('households')
      .doc(AppConfig.householdId)
      .collection('tasks');

  CollectionReference<Map<String, dynamic>> get _listCol => _db!
      .collection('households')
      .doc(AppConfig.householdId)
      .collection('taskLists');

  Stream<List<HouseholdTask>> watchTasks() {
    if (!_live) {
      return Stream<List<HouseholdTask>>.multi((listener) {
        listener.add(_activeMemory());
        final sub = _memoryCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => HouseholdTask.fromDoc(d.id, d.data()))
          .where((t) => !t.isDeleted)
          .toList();
      return items;
    });
  }

  Stream<List<HouseholdTask>> watchDeleted({DateTime? now}) {
    List<HouseholdTask> pick(Iterable<HouseholdTask> all) {
      final stamp = now ?? DateTime.now();
      return all
          .where((t) => withinTrashRetention(t.deletedAt, now: stamp))
          .toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    }

    if (!_live) {
      return Stream<List<HouseholdTask>>.multi((listener) {
        listener.add(pick(_memory.values));
        final sub = _deletedCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map(
          (snap) =>
              pick(snap.docs.map((d) => HouseholdTask.fromDoc(d.id, d.data()))),
        );
  }

  Stream<HouseholdTask?> watchTask(String id) {
    return watchTasks().map((list) {
      try {
        return list.firstWhere((t) => t.id == id);
      } catch (_) {
        return _memory[id];
      }
    });
  }

  Future<HouseholdTask> save({
    required HouseholdTask draft,
    required String actorUid,
    bool logActivity = true,
  }) async {
    final isCreate = draft.id.isEmpty;
    final id = isCreate ? _uuid.v4() : draft.id;
    final withId = HouseholdTask(
      id: id,
      title: draft.title.trim(),
      notes: draft.notes?.trim().isEmpty == true ? null : draft.notes?.trim(),
      assigneeUid: draft.assigneeUid,
      dueDate: draft.dueDate,
      reminderDaysBefore: draft.reminderDaysBefore,
      propertyId: draft.propertyId,
      linkedExpenseId: draft.linkedExpenseId,
      createExpenseOnDone: draft.createExpenseOnDone,
      done: draft.done,
      doneAt: draft.doneAt,
      doneBy: draft.doneBy,
      listId: draft.listId,
      listOwnerUid: draft.listOwnerUid,
      source: draft.source,
      createdBy: isCreate ? actorUid : draft.createdBy,
      createdAt: draft.createdAt,
      updatedBy: actorUid,
      deletedAt: draft.deletedAt,
    );

    if (!_live) {
      _memory[id] = withId;
      _emitMemory();
      if (logActivity) {
        await _log(
          isCreate ? ActivityType.taskCreated : ActivityType.taskUpdated,
          id,
          actorUid,
          isCreate
              ? 'Ha aggiunto “${withId.title}”'
              : 'Ha modificato “${withId.title}”',
        );
      }
      return withId;
    }

    await _col.doc(id).set(
          withId.toMap(isCreate: isCreate),
          SetOptions(merge: true),
        );
    if (logActivity) {
      await _log(
        isCreate ? ActivityType.taskCreated : ActivityType.taskUpdated,
        id,
        actorUid,
        isCreate
            ? 'Ha aggiunto “${withId.title}”'
            : 'Ha modificato “${withId.title}”',
      );
    }
    return withId;
  }

  Future<HouseholdTask> setDone({
    required HouseholdTask task,
    required bool done,
    required String actorUid,
  }) async {
    final saved = await save(
      draft: done
          ? task.copyWith(done: true, doneAt: DateTime.now(), doneBy: actorUid)
          : task.copyWith(
              done: false,
              clearDoneAt: true,
              clearDoneBy: true,
            ),
      actorUid: actorUid,
      logActivity: false,
    );
    await _log(
      done ? ActivityType.taskDone : ActivityType.taskReopened,
      saved.id,
      actorUid,
      done ? 'Ha segnato fatta “${saved.title}”' : 'Ha riaperto “${saved.title}”',
    );
    return saved;
  }

  Future<void> softDelete(String id, String actorUid) async {
    final title = _memory[id]?.title ?? 'cosa da fare';
    if (!_live) {
      final current = _memory[id];
      if (current == null) return;
      _memory[id] = current.copyWith(deletedAt: DateTime.now());
      _emitMemory();
      await _log(
        ActivityType.taskDeleted,
        id,
        actorUid,
        'Ha messo nel cestino “$title”',
      );
      return;
    }
    await _col.doc(id).set({
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(
      ActivityType.taskDeleted,
      id,
      actorUid,
      'Ha messo nel cestino “$title”',
    );
  }

  Future<void> restore(String id, String actorUid) async {
    final title = _memory[id]?.title ?? 'cosa da fare';
    if (!_live) {
      final current = _memory[id];
      if (current == null) return;
      _memory[id] = current.copyWith(clearDeletedAt: true);
      _emitMemory();
      await _log(
        ActivityType.taskRestored,
        id,
        actorUid,
        'Ha ripristinato “$title”',
      );
      return;
    }
    await _col.doc(id).set({
      'deletedAt': null,
      'updatedBy': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(
      ActivityType.taskRestored,
      id,
      actorUid,
      'Ha ripristinato “$title”',
    );
  }

  Stream<List<TaskList>> watchLists() {
    if (!_live) {
      return Stream<List<TaskList>>.multi((listener) {
        listener.add(_activeLists());
        final sub = _listCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _listCol.snapshots().map((snap) {
      return snap.docs
          .map((d) => TaskList.fromDoc(d.id, d.data()))
          .where((l) => !l.isDeleted)
          .toList();
    });
  }

  Stream<List<TaskList>> watchDeletedLists({DateTime? now}) {
    List<TaskList> pick(Iterable<TaskList> all) {
      final stamp = now ?? DateTime.now();
      return all
          .where((l) => withinTrashRetention(l.deletedAt, now: stamp))
          .toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    }

    if (!_live) {
      return Stream<List<TaskList>>.multi((listener) {
        listener.add(pick(_listMemory.values));
        final sub = _deletedListCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _listCol.snapshots().map(
          (snap) => pick(snap.docs.map((d) => TaskList.fromDoc(d.id, d.data()))),
        );
  }

  Future<TaskList> saveList({
    required TaskList draft,
    required String actorUid,
  }) async {
    final isCreate = draft.id.isEmpty;
    final id = isCreate ? _uuid.v4() : draft.id;
    final withId = TaskList(
      id: id,
      name: draft.name.trim(),
      ownerUid: draft.ownerUid,
      createdBy: isCreate ? actorUid : draft.createdBy,
      createdAt: draft.createdAt,
      updatedBy: actorUid,
      deletedAt: draft.deletedAt,
    );

    if (!_live) {
      _listMemory[id] = withId;
      _listCtrl.add(_activeLists());
      return withId;
    }

    await _listCol.doc(id).set(
          withId.toMap(isCreate: isCreate),
          SetOptions(merge: true),
        );
    return withId;
  }

  Future<void> softDeleteLists(Iterable<String> ids, String actorUid) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return;
    if (!_live) {
      var changed = false;
      for (final id in unique) {
        final current = _listMemory[id];
        if (current == null || current.isDeleted) continue;
        _listMemory[id] = current.copyWith(deletedAt: DateTime.now());
        changed = true;
      }
      if (changed) {
        _listCtrl.add(_activeLists());
        _deletedListCtrl.add(_deletedLists());
      }
      return;
    }
    final batch = _db!.batch();
    for (final id in unique) {
      batch.set(
        _listCol.doc(id),
        {
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> restoreLists(Iterable<String> ids, String actorUid) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return;
    if (!_live) {
      var changed = false;
      for (final id in unique) {
        final current = _listMemory[id];
        if (current == null) continue;
        _listMemory[id] = current.copyWith(clearDeletedAt: true);
        changed = true;
      }
      if (changed) {
        _listCtrl.add(_activeLists());
        _deletedListCtrl.add(_deletedLists());
      }
      return;
    }
    final batch = _db!.batch();
    for (final id in unique) {
      batch.set(
        _listCol.doc(id),
        {
          'deletedAt': null,
          'updatedBy': actorUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<List<HouseholdTask>> fetchAll() async {
    if (!_live) return _memory.values.toList();
    final snap = await _col.get();
    return snap.docs.map((d) => HouseholdTask.fromDoc(d.id, d.data())).toList();
  }

  Future<List<TaskList>> fetchAllLists() async {
    if (!_live) return _listMemory.values.toList();
    final snap = await _listCol.get();
    return snap.docs.map((d) => TaskList.fromDoc(d.id, d.data())).toList();
  }

  Future<int> retireMany(Iterable<String> ids, String actorUid) async {
    return _retire(
      ids,
      actorUid,
      memory: _memory,
      col: _live ? _col : null,
      apply: (current, stamp) => current.copyWith(deletedAt: stamp),
      emit: _emitMemory,
    );
  }

  Future<int> retireLists(Iterable<String> ids, String actorUid) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return 0;
    final stamp = DateTime.now().subtract(const Duration(days: 31));
    var n = 0;
    if (!_live) {
      for (final id in unique) {
        final current = _listMemory[id];
        if (current == null || current.isDeleted) continue;
        _listMemory[id] = current.copyWith(deletedAt: stamp);
        n++;
      }
      if (n > 0) {
        _listCtrl.add(_activeLists());
        _deletedListCtrl.add(_deletedLists());
      }
      return n;
    }
    const chunk = 400;
    final list = unique.toList();
    for (var i = 0; i < list.length; i += chunk) {
      final batch = _db!.batch();
      final end = i + chunk > list.length ? list.length : i + chunk;
      for (final id in list.sublist(i, end)) {
        batch.set(
          _listCol.doc(id),
          {
            'deletedAt': Timestamp.fromDate(stamp),
            'updatedBy': actorUid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        n++;
      }
      await batch.commit();
    }
    return n;
  }

  Future<int> _retire(
    Iterable<String> ids,
    String actorUid, {
    required Map<String, HouseholdTask> memory,
    required CollectionReference<Map<String, dynamic>>? col,
    required HouseholdTask Function(HouseholdTask current, DateTime stamp) apply,
    required void Function() emit,
  }) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return 0;
    final stamp = DateTime.now().subtract(const Duration(days: 31));
    var n = 0;
    if (col == null) {
      for (final id in unique) {
        final current = memory[id];
        if (current == null || current.isDeleted) continue;
        memory[id] = apply(current, stamp);
        n++;
      }
      if (n > 0) emit();
      return n;
    }
    const chunk = 400;
    final list = unique.toList();
    for (var i = 0; i < list.length; i += chunk) {
      final batch = _db!.batch();
      final end = i + chunk > list.length ? list.length : i + chunk;
      for (final id in list.sublist(i, end)) {
        batch.set(
          col.doc(id),
          {
            'deletedAt': Timestamp.fromDate(stamp),
            'updatedBy': actorUid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        n++;
      }
      await batch.commit();
    }
    return n;
  }

  List<HouseholdTask> _activeMemory() =>
      _memory.values.where((t) => !t.isDeleted).toList();

  List<HouseholdTask> _deletedMemory() => _memory.values
      .where((t) => withinTrashRetention(t.deletedAt))
      .toList()
    ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  List<TaskList> _activeLists() =>
      _listMemory.values.where((l) => !l.isDeleted).toList();

  List<TaskList> _deletedLists() => _listMemory.values
      .where((l) => withinTrashRetention(l.deletedAt))
      .toList()
    ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  void _emitMemory() {
    _memoryCtrl.add(_activeMemory());
    _deletedCtrl.add(_deletedMemory());
  }

  Future<void> _log(
    ActivityType type,
    String refId,
    String actorUid,
    String summary,
  ) async {
    await activity?.log(
      type: type,
      refId: refId,
      byUid: actorUid,
      summary: summary,
    );
  }

  void dispose() {
    _memoryCtrl.close();
    _deletedCtrl.close();
    _listCtrl.close();
    _deletedListCtrl.close();
  }
}
