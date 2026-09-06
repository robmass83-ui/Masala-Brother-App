import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/chip_wrap.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../../data/task_models.dart';
import '../auth/auth_providers.dart';
import 'task_expense_flow.dart';
import 'task_list_dialog.dart';

enum _Assignee { rob, lau, anyone }

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key, this.id, this.initialListId});

  final String? id;
  final String? initialListId;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _titleCtrl = TextEditingController();
  _Assignee _assignee = _Assignee.anyone;
  DateTime? _dueDate;
  int? _reminderDays;
  String? _propertyId;
  String? _listId;
  bool _createExpense = false;
  bool _loaded = false;
  bool _busy = false;
  HouseholdTask? _existing;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _listId = widget.initialListId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _fillFrom(HouseholdTask task) {
    _existing = task;
    _titleCtrl.text = task.title;
    _listId = task.listId;
    final household = ref.read(authSessionProvider).valueOrNull?.household;
    if (task.assigneeUid == null) {
      _assignee = _Assignee.anyone;
    } else if (household != null && task.assigneeUid == household.lauUid) {
      _assignee = _Assignee.lau;
    } else {
      _assignee = _Assignee.rob;
    }
    _dueDate = task.dueDate;
    _reminderDays = task.reminderDaysBefore;
    _propertyId = task.propertyId;
    _createExpense = task.createExpenseOnDone;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final props =
        ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[];
    if (_isEdit) {
      final existing = ref.watch(taskProvider(widget.id!)).valueOrNull;
      if (existing != null && !_loaded) {
        _fillFrom(existing);
        _loaded = true;
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifica' : 'Nuova cosa da fare'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isEdit)
            TextButton(
              onPressed: _busy ? null : _delete,
              child: Text('Elimina', style: TextStyle(color: c.due)),
            )
          else
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Annulla', style: TextStyle(color: c.ink3)),
            ),
        ],
      ),
      bottomNavigationBar: Material(
        color: c.bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: PrimaryButton(
            label: _busy
                ? 'Salvataggio…'
                : _isEdit
                    ? 'Salva'
                    : 'Aggiungi',
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _FieldLabel('Cosa'),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            autofocus: !_isEdit,
            minLines: 3,
            maxLines: 6,
            maxLength: 200,
            style: TextStyle(
              color: c.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: c.card,
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.line, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.acc, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _FieldLabel('Lista'),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final lists = ref.watch(visibleTaskListsProvider);
              final selected = [
                for (final l in lists)
                  if (l.id == _listId) l,
              ];
              final selectedList = selected.isEmpty ? null : selected.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipWrap(
                    children: [
                      _ChoiceChip(
                        label: 'Nessuna',
                        selected: _listId == null,
                        onTap: () => setState(() => _listId = null),
                      ),
                      for (final list in lists)
                        _ChoiceChip(
                          label: list.name,
                          selected: _listId == list.id,
                          onTap: () => setState(() => _listId = list.id),
                        ),
                      _ChoiceChip(
                        label: '+ Nuova lista',
                        selected: false,
                        onTap: () async {
                          final created =
                              await showCreateTaskListDialog(context, ref);
                          if (!mounted || created == null) return;
                          setState(() => _listId = created.id);
                        },
                      ),
                    ],
                  ),
                  if (selectedList != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      selectedList.isPersonal
                          ? 'Solo tu vedi questa lista. Se crei una spesa, quella può essere divisa in due.'
                          : 'Lista condivisa: la vede anche l’altra persona.',
                      style: TextStyle(
                        color: c.ink2,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _FieldLabel('Se ne occupa'),
          const SizedBox(height: 8),
          _AssigneePicker(
            value: _assignee,
            onChanged: (v) => setState(() => _assignee = v),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Scadenza'),
                    const SizedBox(height: 6),
                    _TappableField(
                      icon: Icons.calendar_today_outlined,
                      label: _dueDate == null
                          ? 'Opzionale'
                          : AppDateFormat.format(_dueDate!),
                      muted: _dueDate == null,
                      onTap: _pickDue,
                      onClear: _dueDate == null
                          ? null
                          : () => setState(() {
                                _dueDate = null;
                                _reminderDays = null;
                              }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Promemoria'),
                    const SizedBox(height: 6),
                    _TappableField(
                      icon: Icons.notifications_outlined,
                      label: _reminderLabel(_reminderDays),
                      muted: _reminderDays == null,
                      onTap: _pickReminder,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FieldLabel('Collegata a'),
          const SizedBox(height: 8),
          ChipWrap(
            children: [
              _ChoiceChip(
                label: 'Nessuno',
                selected: _propertyId == null,
                onTap: () => setState(() => _propertyId = null),
              ),
              for (final p in props)
                _ChoiceChip(
                  label: p.shortName,
                  selected: _propertyId == p.id,
                  onTap: () => setState(() => _propertyId = p.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.accSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.swap_horiz, color: c.acc),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crea anche la spesa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Quando la segni fatta, ti chiede l’importo. Anche da una lista solo tua la spesa può essere condivisa.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink2,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _createExpense,
                  onChanged: (v) => setState(() => _createExpense = v),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return c.ink;
                    return c.card;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return c.acc;
                    return c.line;
                  }),
                ),
              ],
            ),
          ),
          if (_existing?.linkedExpenseId != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => pushExpenseForTask(
                context,
                task: _existing!,
                fromCompletion: false,
              ),
              child: Text(
                'Apri la spesa collegata',
                style: TextStyle(color: c.acc, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('it', 'IT'),
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _pickReminder() async {
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli prima una scadenza')),
      );
      return;
    }
    final c = context.colors;
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        Widget option(String label, int? days) {
          final selected = days == _reminderDays;
          return ListTile(
            title: Text(
              label,
              style: TextStyle(
                color: selected ? c.acc : c.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () => Navigator.pop(ctx, days ?? 'none'),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option('Nessuno', null),
                option('Il giorno stesso', 0),
                option('1 giorno prima', 1),
                option('3 giorni prima', 3),
                option('7 giorni prima', 7),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _reminderDays = chosen == 'none' ? null : chosen as int;
    });
  }

  Future<void> _save() async {
    final error = taskValidationError(
      title: _titleCtrl.text,
      dueDate: _dueDate,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final session = ref.read(authSessionProvider).valueOrNull;
    final user = session?.user;
    final household = session?.household;
    if (user == null || household == null) return;

    setState(() => _busy = true);
    try {
      final assigneeUid = switch (_assignee) {
        _Assignee.rob => household.robUid,
        _Assignee.lau => household.lauUid,
        _Assignee.anyone => null,
      };

      final lists = ref.read(visibleTaskListsProvider);
      TaskList? selectedList;
      for (final l in lists) {
        if (l.id == _listId) {
          selectedList = l;
          break;
        }
      }

      final saved = await ref.read(taskRepositoryProvider).save(
            draft: HouseholdTask(
              id: widget.id ?? '',
              title: _titleCtrl.text.trim(),
              assigneeUid: assigneeUid,
              dueDate: _dueDate,
              reminderDaysBefore: _dueDate == null ? null : _reminderDays,
              propertyId: _propertyId,
              linkedExpenseId: _existing?.linkedExpenseId,
              createExpenseOnDone: _createExpense,
              done: _existing?.done ?? false,
              doneAt: _existing?.doneAt,
              doneBy: _existing?.doneBy,
              listId: selectedList?.id,
              listOwnerUid: selectedList?.ownerUid,
              createdBy: _existing?.createdBy,
              createdAt: _existing?.createdAt,
            ),
            actorUid: user.uid,
          );

      final linkedId = saved.linkedExpenseId;
      if (linkedId != null && linkedId.isNotEmpty) {
        final expRepo = ref.read(expenseRepositoryProvider);
        final exp = await expRepo.watchExpense(linkedId).first;
        if (exp != null) {
          await expRepo.save(
            draft: exp.copyWith(
              description: saved.title,
              propertyId: saved.propertyId,
              clearPropertyId: saved.propertyId == null,
            ),
            actorUid: user.uid,
            robUid: household.robUid,
            lauUid: household.lauUid,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvataggio non riuscito. Riprova.')),
      );
      setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    context.pop();
  }

  Future<void> _delete() async {
    final id = widget.id;
    final session = ref.read(authSessionProvider).valueOrNull;
    final uid = session?.user?.uid;
    if (id == null || uid == null) return;
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
    if (ok != true || !mounted) return;
    await ref.read(taskRepositoryProvider).softDelete(id, uid);
    if (!mounted) return;
    context.pop();
  }
}

String _reminderLabel(int? days) {
  return switch (days) {
    null => 'Nessuno',
    0 => 'Giorno stesso',
    1 => '1 giorno prima',
    3 => '3 giorni prima',
    7 => '7 giorni prima',
    _ => '$days giorni prima',
  };
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: c.ink2,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.02,
      ),
    );
  }
}

class _AssigneePicker extends StatelessWidget {
  const _AssigneePicker({required this.value, required this.onChanged});

  final _Assignee value;
  final ValueChanged<_Assignee> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AssigneeSeg(
              selected: value == _Assignee.rob,
              person: PersonKey.rob,
              label: 'Roberto',
              onTap: () => onChanged(_Assignee.rob),
            ),
          ),
          Expanded(
            child: _AssigneeSeg(
              selected: value == _Assignee.lau,
              person: PersonKey.lau,
              label: 'Laura',
              onTap: () => onChanged(_Assignee.lau),
            ),
          ),
          Expanded(
            child: _AssigneeSeg(
              selected: value == _Assignee.anyone,
              label: 'Chiunque',
              onTap: () => onChanged(_Assignee.anyone),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigneeSeg extends StatelessWidget {
  const _AssigneeSeg({
    required this.selected,
    required this.label,
    required this.onTap,
    this.person,
  });

  final bool selected;
  final PersonKey? person;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.card : c.line,
      elevation: selected ? 1 : 0,
      shadowColor: c.shadow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (person != null) ...[
                    PersonAvatar(person: person, size: 26),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? c.ink : c.ink2,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.ink3, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted ? c.ink3 : c.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, color: c.ink3, size: 18),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.accLine : c.line),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? c.acc : c.ink2,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
