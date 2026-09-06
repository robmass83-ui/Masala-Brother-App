import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ActivityType {
  expenseCreated,
  expenseUpdated,
  expenseDeleted,
  expenseRestored,
  transferCreated,
  transferDeleted,
  transferRestored,
  taskCreated,
  taskUpdated,
  taskDone,
  taskReopened,
  taskDeleted,
  taskRestored,
  catalogChanged,
  excelImported,
}

@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.type,
    required this.refId,
    required this.byUid,
    required this.at,
    required this.summary,
  });

  final String id;
  final ActivityType type;
  final String refId;
  final String byUid;
  final DateTime at;
  final String summary;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'refId': refId,
        'byUid': byUid,
        'at': Timestamp.fromDate(at),
        'summary': summary,
      };

  factory ActivityEntry.fromDoc(String id, Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? '';
    return ActivityEntry(
      id: id,
      type: ActivityType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => ActivityType.catalogChanged,
      ),
      refId: map['refId'] as String? ?? '',
      byUid: map['byUid'] as String? ?? '',
      at: _readDate(map['at']) ?? DateTime.now(),
      summary: map['summary'] as String? ?? '',
    );
  }
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
