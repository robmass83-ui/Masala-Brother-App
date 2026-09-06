import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import 'activity_models.dart';
import 'activity_repository.dart';
import 'expense_models.dart';
import 'trash_models.dart';

class ExpenseRepository {
  ExpenseRepository({
    FirebaseFirestore? firestore,
    this.activity,
  }) : _db = firestore;

  final FirebaseFirestore? _db;
  final ActivityRepository? activity;
  final _uuid = const Uuid();
  final _memory = <String, Expense>{};
  final _memoryCtrl = StreamController<List<Expense>>.broadcast();
  final _deletedCtrl = StreamController<List<Expense>>.broadcast();

  bool get _live => _db != null;

  CollectionReference<Map<String, dynamic>> get _col => _db!
      .collection('households')
      .doc(AppConfig.householdId)
      .collection('expenses');

  Stream<List<Expense>> watchExpenses() {
    if (!_live) {
      return Stream<List<Expense>>.multi((listener) {
        listener.add(_activeMemory());
        final sub = _memoryCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => Expense.fromDoc(d.id, d.data()))
          .where((e) => !e.isDeleted)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Stream<Expense?> watchExpense(String id) {
    if (!_live) {
      return watchExpenses().map((list) {
        try {
          return list.firstWhere((e) => e.id == id);
        } catch (_) {
          return _memory[id];
        }
      });
    }
    return _col.doc(id).snapshots().map((d) {
      if (!d.exists || d.data() == null) return null;
      final e = Expense.fromDoc(d.id, d.data()!);
      return e.isDeleted ? null : e;
    });
  }

  Stream<List<Expense>> watchDeleted({DateTime? now}) {
    List<Expense> pick(Iterable<Expense> all) {
      final stamp = now ?? DateTime.now();
      return all.where((e) => withinTrashRetention(e.deletedAt, now: stamp)).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    }

    if (!_live) {
      return Stream<List<Expense>>.multi((listener) {
        listener.add(pick(_memory.values));
        final sub = _deletedCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map(
          (snap) => pick(snap.docs.map((d) => Expense.fromDoc(d.id, d.data()))),
        );
  }

  Future<Expense> save({
    required Expense draft,
    required String actorUid,
    required String robUid,
    required String lauUid,
  }) async {
    final isCreate = draft.id.isEmpty;
    final id = isCreate ? _uuid.v4() : draft.id;
    final withId = Expense(
      id: id,
      description: draft.description.trim(),
      amountDueCents: draft.amountDueCents,
      date: draft.date,
      categoryId: draft.categoryId,
      propertyId: draft.propertyId,
      shareRobPct: draft.shareRobPct,
      payments: draft.payments,
      notes: draft.notes,
      source: draft.source,
      importRow: draft.importRow,
      dateEstimated: draft.dateEstimated,
      createdBy: isCreate ? actorUid : draft.createdBy,
      createdAt: draft.createdAt,
      updatedBy: actorUid,
      deletedAt: draft.deletedAt,
    ).withTotals(robUid: robUid, lauUid: lauUid);

    if (!_live) {
      _memory[id] = withId;
      _emitMemory();
      await _log(
        isCreate ? ActivityType.expenseCreated : ActivityType.expenseUpdated,
        id,
        actorUid,
        isCreate
            ? 'Ha aggiunto “${withId.description}”'
            : 'Ha modificato “${withId.description}”',
      );
      return withId;
    }

    await _col.doc(id).set(withId.toMap(isCreate: isCreate), SetOptions(merge: true));
    await _log(
      isCreate ? ActivityType.expenseCreated : ActivityType.expenseUpdated,
      id,
      actorUid,
      isCreate
          ? 'Ha aggiunto “${withId.description}”'
          : 'Ha modificato “${withId.description}”',
    );
    return withId;
  }

  Future<void> softDelete(String id, String actorUid) async {
    final title = _titleOf(id);
    if (!_live) {
      final current = _memory[id];
      if (current == null) return;
      _memory[id] = current.copyWith(deletedAt: DateTime.now());
      _emitMemory();
      await _log(
        ActivityType.expenseDeleted,
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
      ActivityType.expenseDeleted,
      id,
      actorUid,
      'Ha messo nel cestino “$title”',
    );
  }

  Future<void> restore(String id, String actorUid) async {
    final title = _titleOf(id);
    if (!_live) {
      final current = _memory[id];
      if (current == null) return;
      _memory[id] = current.copyWith(clearDeletedAt: true);
      _emitMemory();
      await _log(
        ActivityType.expenseRestored,
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
      ActivityType.expenseRestored,
      id,
      actorUid,
      'Ha ripristinato “$title”',
    );
  }

  Future<Expense> addPayment({
    required Expense expense,
    required ExpensePayment payment,
    required String actorUid,
    required String robUid,
    required String lauUid,
  }) {
    return save(
      draft: expense.copyWith(payments: [...expense.payments, payment]),
      actorUid: actorUid,
      robUid: robUid,
      lauUid: lauUid,
    );
  }

  Future<Expense> addPayments({
    required Expense expense,
    required List<({String payerUid, int amountCents})> parts,
    required String actorUid,
    required String robUid,
    required String lauUid,
  }) async {
    var current = expense;
    for (final part in parts) {
      if (part.amountCents <= 0) continue;
      current = await addPayment(
        expense: current,
        payment: newPayment(
          payerUid: part.payerUid,
          amountCents: part.amountCents,
        ),
        actorUid: actorUid,
        robUid: robUid,
        lauUid: lauUid,
      );
    }
    return current;
  }

  Future<Expense> removePayment({
    required Expense expense,
    required String paymentId,
    required String actorUid,
    required String robUid,
    required String lauUid,
  }) {
    return save(
      draft: expense.copyWith(
        payments: expense.payments.where((p) => p.id != paymentId).toList(),
      ),
      actorUid: actorUid,
      robUid: robUid,
      lauUid: lauUid,
    );
  }

  Future<List<Expense>> fetchAll() async {
    if (!_live) return _memory.values.toList();
    final snap = await _col.get();
    return snap.docs.map((d) => Expense.fromDoc(d.id, d.data())).toList();
  }

  /// Soft-deletes without filling the trash (deleted 31+ days ago).
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

  Future<void> saveImported(List<Expense> items) async {
    if (items.isEmpty) return;
    if (!_live) {
      for (final e in items) {
        _memory[e.id] = e;
      }
      _emitMemory();
      return;
    }
    const chunk = 400;
    for (var i = 0; i < items.length; i += chunk) {
      final batch = _db!.batch();
      final end = i + chunk > items.length ? items.length : i + chunk;
      for (final e in items.sublist(i, end)) {
        batch.set(
          _col.doc(e.id),
          e.toMap(isCreate: true),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  ExpensePayment newPayment({
    required String payerUid,
    required int amountCents,
    DateTime? date,
    PaymentMethod method = PaymentMethod.altro,
    String? note,
  }) {
    return ExpensePayment(
      id: _uuid.v4(),
      payerUid: payerUid,
      amountCents: amountCents,
      date: date ?? DateTime.now(),
      method: method,
      note: note,
    );
  }

  List<Expense> _activeMemory() =>
      _memory.values.where((e) => !e.isDeleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Expense> _deletedMemory() => _memory.values
      .where((e) => withinTrashRetention(e.deletedAt))
      .toList()
    ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  void _emitMemory() {
    _memoryCtrl.add(_activeMemory());
    _deletedCtrl.add(_deletedMemory());
  }

  String _titleOf(String id) => _memory[id]?.description ?? 'spesa';

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
