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
import '../../data/balance_calculator.dart';
import '../../data/data_providers.dart';
import '../../data/expense_list_filter.dart';
import '../../data/expense_models.dart';
import '../../data/report_aggregator.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';
import 'payer_dialog.dart';

enum _ListFilter { tutte, daPagare, parziale, pagato }

const _tabular = [FontFeature.tabularFigures()];

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

    // Property/category/date filter and search apply first, so the status
    // counts below describe what the list can actually show.
    final q = _query.trim().toLowerCase();
    final inScope = expenses.where((e) {
      if (!extraFilter.matches(
        expensePropertyId: e.propertyId,
        categoryId: e.categoryId,
        date: e.date,
      )) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        e.description,
        cats[e.categoryId] ?? '',
        if (e.propertyId != null) props[e.propertyId] ?? '',
        MoneyFormat.fromCents(e.amountDueCents),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();

    final filtered = inScope.where((e) {
      return switch (_filter) {
        _ListFilter.tutte => true,
        _ListFilter.daPagare => e.status == ExpenseStatus.daPagare,
        _ListFilter.parziale => e.status == ExpenseStatus.parziale,
        _ListFilter.pagato => e.status == ExpenseStatus.pagato,
      };
    }).toList();

    final months = _groupByMonth(filtered);

    int count(ExpenseStatus s) => inScope.where((e) => e.status == s).length;

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
            tooltip: _searching ? 'Chiudi ricerca' : 'Cerca',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _Chip(
                  label: 'Tutte',
                  count: inScope.length,
                  selected: _filter == _ListFilter.tutte,
                  onTap: () => setState(() => _filter = _ListFilter.tutte),
                ),
                _Chip(
                  label: 'Da pagare',
                  count: count(ExpenseStatus.daPagare),
                  selected: _filter == _ListFilter.daPagare,
                  onTap: () => setState(() => _filter = _ListFilter.daPagare),
                ),
                _Chip(
                  label: 'Parziali',
                  count: count(ExpenseStatus.parziale),
                  selected: _filter == _ListFilter.parziale,
                  onTap: () => setState(() => _filter = _ListFilter.parziale),
                ),
                _Chip(
                  label: 'Pagate',
                  count: count(ExpenseStatus.pagato),
                  selected: _filter == _ListFilter.pagato,
                  onTap: () => setState(() => _filter = _ListFilter.pagato),
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
                    itemCount: months.length,
                    itemBuilder: (context, i) {
                      final month = months[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MonthHeader(
                            title: month.title,
                            totalCents: month.totalCents,
                          ),
                          _MonthCard(
                            children: [
                              for (final e in month.items)
                                _ExpenseRow(
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
    final repo = ref.read(expenseRepositoryProvider);
    await repo.softDelete(e.id, uid);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Spesa eliminata',
      onUndo: () => repo.restore(e.id, uid),
    );
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

List<_MonthSection> _groupByMonth(List<Expense> expenses) {
  final months = <String, _MonthSection>{};
  for (final e in expenses) {
    final key = '${e.date.year}-${e.date.month}';
    months
        .putIfAbsent(
          key,
          () => _MonthSection(title: AppDateFormat.monthYearTitle(e.date)),
        )
        .items
        .add(e);
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
  _MonthSection({required this.title});

  final String title;
  final items = <Expense>[];

  int get totalCents => items.fold(0, (sum, e) => sum + e.amountDueCents);
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
    final fg = selected ? c.bg : c.ink2;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? c.ink : c.card,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? c.ink : c.line),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  '$label $count',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.title, required this.totalCents});

  final String title;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.2,
              ),
            ),
          ),
          Text(
            MoneyFormat.fromCents(totalCents),
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.2,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// One surface per month; rows are split by a hairline that starts at the
/// text column, so the avatars read as one column.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 58, color: c.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
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
    final meta = [
      AppDateFormat.formatDayMonth(expense.date),
      if (expense.dateEstimated) 'data stimata',
      if (property != null && property!.trim().isNotEmpty) property!,
      if (category != null && category!.trim().isNotEmpty) category!,
    ].join(' · ');

    // Only what still needs doing gets a word, and only it gets colour.
    final String? open = switch (expense.status) {
      ExpenseStatus.daPagare => 'Da pagare',
      ExpenseStatus.parziale =>
        'Manca ${MoneyFormat.fromCents(expense.missingCents)}',
      ExpenseStatus.pagato => null,
    };

    return Dismissible(
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
            content: const Text('Finisce nel Cestino: puoi ripristinarla entro 30 giorni.'),
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
      child: Material(
        color: c.card,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PayerAvatars(
                  rob: expense.paidRobCents > 0,
                  lau: expense.paidLauCents > 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            MoneyFormat.fromCents(expense.amountDueCents),
                            style: TextStyle(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.3,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              meta,
                              style: TextStyle(
                                color: c.ink2,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (open != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              open,
                              style: TextStyle(
                                color: c.due,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        width: 32,
        height: 32,
        child: Stack(
          children: [
            PersonAvatar(person: PersonKey.rob, size: 22),
            Positioned(
              right: 0,
              bottom: 0,
              child: PersonAvatar(person: PersonKey.lau, size: 22),
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
      color: color,
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
