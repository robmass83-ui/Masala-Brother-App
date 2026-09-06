import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/chip_wrap.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../auth/auth_providers.dart';

enum _PayerChoice { rob, lau, both, none }

enum ExpensePrefillPayer { rob, lau, both, none }

class ExpenseFormPrefill {
  const ExpenseFormPrefill({
    this.description,
    this.propertyId,
    this.taskId,
    this.defaultPayer,
    this.fromTaskCompletion = false,
  });

  final String? description;
  final String? propertyId;
  final String? taskId;
  final ExpensePrefillPayer? defaultPayer;
  final bool fromTaskCompletion;
}

class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key, this.id, this.prefill});

  final String? id;
  final ExpenseFormPrefill? prefill;

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _categoryId;
  String? _propertyId;
  _PayerChoice _payer = _PayerChoice.none;
  int _shareRob = 50;
  int _robPartCents = 0;
  int _lauPartCents = 0;
  bool _loaded = false;
  bool _prefillApplied = false;
  bool _busy = false;

  bool get _isEdit => widget.id != null;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  int get _amountCents {
    try {
      return MoneyFormat.parseToCents(_amountCtrl.text);
    } catch (_) {
      return 0;
    }
  }

  void _fillFrom(Expense e) {
    _amountCtrl.text = MoneyFormat.fromCents(e.amountDueCents).replaceFirst('€', '').trim();
    _descCtrl.text = e.description;
    _date = e.date;
    _categoryId = e.categoryId;
    _propertyId = e.propertyId;
    _shareRob = e.shareRobPct;
    if (e.paidRobCents > 0 && e.paidLauCents > 0) {
      _payer = _PayerChoice.both;
      _robPartCents = e.paidRobCents;
      _lauPartCents = e.paidLauCents;
    } else if (e.paidRobCents > 0) {
      _payer = _PayerChoice.rob;
    } else if (e.paidLauCents > 0) {
      _payer = _PayerChoice.lau;
    } else {
      _payer = _PayerChoice.none;
    }
  }

  void _syncSplit() {
    final half = _amountCents ~/ 2;
    _robPartCents = half;
    _lauPartCents = _amountCents - half;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <CatalogCategory>[];
    final props = ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[];
    final existing = widget.id == null
        ? null
        : ref.watch(expenseProvider(widget.id!)).valueOrNull;

    if (_isEdit && existing != null && !_loaded) {
      _fillFrom(existing);
      _loaded = true;
    }
    if (!_isEdit && !_prefillApplied && widget.prefill != null) {
      _prefillApplied = true;
      final p = widget.prefill!;
      if (p.description != null && p.description!.trim().isNotEmpty) {
        _descCtrl.text = p.description!;
      }
      _propertyId = p.propertyId ?? _propertyId;
      if (p.defaultPayer != null) {
        _payer = switch (p.defaultPayer!) {
          ExpensePrefillPayer.rob => _PayerChoice.rob,
          ExpensePrefillPayer.lau => _PayerChoice.lau,
          ExpensePrefillPayer.both => _PayerChoice.both,
          ExpensePrefillPayer.none => _PayerChoice.none,
        };
      }
    }
    _categoryId ??= cats.isEmpty ? 'altro' : cats.first.id;

    return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: Text(
            widget.prefill?.fromTaskCompletion == true
                ? 'Importo e pagamento'
                : _isEdit
                    ? 'Modifica spesa'
                    : 'Nuova spesa',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
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
              label: _busy ? 'Salvataggio…' : 'Salva spesa',
              onPressed: _busy ? null : _save,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            AppCard(
              child: TextField(
                controller: _amountCtrl,
                autofocus: !_isEdit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: TextStyle(
                  color: c.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: 'Importo',
                  labelStyle: TextStyle(color: c.ink2),
                  prefixText: '€ ',
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  if (_payer == _PayerChoice.both) {
                    setState(_syncSplit);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: TextField(
                controller: _descCtrl,
                maxLength: 120,
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Descrizione',
                  labelStyle: TextStyle(color: c.ink2),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  locale: const Locale('it', 'IT'),
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _date = picked;
                  });
                }
              },
              child: Text(
                'Data · ${AppDateFormat.format(_date)}',
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),
            Text('Categoria', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ChipWrap(
              children: [
                for (final cat in cats)
                  _ChoiceChip(
                    label: cat.name,
                    selected: _categoryId == cat.id,
                    onTap: () => setState(() {
                      _categoryId = cat.id;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Immobile', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ChipWrap(
              children: [
                _ChoiceChip(
                  label: 'Nessuno',
                  selected: _propertyId == null,
                  onTap: () => setState(() {
                    _propertyId = null;
                  }),
                ),
                for (final p in props)
                  _ChoiceChip(
                    label: p.shortName,
                    selected: _propertyId == p.id,
                    onTap: () => setState(() {
                      _propertyId = p.id;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Chi ha pagato', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
            if (widget.prefill?.fromTaskCompletion == true) ...[
              const SizedBox(height: 4),
              Text(
                'La cosa è fatta: metti l’importo e chi ha pagato (o Nessuno ancora).',
                style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            ChipWrap(
              children: [
                _ChoiceChip(
                  label: 'Roberto',
                  selected: _payer == _PayerChoice.rob,
                  onTap: () => setState(() {
                    _payer = _PayerChoice.rob;
                    _robPartCents = _amountCents;
                    _paidCtrl.text = MoneyFormat.fromCents(_amountCents)
                        .replaceFirst('€', '')
                        .trim();
                  }),
                ),
                _ChoiceChip(
                  label: 'Laura',
                  selected: _payer == _PayerChoice.lau,
                  onTap: () => setState(() {
                    _payer = _PayerChoice.lau;
                    _lauPartCents = _amountCents;
                    _paidCtrl.text = MoneyFormat.fromCents(_amountCents)
                        .replaceFirst('€', '')
                        .trim();
                  }),
                ),
                _ChoiceChip(
                  label: 'Entrambi',
                  selected: _payer == _PayerChoice.both,
                  onTap: () => setState(() {
                    _payer = _PayerChoice.both;
                    _syncSplit();
                  }),
                ),
                _ChoiceChip(
                  label: 'Nessuno ancora',
                  selected: _payer == _PayerChoice.none,
                  onTap: () => setState(() {
                    _payer = _PayerChoice.none;
                  }),
                ),
              ],
            ),
            if (_payer == _PayerChoice.rob || _payer == _PayerChoice.lau) ...[
              const SizedBox(height: 10),
              AppCard(
                child: TextField(
                  controller: _paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: _payer == _PayerChoice.rob
                        ? 'Importo pagato da Roberto'
                        : 'Importo pagato da Laura',
                    labelStyle: TextStyle(color: c.ink2),
                    prefixText: '€ ',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    try {
                      final cents = MoneyFormat.parseToCents(v);
                      if (_payer == _PayerChoice.rob) {
                        _robPartCents = cents;
                      } else {
                        _lauPartCents = cents;
                      }
                    } catch (_) {}
                  },
                ),
              ),
            ],
            if (_payer == _PayerChoice.both) ...[
              const SizedBox(height: 10),
              Text(
                'Roberto ${MoneyFormat.fromCents(_robPartCents)} · '
                'Laura ${MoneyFormat.fromCents(_lauPartCents)}',
                style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
              ),
              if (_robPartCents + _lauPartCents < _amountCents)
                Text(
                  'Manca ${MoneyFormat.fromCents(_amountCents - _robPartCents - _lauPartCents)}',
                  style: TextStyle(color: c.due, fontWeight: FontWeight.w700),
                ),
            ],
            const SizedBox(height: 16),
            Text('Divisione', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ChipWrap(
              columns: 1,
              children: [
                _ChoiceChip(
                  label: 'Metà ciascuno',
                  selected: _shareRob == 50,
                  onTap: () => setState(() {
                    _shareRob = 50;
                  }),
                ),
              ],
            ),
            Slider(
              value: _shareRob.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: c.acc,
              label: 'Roberto $_shareRob%',
              onChanged: (v) => setState(() {
                _shareRob = v.round();
              }),
            ),
            Text(
              'Roberto $_shareRob% · Laura ${100 - _shareRob}%',
              style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
            ),
          ],
        ),
    );
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty || _amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servono importo e descrizione')),
      );
      return;
    }
    final session = ref.read(authSessionProvider).valueOrNull;
    final user = session?.user;
    final household = session?.household;
    if (user == null || household == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final taskId = widget.prefill?.taskId;
      final taskRepo = ref.read(taskRepositoryProvider);
      final linkedTask = (taskId == null || taskId.isEmpty)
          ? null
          : await taskRepo.watchTask(taskId).first;
      var expenseId = widget.id;
      if (expenseId == null || expenseId.isEmpty) {
        expenseId = linkedTask?.linkedExpenseId;
      }
      if (expenseId != null && expenseId.isEmpty) expenseId = null;
      final existing = expenseId == null
          ? null
          : await repo.watchExpense(expenseId).first;
      final fromTask = taskId != null && taskId.isNotEmpty;

      final payments = <ExpensePayment>[];
      if (fromTask || existing == null || existing.payments.isEmpty) {
        if (_payer == _PayerChoice.rob) {
          final paid = _robPartCents > 0 ? _robPartCents : _amountCents;
          payments.add(
            repo.newPayment(payerUid: household.robUid, amountCents: paid),
          );
        } else if (_payer == _PayerChoice.lau) {
          final paid = _lauPartCents > 0 ? _lauPartCents : _amountCents;
          payments.add(
            repo.newPayment(payerUid: household.lauUid, amountCents: paid),
          );
        } else if (_payer == _PayerChoice.both) {
          if (_robPartCents > 0) {
            payments.add(
              repo.newPayment(
                payerUid: household.robUid,
                amountCents: _robPartCents,
              ),
            );
          }
          if (_lauPartCents > 0) {
            payments.add(
              repo.newPayment(
                payerUid: household.lauUid,
                amountCents: _lauPartCents,
              ),
            );
          }
        }
      } else {
        payments.addAll(existing.payments);
      }

      final sameDay = existing != null &&
          existing.date.year == _date.year &&
          existing.date.month == _date.month &&
          existing.date.day == _date.day;
      final saved = await repo.save(
        draft: Expense(
          id: expenseId ?? '',
          description: desc,
          amountDueCents: _amountCents,
          date: _date,
          categoryId: _categoryId ?? 'altro',
          propertyId: _propertyId,
          shareRobPct: _shareRob,
          payments: payments,
          notes: existing?.notes,
          source: existing?.source ?? 'app',
          importRow: existing?.importRow,
          dateEstimated: existing?.dateEstimated == true && sameDay,
          createdBy: existing?.createdBy,
          createdAt: existing?.createdAt,
        ),
        actorUid: user.uid,
        robUid: household.robUid,
        lauUid: household.lauUid,
      );

      if (linkedTask != null && linkedTask.linkedExpenseId != saved.id) {
        await taskRepo.save(
          draft: linkedTask.copyWith(linkedExpenseId: saved.id),
          actorUid: user.uid,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito. Riprova.')),
      );
      setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    context.pop();
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
