import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/status_mapping.dart';
import '../../data/balance_calculator.dart';
import '../../data/data_providers.dart';
import '../../data/expense_list_filter.dart';
import '../../data/expense_models.dart';
import '../../data/report_aggregator.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';
import 'payer_dialog.dart';

enum _ListFilter { tutte, daPagare, parziale, pagato }

class ExpensesListPage extends ConsumerStatefulWidget {
  const ExpensesListPage({super.key});

  @override
  ConsumerState<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends ConsumerState<ExpensesListPage> {
  _ListFilter _filter = _ListFilter.tutte;
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expenses = ref.watch(expensesProvider).valueOrNull ?? const <Expense>[];
    final cats = {
      for (final x in ref.watch(categoriesProvider).valueOrNull ?? const <CatalogCategory>[])
        x.id: x.name,
    };
    final props = {
      for (final x in ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[])
        x.id: x.shortName,
    };
    final household = ref.watch(authSessionProvider).valueOrNull?.household;
    final user = ref.watch(authSessionProvider).valueOrNull?.user;
    final extraFilter = ref.watch(expenseListFilterProvider);

    final q = _query.trim().toLowerCase();
    final filtered = expenses.where((e) {
      if (!extraFilter.matches(
        expensePropertyId: e.propertyId,
        categoryId: e.categoryId,
        date: e.date,
      )) {
        return false;
      }
      final statusOk = switch (_filter) {
        _ListFilter.tutte => true,
        _ListFilter.daPagare => e.status == ExpenseStatus.daPagare,
        _ListFilter.parziale => e.status == ExpenseStatus.parziale,
        _ListFilter.pagato => e.status == ExpenseStatus.pagato,
      };
      if (!statusOk) return false;
      if (q.isEmpty) return true;
      final hay = [
        e.description,
        cats[e.categoryId] ?? '',
        if (e.propertyId != null) props[e.propertyId] ?? '',
        MoneyFormat.fromCents(e.amountDueCents),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();

    final groups = <String, List<Expense>>{};
    for (final e in filtered) {
      final key = AppDateFormat.monthYearHeader(e.date);
      groups.putIfAbsent(key, () => []).add(e);
    }

    int count(ExpenseStatus s) => expenses.where((e) => e.status == s).length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Cerca spese',
                  hintStyle: TextStyle(color: c.ink3),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Spese'),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          if (extraFilter.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ActiveFilterBanner(
                filter: extraFilter,
                categoryName: extraFilter.categoryId == null
                    ? null
                    : cats[extraFilter.categoryId!],
                propertyName: extraFilter.propertyId == null
                    ? null
                    : extraFilter.propertyId == ReportAggregator.nonePropertyId
                        ? 'Senza immobile'
                        : props[extraFilter.propertyId!],
                onClear: () => ref
                    .read(expenseListFilterProvider.notifier)
                    .state = const ExpenseListFilter(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _Chip(
                    label: 'Tutte',
                    count: expenses.length,
                    selected: _filter == _ListFilter.tutte,
                    onTap: () => setState(() => _filter = _ListFilter.tutte),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Chip(
                    label: 'Da pagare',
                    count: count(ExpenseStatus.daPagare),
                    selected: _filter == _ListFilter.daPagare,
                    onTap: () => setState(() => _filter = _ListFilter.daPagare),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Chip(
                    label: 'Parziali',
                    count: count(ExpenseStatus.parziale),
                    selected: _filter == _ListFilter.parziale,
                    onTap: () => setState(() => _filter = _ListFilter.parziale),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Chip(
                    label: 'Pagate',
                    count: count(ExpenseStatus.pagato),
                    selected: _filter == _ListFilter.pagato,
                    onTap: () => setState(() => _filter = _ListFilter.pagato),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      EmptyState(
                        message: expenses.isEmpty
                            ? 'Ancora nessuna spesa. Aggiungete la prima.'
                            : 'Nessuna spesa con questi filtri.',
                        actionLabel: 'Nuova spesa',
                        onAction: () => context.push('/spese/nuova'),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final month = groups.keys.elementAt(i);
                      final items = groups[month]!;
                      final monthTotal =
                          items.fold<int>(0, (s, e) => s + e.amountDueCents);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                            child: Text(
                              '$month · ${MoneyFormat.fromCents(monthTotal)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.ink3,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          for (final e in items)
                            _ExpenseTile(
                              expense: e,
                              category: cats[e.categoryId],
                              property: e.propertyId == null
                                  ? null
                                  : props[e.propertyId],
                              robUid: household?.robUid ?? 'rob',
                              lauUid: household?.lauUid ?? 'lau',
                              onOpen: () => context.push('/spese/${e.id}'),
                              onDelete: household == null || user == null
                                  ? null
                                  : () => _delete(e, user.uid),
                              onMarkPaid: household == null || user == null
                                  ? null
                                  : () => _markPaid(e, household, user.uid),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Expense e, String uid) async {
    await ref.read(expenseRepositoryProvider).softDelete(e.id, uid);
  }

  Future<void> _markPaid(Expense e, Household household, String uid) async {
    final draft = await askPayment(
      context: context,
      household: household,
      suggestedCents: e.missingCents > 0 ? e.missingCents : e.amountDueCents,
      title: 'Segna pagata',
    );
    if (draft == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    await repo.addPayments(
      expense: e,
      parts: [
        for (final p in draft.parts)
          (payerUid: p.payerUid, amountCents: p.amountCents),
      ],
      actorUid: uid,
      robUid: household.robUid,
      lauUid: household.lauUid,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.acc : c.ink2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.accSoft : c.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? c.accLine : c.line),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.category,
    required this.property,
    required this.robUid,
    required this.lauUid,
    required this.onOpen,
    required this.onDelete,
    required this.onMarkPaid,
  });

  final Expense expense;
  final String? category;
  final String? property;
  final String robUid;
  final String lauUid;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final robPaid = expense.paidRobCents > 0;
    final lauPaid = expense.paidLauCents > 0;
    final subtitle = [
      AppDateFormat.format(expense.date),
      if (expense.dateEstimated) 'data stimata',
      if (category != null) category,
      if (property != null) property,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(expense.id),
        background: _SwipeBg(
          color: c.okSoft,
          align: Alignment.centerLeft,
          label: 'Pagata',
          fg: c.ok,
        ),
        secondaryBackground: _SwipeBg(
          color: c.dueSoft,
          align: Alignment.centerRight,
          label: 'Elimina',
          fg: c.due,
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            onMarkPaid?.call();
            return false;
          }
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Eliminare la spesa?'),
              content: const Text('La spesa verrà nascosta. Puoi sempre crearne un’altra.'),
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
        child: AppCard(
          onTap: onOpen,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _PayerAvatars(rob: robPaid, lau: lauPaid),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.ink2,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    expense.amountDueCents,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  StatusChip(
                    status: statusToUi(expense.status),
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayerAvatars extends StatelessWidget {
  const _PayerAvatars({required this.rob, required this.lau});

  final bool rob;
  final bool lau;

  @override
  Widget build(BuildContext context) {
    if (!rob && !lau) {
      return const PersonAvatar(empty: true, size: 32);
    }
    if (rob && lau) {
      return const SizedBox(
        width: 44,
        height: 32,
        child: Stack(
          children: [
            PersonAvatar(person: PersonKey.rob, size: 32),
            Positioned(
              left: 12,
              child: PersonAvatar(person: PersonKey.lau, size: 32),
            ),
          ],
        ),
      );
    }
    return PersonAvatar(
      person: rob ? PersonKey.rob : PersonKey.lau,
      size: 32,
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.color,
    required this.align,
    required this.label,
    required this.fg,
  });

  final Color color;
  final Alignment align;
  final String label;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ActiveFilterBanner extends StatelessWidget {
  const _ActiveFilterBanner({
    required this.filter,
    required this.onClear,
    this.categoryName,
    this.propertyName,
  });

  final ExpenseListFilter filter;
  final VoidCallback onClear;
  final String? categoryName;
  final String? propertyName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = <String>[
      if (propertyName != null) propertyName!,
      if (categoryName != null) categoryName!,
      if (filter.from != null && filter.to != null)
        '${AppDateFormat.format(filter.from!)} – ${AppDateFormat.format(filter.to!)}'
      else if (filter.from != null)
        'da ${AppDateFormat.format(filter.from!)}'
      else if (filter.to != null)
        'fino a ${AppDateFormat.format(filter.to!)}',
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parts.isEmpty ? 'Filtro attivo' : parts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: Text('Azzera', style: TextStyle(color: c.acc)),
          ),
        ],
      ),
    );
  }
}

