import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/eccellente_badge.dart';
import '../../core/widgets/penny_on_button.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/status_mapping.dart';
import '../../data/balance_calculator.dart';
import '../../data/da_sistemare.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../../data/task_models.dart';
import '../auth/auth_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.user;
    final balance = ref.watch(balanceProvider);
    final expenses = ref.watch(expensesProvider).valueOrNull ?? const <Expense>[];
    final tasks = ref.watch(visibleTasksProvider);
    final categories = {
      for (final cat in ref.watch(categoriesProvider).valueOrNull ?? const <CatalogCategory>[])
        cat.id: cat.name,
    };
    final firstName = (user?.displayName ?? 'ciao').split(' ').first;
    final toFix = daSistemareItems(expenses: expenses, tasks: tasks);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          'Ciao $firstName',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Cose in scadenza',
            onPressed: () => context.go('/dafare'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        physics: const ClampingScrollPhysics(),
        children: [
          _HeroBalance(colors: c, snap: balance),
          const SizedBox(height: 6),
          _PaidRow(paidRob: balance.paidRobCents, paidLau: balance.paidLauCents),
          const SizedBox(height: 6),
          _TotalsCard(balance: balance),
          const SizedBox(height: 6),
          if (toFix.isEmpty)
            EmptyState(
              message: 'Niente in sospeso. Siete a posto.',
              actionLabel: 'Nuova spesa',
              compact: true,
              onAction: () => context.push('/spese/nuova'),
            )
          else ...[
            _DaSistemareHeader(),
            for (final item in toFix) ...[
              if (item.expense != null)
                _OpenExpenseCard(
                  expense: item.expense!,
                  category: categories[item.expense!.categoryId] ??
                      item.expense!.categoryId,
                )
              else if (item.task != null)
                _OpenTaskCard(task: item.task!),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _PaidRow extends StatelessWidget {
  const _PaidRow({required this.paidRob, required this.paidLau});

  final int paidRob;
  final int paidLau;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaidCard(
            person: PersonKey.rob,
            label: 'Roberto ha pagato',
            cents: paidRob,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PaidCard(
            person: PersonKey.lau,
            label: 'Laura ha pagato',
            cents: paidLau,
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.balance});

  final BalanceSnapshot balance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      onTap: () => context.push('/rendiconto'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spese totali',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink2,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SoftArrowHint(),
            ],
          ),
          const SizedBox(height: 2),
          MoneyText(balance.totalDueCents, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            'Metà a testa ${MoneyFormat.fromCents(balance.halfEachCents)}',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          _ShareBar(robShare: balance.robPaidShare),
        ],
      ),
    );
  }
}

class _DaSistemareHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Text(
          'Da sistemare',
          style: TextStyle(
            color: c.ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/spese'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
          ),
          child: Text('Vedi tutte', style: TextStyle(color: c.acc)),
        ),
      ],
    );
  }
}

class _OpenExpenseCard extends StatelessWidget {
  const _OpenExpenseCard({required this.expense, required this.category});

  final Expense expense;
  final String category;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: () => context.push('/spese/${expense.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppDateFormat.format(expense.date)}'
                  '${expense.dateEstimated ? ' · stimata' : ''} · $category',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(expense.amountDueCents),
              const SizedBox(height: 6),
              StatusChip(status: statusToUi(expense.status)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenTaskCard extends StatelessWidget {
  const _OpenTaskCard({required this.task});

  final HouseholdTask task;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final due = task.dueDate;
    final kind = taskDueKind(task, now: DateTime.now());
    final dueColor = kind == TaskDueKind.overdue ? c.due : c.warn;
    return AppCard(
      onTap: () => context.push('/dafare/${task.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  due == null
                      ? 'Da fare'
                      : 'scade ${AppDateFormat.format(due)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kind == TaskDueKind.overdue ? c.dueSoft : c.warnSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Da fare',
              style: TextStyle(
                color: dueColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBalance extends StatefulWidget {
  const _HeroBalance({required this.colors, required this.snap});

  final AppColors colors;
  final BalanceSnapshot snap;

  @override
  State<_HeroBalance> createState() => _HeroBalanceState();
}

class _HeroBalanceState extends State<_HeroBalance> {
  bool _penny = false;
  Timer? _swap;

  bool get _canLoop {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return !WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_canLoop) return;
      _armSwap();
    });
  }

  void _armSwap() {
    _swap?.cancel();
    _swap = Timer(_penny ? const Duration(seconds: 11) : const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _penny = !_penny);
      _armSwap();
    });
  }

  @override
  void dispose() {
    _swap?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final snap = widget.snap;
    final even = snap.isEven;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, _penny ? 10 : 8, 16, 8),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_penny) const SizedBox(height: 56),
              Text(
                'SITUAZIONE ATTUALE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.04,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: EdgeInsets.only(right: _penny ? 0 : 72),
                child: Text(
                  even
                      ? 'Siete in pari'
                      : MoneyFormat.fromCents(snap.absoluteCreditCents),
                  style: TextStyle(
                    color: colors.heroFg,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -0.02,
                  ),
                ),
              ),
              if (!even) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(right: _penny ? 0 : 72),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: colors.heroFg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      children: snap.lauraOwesRoberto
                          ? [
                              const TextSpan(text: 'che '),
                              TextSpan(
                                text: 'Laura',
                                style: TextStyle(
                                  color: colors.lauOnHero,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ' deve a '),
                              TextSpan(
                                text: 'Roberto',
                                style: TextStyle(
                                  color: colors.robOnHero,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ]
                          : [
                              const TextSpan(text: 'che '),
                              TextSpan(
                                text: 'Roberto',
                                style: TextStyle(
                                  color: colors.robOnHero,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ' deve a '),
                              TextSpan(
                                text: 'Laura',
                                style: TextStyle(
                                  color: colors.lauOnHero,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/bonifici/nuovo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.acc,
                    foregroundColor: colors.onAcc,
                    minimumSize: const Size.fromHeight(38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Registra bonifico',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          if (!_penny)
            const Positioned(
              right: -6,
              top: -6,
              child: IgnorePointer(child: EccellenteBadge(size: 64)),
            ),
          if (_penny)
            const Positioned(
              right: -2,
              bottom: 10,
              child: IgnorePointer(child: PennyOnButton()),
            ),
        ],
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  const _PaidCard({
    required this.person,
    required this.label,
    required this.cents,
  });

  final PersonKey person;
  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(person: person, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink2,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MoneyText(cents, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _SoftArrowHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.accLine),
      ),
      child: Icon(Icons.arrow_forward, color: c.acc, size: 20),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.robShare});

  final double robShare;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rob = robShare.clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(flex: (rob * 1000).round().clamp(0, 1000), child: ColoredBox(color: c.rob)),
                Expanded(
                  flex: ((1 - rob) * 1000).round().clamp(0, 1000),
                  child: ColoredBox(color: c.lau),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Roberto ${(rob * 100).round()}%',
              style: TextStyle(color: c.rob, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const Spacer(),
            Text(
              'Laura ${((1 - rob) * 100).round()}%',
              style: TextStyle(color: c.lau, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
