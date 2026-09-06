import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class HouseholdTask {
  const HouseholdTask({
    required this.id,
    required this.title,
    this.notes,
    this.assigneeUid,
    this.dueDate,
    this.reminderDaysBefore,
    this.propertyId,
    this.linkedExpenseId,
    this.createExpenseOnDone = false,
    this.done = false,
    this.doneAt,
    this.doneBy,
    this.listId,
    this.listOwnerUid,
    this.source = 'app',
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String? notes;
  final String? assigneeUid;
  final DateTime? dueDate;
  final int? reminderDaysBefore;
  final String? propertyId;
  final String? linkedExpenseId;
  final bool createExpenseOnDone;
  final bool done;
  final DateTime? doneAt;
  final String? doneBy;
  /// Parent list. Null = cosa da fare singola, fuori dalle liste.
  final String? listId;
  /// Denormalized from the list: null = visibile a entrambi.
  final String? listOwnerUid;
  final String source;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool get isPersonal => listOwnerUid != null && listOwnerUid!.isNotEmpty;

  /// Personal-list items are visible only to the owner. Shared / ungrouped are
  /// visible to both. A personal item can still create a shared expense.
  bool isVisibleTo(String? uid) => _ownedByOrShared(listOwnerUid, uid);

  HouseholdTask copyWith({
    String? title,
    String? notes,
    String? assigneeUid,
    DateTime? dueDate,
    int? reminderDaysBefore,
    String? propertyId,
    String? linkedExpenseId,
    bool? createExpenseOnDone,
    bool? done,
    DateTime? doneAt,
    String? doneBy,
    String? listId,
    String? listOwnerUid,
    DateTime? deletedAt,
    bool clearNotes = false,
    bool clearAssignee = false,
    bool clearDueDate = false,
    bool clearReminder = false,
    bool clearProperty = false,
    bool clearLinkedExpense = false,
    bool clearList = false,
    bool clearDeletedAt = false,
    bool clearDoneAt = false,
    bool clearDoneBy = false,
  }) {
    return HouseholdTask(
      id: id,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      assigneeUid: clearAssignee ? null : (assigneeUid ?? this.assigneeUid),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderDaysBefore:
          clearReminder ? null : (reminderDaysBefore ?? this.reminderDaysBefore),
      propertyId: clearProperty ? null : (propertyId ?? this.propertyId),
      linkedExpenseId:
          clearLinkedExpense ? null : (linkedExpenseId ?? this.linkedExpenseId),
      createExpenseOnDone: createExpenseOnDone ?? this.createExpenseOnDone,
      done: done ?? this.done,
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      doneBy: clearDoneBy ? null : (doneBy ?? this.doneBy),
      listId: clearList ? null : (listId ?? this.listId),
      listOwnerUid: clearList ? null : (listOwnerUid ?? this.listOwnerUid),
      source: source,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toMap({required bool isCreate}) {
    return {
      'title': title,
      'notes': notes,
      'assigneeUid': assigneeUid,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'reminderDaysBefore': reminderDaysBefore,
      'propertyId': propertyId,
      'linkedExpenseId': linkedExpenseId,
      'createExpenseOnDone': createExpenseOnDone,
      'done': done,
      'doneAt': doneAt == null ? null : Timestamp.fromDate(doneAt!),
      'doneBy': doneBy,
      'listId': listId,
      'listOwnerUid': listOwnerUid,
      'source': source,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      if (isCreate) 'createdBy': createdBy,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory HouseholdTask.fromDoc(String id, Map<String, dynamic> map) {
    return HouseholdTask(
      id: id,
      title: map['title'] as String? ?? '',
      notes: map['notes'] as String?,
      assigneeUid: map['assigneeUid'] as String?,
      dueDate: _readDate(map['dueDate']),
      reminderDaysBefore: (map['reminderDaysBefore'] as num?)?.toInt(),
      propertyId: map['propertyId'] as String?,
      linkedExpenseId: map['linkedExpenseId'] as String?,
      createExpenseOnDone: map['createExpenseOnDone'] as bool? ?? false,
      done: map['done'] as bool? ?? false,
      doneAt: _readDate(map['doneAt']),
      doneBy: map['doneBy'] as String?,
      listId: map['listId'] as String?,
      listOwnerUid: map['listOwnerUid'] as String?,
      source: map['source'] as String? ?? 'app',
      createdBy: map['createdBy'] as String?,
      createdAt: _readDate(map['createdAt']),
      updatedBy: map['updatedBy'] as String?,
      updatedAt: _readDate(map['updatedAt']),
      deletedAt: _readDate(map['deletedAt']),
    );
  }
}

/// A named group of things to do. [ownerUid] null = shared with both.
@immutable
class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    this.ownerUid,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  /// Null = visibile a Roberto e Laura. Altrimenti solo al creatore.
  final String? ownerUid;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool get isPersonal => ownerUid != null && ownerUid!.isNotEmpty;

  bool isVisibleTo(String? uid) => _ownedByOrShared(ownerUid, uid);

  TaskList copyWith({
    String? name,
    String? ownerUid,
    DateTime? deletedAt,
    bool clearOwner = false,
    bool clearDeletedAt = false,
  }) {
    return TaskList(
      id: id,
      name: name ?? this.name,
      ownerUid: clearOwner ? null : (ownerUid ?? this.ownerUid),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toMap({required bool isCreate}) {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      if (isCreate) 'createdBy': createdBy,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TaskList.fromDoc(String id, Map<String, dynamic> map) {
    return TaskList(
      id: id,
      name: map['name'] as String? ?? '',
      ownerUid: map['ownerUid'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt: _readDate(map['createdAt']),
      updatedBy: map['updatedBy'] as String?,
      updatedAt: _readDate(map['updatedAt']),
      deletedAt: _readDate(map['deletedAt']),
    );
  }
}

class TaskListSection {
  const TaskListSection({this.list, required this.items});

  /// Null = cose da fare senza lista.
  final TaskList? list;
  final List<HouseholdTask> items;

  bool get isUngrouped => list == null;
}

bool _ownedByOrShared(String? ownerUid, String? viewerUid) {
  if (ownerUid == null || ownerUid.isEmpty) return true;
  return viewerUid != null && ownerUid == viewerUid;
}

enum TaskDueKind { overdue, dueSoon, upcoming, none }

class TaskBuckets {
  const TaskBuckets({
    required this.overdueOrSoon,
    required this.upcoming,
    required this.undated,
    required this.recentlyDone,
  });

  final List<HouseholdTask> overdueOrSoon;
  final List<HouseholdTask> upcoming;
  final List<HouseholdTask> undated;
  final List<HouseholdTask> recentlyDone;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

TaskDueKind taskDueKind(HouseholdTask task, {required DateTime now}) {
  final due = task.dueDate;
  if (due == null) return TaskDueKind.none;
  final today = dateOnly(now);
  final dueDay = dateOnly(due);
  if (dueDay.isBefore(today)) return TaskDueKind.overdue;
  final horizon = today.add(const Duration(days: 7));
  if (!dueDay.isAfter(horizon)) return TaskDueKind.dueSoon;
  return TaskDueKind.upcoming;
}

TaskBuckets groupTasks(List<HouseholdTask> tasks, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final open = tasks.where((t) => !t.done).toList();
  final overdueOrSoon = <HouseholdTask>[];
  final upcoming = <HouseholdTask>[];
  final undated = <HouseholdTask>[];
  for (final t in open) {
    switch (taskDueKind(t, now: n)) {
      case TaskDueKind.overdue:
      case TaskDueKind.dueSoon:
        overdueOrSoon.add(t);
      case TaskDueKind.upcoming:
        upcoming.add(t);
      case TaskDueKind.none:
        undated.add(t);
    }
  }
  int byDue(HouseholdTask a, HouseholdTask b) {
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return a.title.compareTo(b.title);
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  overdueOrSoon.sort(byDue);
  upcoming.sort(byDue);
  undated.sort((a, b) => a.title.compareTo(b.title));

  final done = tasks.where((t) => t.done).toList()
    ..sort((a, b) {
      final ad = a.doneAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.doneAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

  return TaskBuckets(
    overdueOrSoon: overdueOrSoon,
    upcoming: upcoming,
    undated: undated,
    recentlyDone: done.take(10).toList(),
  );
}

/// Open items first (by due date), then done (most recently completed last
/// among the open-first rule: done sink to the bottom).
int compareOpenFirst(HouseholdTask a, HouseholdTask b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  if (!a.done) {
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return a.title.compareTo(b.title);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final byDue = ad.compareTo(bd);
    if (byDue != 0) return byDue;
    return a.title.compareTo(b.title);
  }
  final ad = a.doneAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bd = b.doneAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bd.compareTo(ad);
}

enum TaskListFilter { aperte, fatte, tutte }

/// Groups visible tasks under visible lists. Named lists (including empty)
/// come first, then ungrouped singles. Items in each section are open-first.
List<TaskListSection> groupTasksByList({
  required List<HouseholdTask> tasks,
  required List<TaskList> lists,
  required String? viewerUid,
}) {
  final visibleLists = lists
      .where((l) => !l.isDeleted && l.isVisibleTo(viewerUid))
      .toList()
    ..sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  final visibleTasks = tasks
      .where((t) => !t.isDeleted && t.isVisibleTo(viewerUid))
      .toList();
  final listIds = {for (final l in visibleLists) l.id};
  final byListId = <String, List<HouseholdTask>>{};
  final ungrouped = <HouseholdTask>[];
  for (final t in visibleTasks) {
    final lid = t.listId;
    if (lid != null && listIds.contains(lid)) {
      byListId.putIfAbsent(lid, () => []).add(t);
    } else {
      ungrouped.add(t);
    }
  }
  final sections = <TaskListSection>[
    for (final list in visibleLists)
      TaskListSection(
        list: list,
        items: (byListId[list.id] ?? [])..sort(compareOpenFirst),
      ),
  ];
  ungrouped.sort(compareOpenFirst);
  if (ungrouped.isNotEmpty) {
    sections.add(TaskListSection(items: ungrouped));
  }
  return sections;
}

List<TaskListSection> applyTaskListFilter(
  List<TaskListSection> sections,
  TaskListFilter filter,
) {
  switch (filter) {
    case TaskListFilter.aperte:
      return [
        for (final s in sections)
          if (s.list != null || s.items.any((t) => !t.done))
            TaskListSection(
              list: s.list,
              items: s.items.where((t) => !t.done).toList(),
            ),
      ];
    case TaskListFilter.fatte:
      return [
        for (final s in sections)
          if (s.items.any((t) => t.done))
            TaskListSection(
              list: s.list,
              items: s.items.where((t) => t.done).toList(),
            ),
      ];
    case TaskListFilter.tutte:
      return sections;
  }
}

/// 9:00 of (dueDate − daysBefore).
DateTime? reminderAt({
  required DateTime? dueDate,
  required int? reminderDaysBefore,
  int hour = 9,
}) {
  if (dueDate == null || reminderDaysBefore == null) return null;
  final dueDay = dateOnly(dueDate);
  final day = dueDay.subtract(Duration(days: reminderDaysBefore));
  return DateTime(day.year, day.month, day.day, hour);
}

String? taskValidationError({required String title, DateTime? dueDate}) {
  final t = title.trim();
  if (t.isEmpty) return 'Scrivi cosa c’è da fare';
  if (t.length > 200) return 'Massimo 200 caratteri';
  if (dueDate != null) {
    final max = DateTime.now().add(const Duration(days: 366));
    if (dueDate.isAfter(max)) {
      return 'La data non può essere oltre un anno';
    }
  }
  return null;
}

String? taskListValidationError(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'Scrivi il nome della lista';
  if (t.length > 80) return 'Massimo 80 caratteri';
  return null;
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
