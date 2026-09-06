import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
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
    final catalogProperties =
        ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[];
    final props = {
      for (final x in catalogProperties) x.id: x.name,
    };
    final propertiesById = {
      for (final x in catalogProperties) x.id: x,
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

    final groups = _groupByMonthAndDay(filtered);

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
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 72),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final month = groups[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
                            child: Text(
                              month.header,
                              style: TextStyle(
                                color: c.ink3,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                          for (final day in month.days) ...[
                            _DayHeader(date: day.date),
                            for (final e in day.items)
                              _ExpenseTile(
                                expense: e,
                                category: cats[e.categoryId],
                                property: e.propertyId == null
                                    ? null
                                    : _propertyChipLabel(
                                        propertiesById[e.propertyId],
                                        fallback: props[e.propertyId],
                                      ),
                                onOpen: () => context.push('/spese/${e.id}'),
                                onDelete: household == null || user == null
                                    ? null
                                    : () => _delete(e, user.uid),
                                onMarkPaid: household == null || user == null
                                    ? null
                                    : () => _markPaid(e, household, user.uid),
                              ),
                          ],
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

List<_MonthSection> _groupByMonthAndDay(List<Expense> expenses) {
  final months = <String, _MonthSection>{};
  for (final e in expenses) {
    final header = AppDateFormat.monthYearHeader(e.date);
    final month = months.putIfAbsent(header, () => _MonthSection(header: header));
    final dayStamp = DateTime(e.date.year, e.date.month, e.date.day);
    final dayKey = dayStamp.millisecondsSinceEpoch.toString();
    final day = month.daysByKey.putIfAbsent(
      dayKey,
      () => _DaySection(date: dayStamp),
    );
    day.items.add(e);
  }
  return months.values.toList();
}

String? _propertyChipLabel(CatalogProperty? property, {String? fallback}) {
  if (property == null) return fallback;
  final short = property.shortName.trim();
  final number = property.houseNumber.trim();
  if (short.isNotEmpty && number.isNotEmpty) return '$short $number';
  final name = property.name.trim();
  if (name.isNotEmpty) return name;
  if (short.isNotEmpty) return short;
  return fallback;
}

class _MonthSection {
  _MonthSection({required this.header});

  final String header;
  final daysByKey = <String, _DaySection>{};

  List<_DaySection> get days => daysByKey.values.toList();
}

class _DaySection {
  _DaySection({required this.date});

  final DateTime date;
  final items = <Expense>[];
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

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: c.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                AppDateFormat.weekday(date),
                style: TextStyle(
                  color: c.ink2,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.category,
    required this.property,
    required this.onOpen,
    required this.onDelete,
    required this.onMarkPaid,
  });

  final Expense expense;
  final String? category;
  final String? property;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final robPaid = expense.paidRobCents > 0;
    final lauPaid = expense.paidLauCents > 0;
    final facts = <Widget>[
      _FactChip(
        icon: Icons.event_outlined,
        label: [
          AppDateFormat.format(expense.date),
          if (expense.dateEstimated) 'data stimata',
        ].join(' · '),
      ),
      if (property != null && property!.trim().isNotEmpty)
        _FactChip(icon: Icons.home_outlined, label: property!),
      if (category != null && category!.trim().isNotEmpty)
        _FactChip(icon: Icons.label_outline, label: category!),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PayerAvatars(rob: robPaid, lau: lauPaid),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            expense.description,
                            style: TextStyle(
                              color: c.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          MoneyFormat.fromCents(expense.amountDueCents),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            letterSpacing: -0.01,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: facts,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusChip(
                              status: statusToUi(expense.status),
                              compact: true,
                            ),
                            if (expense.status != ExpenseStatus.pagato &&
                                expense.missingCents > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Manca ${MoneyFormat.fromCents(expense.missingCents)}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: c.due,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 88,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 7, 3),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              color: c.ink2,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(icon, size: 12, color: c.ink2),
                ),
              ),
              TextSpan(text: label),
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
      return const PersonAvatar(empty: true, size: 28);
    }
    if (rob && lau) {
      return const SizedBox(
        width: 38,
        height: 28,
        child: Stack(
          children: [
            PersonAvatar(person: PersonKey.rob, size: 28),
            Positioned(
              left: 10,
              child: PersonAvatar(person: PersonKey.lau, size: 28),
            ),
          ],
        ),
      );
    }
    return PersonAvatar(
      person: rob ? PersonKey.rob : PersonKey.lau,
      size: 28,
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

