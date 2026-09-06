import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import 'activity_models.dart';

class ActivityRepository {
  ActivityRepository({FirebaseFirestore? firestore}) : _db = firestore;

  final FirebaseFirestore? _db;
  final _uuid = const Uuid();
  final _memory = <String, ActivityEntry>{};
  final _memoryCtrl = StreamController<List<ActivityEntry>>.broadcast();

  bool get _live => _db != null;

  CollectionReference<Map<String, dynamic>> get _col => _db!
      .collection('households')
      .doc(AppConfig.householdId)
      .collection('activity');

  Stream<List<ActivityEntry>> watchActivity({int limit = 80}) {
    if (!_live) {
      return Stream<List<ActivityEntry>>.multi((listener) {
        listener.add(_sorted().take(limit).toList());
        final sub = _memoryCtrl.stream.listen((list) {
          listener.add(list.take(limit).toList());
        });
        listener.onCancel = sub.cancel;
      });
    }
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => ActivityEntry.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
      return items.take(limit).toList();
    });
  }

  Future<ActivityEntry> log({
    required ActivityType type,
    required String refId,
    required String byUid,
    required String summary,
    DateTime? at,
  }) async {
    final id = _uuid.v4();
    final entry = ActivityEntry(
      id: id,
      type: type,
      refId: refId,
      byUid: byUid,
      at: at ?? DateTime.now(),
      summary: summary,
    );
    if (!_live) {
      _memory[id] = entry;
      _memoryCtrl.add(_sorted());
      return entry;
    }
    await _col.doc(id).set(entry.toMap());
    return entry;
  }

  List<ActivityEntry> _sorted() => _memory.values.toList()
    ..sort((a, b) => b.at.compareTo(a.at));

  void dispose() => _memoryCtrl.close();
}
