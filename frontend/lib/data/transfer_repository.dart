import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import 'activity_models.dart';
import 'activity_repository.dart';
import 'transfer_models.dart';
import 'trash_models.dart';

class TransferRepository {
  TransferRepository({
    FirebaseFirestore? firestore,
    this.activity,
  }) : _db = firestore;

  final FirebaseFirestore? _db;
  final ActivityRepository? activity;
  final _uuid = const Uuid();
  final _memory = <String, Transfer>{};
  final _memoryCtrl = StreamController<List<Transfer>>.broadcast();
  final _deletedCtrl = StreamController<List<Transfer>>.broadcast();

  bool get _live => _db != null;

  CollectionReference<Map<String, dynamic>> get _col => _db!
      .collection('households')
      .doc(AppConfig.householdId)
      .collection('transfers');

  Stream<List<Transfer>> watchTransfers() {
    if (!_live) {
      return Stream<List<Transfer>>.multi((listener) {
        listener.add(_activeMemory());
        final sub = _memoryCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => Transfer.fromDoc(d.id, d.data()))
          .where((t) => !t.isDeleted)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Stream<List<Transfer>> watchDeleted({DateTime? now}) {
    List<Transfer> pick(Iterable<Transfer> all) {
      final stamp = now ?? DateTime.now();
      return all
          .where((t) => withinTrashRetention(t.deletedAt, now: stamp))
          .toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    }

    if (!_live) {
      return Stream<List<Transfer>>.multi((listener) {
        listener.add(pick(_memory.values));
        final sub = _deletedCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map(
          (snap) => pick(snap.docs.map((d) => Transfer.fromDoc(d.id, d.data()))),
        );
  }

  Future<Transfer> save({
    required Transfer draft,
    required String actorUid,
  }) async {
    final isCreate = draft.id.isEmpty;
    final id = isCreate ? _uuid.v4() : draft.id;
    final withId = Transfer(
      id: id,
      fromUid: draft.fromUid,
      toUid: draft.toUid,
      amountCents: draft.amountCents,
      date: draft.date,
      note: draft.note?.trim().isEmpty == true ? null : draft.note?.trim(),
      source: draft.source,
      importRow: draft.importRow,
      createdBy: isCreate ? actorUid : draft.createdBy,
      createdAt: draft.createdAt,
      updatedBy: actorUid,
      deletedAt: draft.deletedAt,
    );

    if (!_live) {
      _memory[id] = withId;
      _emitMemory();
      if (isCreate) {
        await _log(
          ActivityType.transferCreated,
          id,
          actorUid,
          'Ha registrato un bonifico',
        );
      }
      return withId;
    }

    await _col.doc(id).set(
          withId.toMap(isCreate: isCreate),
          SetOptions(merge: true),
        );
    if (isCreate) {
      await _log(
        ActivityType.transferCreated,
        id,
        actorUid,
        'Ha registrato un bonifico',
      );
    }
    return withId;
  }

  Future<void> softDelete(String id, String actorUid) async {
    if (!_live) {
      final current = _memory[id];
      if (current == null) return;
      _memory[id] = current.copyWith(deletedAt: DateTime.now());
      _emitMemory();
      await _log(
        ActivityType.transferDeleted,
        id,
        actorUid,
        'Ha messo un bonifico nel cestino',
      );
      return;
    }
    await _col.doc(id).set({
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(
      ActivityType.transferDeleted,
      id,
      actorUid,
      'Ha messo un bonifico nel cestino',
    );
  }

  Future<List<Transfer>> fetchAll() async {
    if (!_live) return _memory.values.toList();
    final snap = await _col.get();
    return snap.docs.map((d) => Transfer.fromDoc(d.id, d.data())).toList();
  }

  Future<int> retireMany(Iterable<String> ids, String actorUid) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return 0;
    final stamp = DateTime.now().subtract(const Duration(days: 31));
    var n = 0;
    if (!_live) {
      for (final id in unique) {
        final current = _memory[id];
        if (current == null || current.isDeleted) continue;
        _memory[id] = current.copyWith(deletedAt: stamp);
        n++;
      }
      if (n > 0) _emitMemory();
      return n;
    }
    const chunk = 400;
    final list = unique.toList();
    for (var i = 0; i < list.length; i += chunk) {
      final batch = _db!.batch();
      final end = i + chunk > list.length ? list.length : i + chunk;
      for (final id in list.sublist(i, end)) {
        batch.set(
          _col.doc(id),
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

  Future<void> saveImported(List<Transfer> items) async {
    if (items.isEmpty) return;
    if (!_live) {
      for (final t in items) {
        _memory[t.id] = t;
      }
      _emitMemory();
      return;
    }
    const chunk = 400;
    for (var i = 0; i < items.length; i += chunk) {
      final batch = _db!.batch();
      final end = i + chunk > items.length ? items.length : i + chunk;
      for (final t in items.sublist(i, end)) {
        batch.set(
          _col.doc(t.id),
          t.toMap(isCreate: true),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> restore(String id, String actorUid) async {
    if (!_live) {
      final current = _memory[id];
      if (current == null) return;
      _memory[id] = current.copyWith(clearDeletedAt: true);
      _emitMemory();
      await _log(
        ActivityType.transferRestored,
        id,
        actorUid,
        'Ha ripristinato un bonifico',
      );
      return;
    }
    await _col.doc(id).set({
      'deletedAt': null,
      'updatedBy': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(
      ActivityType.transferRestored,
      id,
      actorUid,
      'Ha ripristinato un bonifico',
    );
  }

  List<Transfer> _activeMemory() =>
      _memory.values.where((t) => !t.isDeleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Transfer> _deletedMemory() => _memory.values
      .where((t) => withinTrashRetention(t.deletedAt))
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
  }
}
