import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../../data/task_models.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';
import 'task_expense_flow.dart';
import 'task_list_dialog.dart';

enum _TaskFilter { aperte, fatte, tutte }

TaskListFilter _toListFilter(_TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.aperte => TaskListFilter.aperte,
    _TaskFilter.fatte => TaskListFilter.fatte,
    _TaskFilter.tutte => TaskListFilter.tutte,
  };
}

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.aperte;
  bool _managing = false;
  final _selected = <String>{};

  void _exitManage() {
    setState(() {
      _managing = false;
      _selected.clear();
    });
  }

  void _enterManage({String? listId}) {
    setState(() {
      _managing = true;
      _selected.clear();
      if (listId != null) _selected.add(listId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tasks = ref.watch(visibleTasksProvider);
    final lists = ref.watch(visibleTaskListsProvider);
    final expenses = {
      for (final e in ref.watch(expensesProvider).valueOrNull ?? const <Expense>[])
        e.id: e,
    };
    final household = ref.watch(authSessionProvider).valueOrNull?.household;
    final user = ref.watch(authSessionProvider).valueOrNull?.user;
    final uid = user?.uid;
    final sections = applyTaskListFilter(
      groupTasksByList(tasks: tasks, lists: lists, viewerUid: uid),
      _toListFilter(_filter),
    );
    final namedIds = [
      for (final s in sections)
        if (s.list != null) s.list!.id,
    ];
    final openCount = tasks.where((t) => !t.done).length;
    final doneCount = tasks.where((t) => t.done).length;
    final empty = tasks.isEmpty && lists.isEmpty;
    final hasNamedLists = lists.isNotEmpty;

    Widget taskRow(HouseholdTask t) {
      return _TaskRow(
        task: t,
        household: household,
        linkedExpense: t.linkedExpenseId == null
            ? null
            : expenses[t.linkedExpenseId],
        now: DateTime.now(),
        onToggle: user == null || _managing
            ? null
            : () => _toggle(t, user, household),
        onOpen: _managing ? () {} : () => context.push('/dafare/${t.id}'),
        onDelete: user == null || _managing
            ? null
            : () => _delete(t, user.uid),
      );
    }

    return PopScope(
      canPop: !_managing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _managing) _exitManage();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: _managing
              ? IconButton(
                  tooltip: 'Chiudi',
                  onPressed: _exitManage,
                  icon: const Icon(Icons.close),
                )
              : null,
          title: Text(
            _managing
                ? (_selected.isEmpty
                    ? 'Seleziona liste'
                    : '${_selected.length} selezionate')
                : 'Da fare',
          ),
          actions: [
            if (_managing)
              TextButton(
                onPressed: _selected.isEmpty || user == null
                    ? null
                    : () => _deleteSelected(user.uid, sections),
                child: Text(
                  'Elimina',
                  style: TextStyle(
                    color: _selected.isEmpty ? c.ink3 : c.due,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (hasNamedLists)
              TextButton(
                onPressed: () => _enterManage(),
                child: Text(
                  'Gestisci',
                  style: TextStyle(color: c.acc, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (!_managing) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterPill(
                    label: 'Aperte',
                    count: openCount,
                    selected: _filter == _TaskFilter.aperte,
                    tone: _PillTone.neutral,
                    onTap: () => setState(() => _filter = _TaskFilter.aperte),
                  ),
                  _FilterPill(
                    label: 'Fatte',
                    count: doneCount,
                    selected: _filter == _TaskFilter.fatte,
                    tone: _PillTone.ok,
                    onTap: () => setState(() => _filter = _TaskFilter.fatte),
                  ),
                  _FilterPill(
                    label: 'Tutte',
                    selected: _filter == _TaskFilter.tutte,
                    tone: _PillTone.neutral,
                    onTap: () => setState(() => _filter = _TaskFilter.tutte),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tocca le liste da togliere, anche più di una.',
                      style: TextStyle(
                        color: c.ink2,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: namedIds.isEmpty
                        ? null
                        : () => setState(() {
                              if (_selected.length == namedIds.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(namedIds);
                              }
                            }),
                    child: Text(
                      _selected.length == namedIds.length && namedIds.isNotEmpty
                          ? 'Nessuna'
                          : 'Tutte',
                      style: TextStyle(
                        color: c.acc,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (empty)
              EmptyState(
                message:
                    'Niente in elenco. Tocca + in basso per una cosa da fare, oppure crea una lista (es. Campagna).',
                actionLabel: 'Nuova lista',
                onAction: () => showCreateTaskListDialog(context, ref),
              )
            else
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _Section(
                  title: sections[i].list?.name ?? 'Senza lista',
                  subtitle: sections[i].list == null
                      ? null
                      : (sections[i].list!.isPersonal
                          ? 'Solo tue · non la vede l’altra persona'
                          : 'Condivisa'),
                  titleColor: sections[i].list == null ? c.ink3 : c.ink,
                  selected: sections[i].list != null &&
                      _selected.contains(sections[i].list!.id),
                  managing: _managing && sections[i].list != null,
                  onAdd: sections[i].list == null || _managing
                      ? null
                      : () => context.push(
                            '/dafare/nuova',
                            extra: {'listId': sections[i].list!.id},
                          ),
                  onLongPress: sections[i].list == null || _managing
                      ? null
                      : () => _enterManage(listId: sections[i].list!.id),
                  onToggleSelect: sections[i].list == null || !_managing
                      ? null
                      : () => setState(() {
                            final id = sections[i].list!.id;
                            if (!_selected.remove(id)) _selected.add(id);
                          }),
                  onDeleteList: sections[i].list == null ||
                          _managing ||
                          user == null ||
                          sections[i].items.isNotEmpty
                      ? null
                      : () => _deleteSelected(user.uid, [sections[i]]),
                  children: [
                    if (sections[i].items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _managing
                              ? 'Lista vuota'
                              : 'Ancora niente. Tocca Aggiungi oppure il + in basso.',
                          style: TextStyle(
                            color: c.ink2,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      for (final t in sections[i].items) taskRow(t),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(
    HouseholdTask task,
    AppUser user,
    Household? household,
  ) async {
    final repo = ref.read(taskRepositoryProvider);
    final markingDone = !task.done;
    await repo.setDone(task: task, done: markingDone, actorUid: user.uid);
    if (!mounted) return;

    if (markingDone && task.createExpenseOnDone) {
      await pushExpenseForTask(
        context,
        task: task,
        fromCompletion: true,
        household: household,
        actorUid: user.uid,
      );
      return;
    }

    showUndoSnackBar(
      context,
      message: markingDone ? 'Segnata come fatta' : 'Rimessa tra le aperte',
      onUndo: () {
        repo.setDone(task: task, done: !markingDone, actorUid: user.uid);
      },
    );
  }

  Future<void> _delete(HouseholdTask task, String uid) async {
    await ref.read(taskRepositoryProvider).softDelete(task.id, uid);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Cosa da fare eliminata',
      onUndo: () {
        ref.read(taskRepositoryProvider).restore(task.id, uid);
      },
    );
  }

  Future<void> _deleteSelected(
    String uid,
    List<TaskListSection> sections,
  ) async {
    final byId = {
      for (final s in sections)
        if (s.list != null) s.list!.id: s.list!,
    };
    final chosen = [
      for (final id in _managing ? _selected : byId.keys)
        if (byId[id] != null) byId[id]!,
    ];
    if (chosen.isEmpty) return;

    final names = chosen.map((l) => l.name).join(', ');
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          chosen.length == 1 ? 'Eliminare questa lista?' : 'Eliminare queste liste?',
          style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          chosen.length == 1
              ? '«${chosen.first.name}» sparisce. Le cose da fare restano, senza lista.'
              : '$names. Le cose da fare restano, senza lista.',
          style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: c.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Elimina', style: TextStyle(color: c.due, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ids = chosen.map((l) => l.id).toList();
    await ref.read(taskRepositoryProvider).softDeleteLists(ids, uid);
    if (!mounted) return;
    _exitManage();
  }
}

enum _PillTone { ok, neutral }

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.tone,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final _PillTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color bg;
    final Color fg;
    if (selected) {
      bg = c.ink;
      fg = c.bg;
    } else if (tone == _PillTone.ok) {
      bg = c.okSoft;
      fg = c.ok;
    } else {
      bg = c.line;
      fg = c.ink2;
    }
    final text = count == null ? label : '$label · $count';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.titleColor,
    required this.children,
    this.subtitle,
    this.onAdd,
    this.onLongPress,
    this.onToggleSelect,
    this.onDeleteList,
    this.managing = false,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Color titleColor;
  final List<Widget> children;
  final VoidCallback? onAdd;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onDeleteList;
  final bool managing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      onTap: onToggleSelect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (managing) ...[
                _ListCheck(selected: selected),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.06,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink3,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (onAdd != null)
                TextButton(
                  onPressed: onAdd,
                  child: Text(
                    'Aggiungi',
                    style: TextStyle(
                      color: c.acc,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (onDeleteList != null)
                IconButton(
                  tooltip: 'Elimina lista',
                  onPressed: onDeleteList,
                  icon: Icon(Icons.delete_outline, color: c.ink3),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: selected
                  ? Border.all(color: c.acc, width: 1.5)
                  : Border.all(color: const Color(0x00000000), width: 1.5),
            ),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: c.line),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCheck extends StatelessWidget {
  const _ListCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.acc : null,
        borderRadius: BorderRadius.circular(8),
        border: selected ? null : Border.all(color: c.ink3, width: 2),
      ),
      child: selected
          ? Icon(Icons.check, size: 16, color: c.onAcc)
          : const SizedBox.shrink(),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.household,
    required this.linkedExpense,
    required this.now,
    required this.onToggle,
    required this.onOpen,
    this.onDelete,
  });

  final HouseholdTask task;
  final Household? household;
  final Expense? linkedExpense;
  final DateTime now;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kind = taskDueKind(task, now: now);
    final dueColor = switch (kind) {
      TaskDueKind.overdue => c.due,
      TaskDueKind.dueSoon => c.warn,
      TaskDueKind.upcoming => c.ink2,
      TaskDueKind.none => c.ink2,
    };

    String subtitle;
    Color subColor = c.ink2;
    if (task.done) {
      final who = _assigneeName(household, task.doneBy) ?? 'qualcuno';
      final when = task.doneAt ?? task.updatedAt;
      subtitle = [
        'Fatta da $who',
        if (when != null) AppDateFormat.formatDayMonth(when),
      ].join(' · ');
    } else if (task.dueDate != null) {
      subtitle = [
        'Scade ${AppDateFormat.formatDayMonth(task.dueDate!)}',
        if (linkedExpense != null)
          MoneyFormat.fromCents(linkedExpense!.amountDueCents),
      ].join(' · ');
      subColor = dueColor;
    } else {
      subtitle = linkedExpense == null
          ? 'Senza scadenza'
          : MoneyFormat.fromCents(linkedExpense!.amountDueCents);
    }

    final person = _personKey(household, task.assigneeUid);

    return Dismissible(
      key: ValueKey(task.id),
      direction: onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: c.dueSoft,
        child: Text(
          'Elimina',
          style: TextStyle(color: c.due, fontWeight: FontWeight.w800),
        ),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminare questa cosa da fare?'),
            content: const Text(
              'Verrà nascosta. La spesa collegata, se c’è, resta in elenco.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        );
        if (ok == true) onDelete?.call();
        return false;
      },
      child: InkWell(
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _CheckBox(done: task.done, onTap: onToggle),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: task.done ? c.ink3 : c.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.25,
                        decoration:
                            task.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PersonAvatar(
                person: person,
                empty: person == null,
                size: 30,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.done, required this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? c.acc : null,
          borderRadius: BorderRadius.circular(9),
          border: done ? null : Border.all(color: c.ink3, width: 2),
        ),
        child: done
            ? Icon(Icons.check, size: 18, color: c.onAcc)
            : const SizedBox.shrink(),
      ),
    );
  }
}

PersonKey? _personKey(Household? household, String? uid) {
  if (household == null || uid == null) return null;
  if (uid == household.robUid) return PersonKey.rob;
  if (uid == household.lauUid) return PersonKey.lau;
  return null;
}

String? _assigneeName(Household? household, String? uid) {
  if (household == null || uid == null) return null;
  return household.memberByUid(uid)?.name ??
      (uid == household.robUid
          ? 'Roberto'
          : uid == household.lauUid
              ? 'Laura'
              : null);
}
