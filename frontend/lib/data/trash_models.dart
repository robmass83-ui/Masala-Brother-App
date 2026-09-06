import 'package:flutter/foundation.dart';

enum TrashKind { expense, transfer, task, taskList }

@immutable
class TrashItem {
  const TrashItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.deletedAt,
    this.subtitle,
  });

  final TrashKind kind;
  final String id;
  final String title;
  final DateTime deletedAt;
  final String? subtitle;

  String get kindLabel => switch (kind) {
        TrashKind.expense => 'Spesa',
        TrashKind.transfer => 'Bonifico',
        TrashKind.task => 'Cosa da fare',
        TrashKind.taskList => 'Lista',
      };
}

bool withinTrashRetention(DateTime? deletedAt, {DateTime? now}) {
  if (deletedAt == null) return false;
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 30));
  return !deletedAt.isBefore(cutoff);
}
