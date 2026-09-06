import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../data/data_providers.dart';
import '../../data/expense_list_filter.dart';
import '../../data/report_aggregator.dart';
import '../../data/report_period.dart';
import '../../data/transfer_models.dart';
import '../auth/auth_providers.dart';
import 'period_selector.dart';

class ReportPage extends ConsumerWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final period = ref.watch(reportPeriodProvider);
    final snap = ref.watch(reportSnapshotProvider);
    final household = ref.watch(authSessionProvider).valueOrNull?.household;
    final expensesLabel = period.kind == ReportPeriodKind.currentYear
        ? 'Spese ${DateTime.now().year}'
        : 'Spese del periodo';

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Rendiconto'),
        actions: [
          IconButton(
            tooltip: 'Esporta',
            onPressed: () => context.push('/esporta'),
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
        children: [
          PeriodSelector(
            period: period,
            onChanged: (p) =>
                ref.read(reportPeriodProvider.notifier).state = p,
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: expensesLabel,
                        child: MoneyText(
                          snap.totalDueCents,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Metric(
                        label: 'Voci',
                        child: Text(
                          '${snap.expenseCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Roberto',
                        labelColor: c.rob,
                        child: MoneyText(
                          snap.paidRobCents,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Metric(
                        label: 'Laura',
                        labelColor: c.lau,
                        child: MoneyText(
                          snap.paidLauCents,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ShareBar(robShare: snap.robPaidShare),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Per immobile',
            style: TextStyle(
              color: c.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (snap.byProperty.isEmpty)
            EmptyState(
              message: 'Nessuna spesa in questo periodo.',
              actionLabel: 'Nuova spesa',
              onAction: () => context.push('/spese/nuova'),
            )
          else
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                children: [
                  for (var i = 0; i < snap.byProperty.length; i++) ...[
                    if (i > 0) Divider(color: c.line, height: 1),
                    _NamedBarRow(
                      item: snap.byProperty[i],
                      maxCents: snap.maxPropertyCents,
                      onTap: () => _openExpenses(
                        context,
                        ref,
                        period: period,
                        propertyId: snap.byProperty[i].id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Per categoria',
            style: TextStyle(
              color: c.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (snap.byCategory.isEmpty)
            AppCard(
              child: Text(
                'Nessuna categoria da mostrare.',
                style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                children: [
                  for (var i = 0; i < snap.byCategory.length; i++) ...[
                    if (i > 0) Divider(color: c.line, height: 1),
                    _NamedBarRow(
                      item: snap.byCategory[i],
                      maxCents: snap.maxCategoryCents,
                      onTap: () => _openExpenses(
                        context,
                        ref,
                        period: period,
                        categoryId: snap.byCategory[i].id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Bonifici',
                style: TextStyle(
                  color: c.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/bonifici'),
                child: Text('Vedi tutti', style: TextStyle(color: c.acc)),
              ),
            ],
          ),
          if (snap.transfers.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nessun bonifico in questo periodo.',
                    style: TextStyle(
                      color: c.ink2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push('/bonifici/nuovo'),
                    child: Text(
                      'Registra bonifico',
                      style: TextStyle(
                        color: c.acc,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                children: [
                  for (var i = 0; i < snap.transfers.length; i++) ...[
                    if (i > 0) Divider(color: c.line, height: 1),
                    _ReportTransferRow(
                      transfer: snap.transfers[i],
                      fromLaura: household != null &&
                          household.isLauUid(snap.transfers[i].fromUid),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openExpenses(
    BuildContext context,
    WidgetRef ref, {
    required ReportPeriod period,
    String? propertyId,
    String? categoryId,
  }) {
    ref.read(expenseListFilterProvider.notifier).state = ExpenseListFilter(
      propertyId: propertyId,
      categoryId: categoryId,
      from: period.from,
      to: period.to,
    );
    context.go('/spese');
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.child,
    this.labelColor,
  });

  final String label;
  final Widget child;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: labelColor ?? c.ink3,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
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
    final robFlex = (rob * 1000).round().clamp(0, 1000);
    final lauFlex = (1000 - robFlex).clamp(0, 1000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (robFlex > 0)
              Expanded(flex: robFlex, child: ColoredBox(color: c.rob)),
            if (lauFlex > 0)
              Expanded(flex: lauFlex, child: ColoredBox(color: c.lau)),
          ],
        ),
      ),
    );
  }
}

class _NamedBarRow extends StatelessWidget {
  const _NamedBarRow({
    required this.item,
    required this.maxCents,
    required this.onTap,
  });

  final NamedAmount item;
  final int maxCents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fraction = maxCents == 0 ? 0.0 : item.amountCents / maxCents;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MoneyText(item.amountCents, style: const TextStyle(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 8,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        ColoredBox(color: c.line, child: const SizedBox.expand()),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ColoredBox(
                            color: c.acc,
                            child: SizedBox(
                              width: constraints.maxWidth * fraction.clamp(0, 1),
                              height: 8,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTransferRow extends StatelessWidget {
  const _ReportTransferRow({
    required this.transfer,
    required this.fromLaura,
  });

  final Transfer transfer;
  final bool fromLaura;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fromName = fromLaura ? 'Laura' : 'Roberto';
    final toName = fromLaura ? 'Roberto' : 'Laura';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          PersonAvatar(
            person: fromLaura ? PersonKey.lau : PersonKey.rob,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fromName → $toName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  AppDateFormat.format(transfer.date),
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
          MoneyText(transfer.amountCents),
        ],
      ),
    );
  }
}
