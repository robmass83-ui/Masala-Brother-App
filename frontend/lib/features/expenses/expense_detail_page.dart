import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/status_mapping.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';
import 'payer_dialog.dart';

class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(expenseProvider(id));
    final session = ref.watch(authSessionProvider).valueOrNull;
    final cats = {
      for (final x in ref.watch(categoriesProvider).valueOrNull ?? const <CatalogCategory>[])
        x.id: x.name,
    };
    final props = {
      for (final x in ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[])
        x.id: x.name,
    };

    return async.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Spesa')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Spesa')),
        body: Center(child: Text('Errore: $e')),
      ),
      data: (expense) {
        if (expense == null) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(title: const Text('Spesa')),
            body: const Center(child: Text('Spesa non trovata')),
          );
        }
        final household = session?.household;
        final user = session?.user;
        final cat = cats[expense.categoryId] ?? expense.categoryId;
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            title: const Text('Dettaglio spesa'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (user == null || household == null) return;
                  if (value == 'edit') {
                    context.push('/spese/${expense.id}/modifica');
                  } else if (value == 'duplicate') {
                    await _duplicate(ref, context, expense, user, household);
                  } else if (value == 'delete') {
                    await _delete(ref, context, expense, user.uid);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplica')),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  StatusChip(status: statusToUi(expense.status)),
                  const SizedBox(width: 8),
                  _SoftChip(label: cat),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                expense.description,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${AppDateFormat.format(expense.date)}'
                '${expense.dateEstimated ? ' · data stimata' : ''}'
                '${expense.propertyId != null ? ' · ${props[expense.propertyId]}' : ''}',
                style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Triple(label: 'Da pagare', cents: expense.amountDueCents),
                        _Triple(label: 'Corrisposto', cents: expense.paidTotalCents, ok: true),
                        _Triple(label: 'Manca', cents: expense.missingCents, due: true),
                      ],
                    ),
                    if (expense.overpaidCents > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Pagato in eccesso di ${MoneyFormat.fromCents(expense.overpaidCents)}',
                        style: TextStyle(color: c.warn, fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: [
                            Expanded(
                              flex: expense.paidRobCents.clamp(0, 1 << 20),
                              child: ColoredBox(color: c.rob),
                            ),
                            Expanded(
                              flex: expense.paidLauCents.clamp(0, 1 << 20),
                              child: ColoredBox(color: c.lau),
                            ),
                            if (expense.paidTotalCents == 0)
                              const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Pagamenti', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              if (expense.payments.isEmpty)
                AppCard(
                  child: Text(
                    'Nessun pagamento ancora.',
                    style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                  ),
                )
              else
                for (final p in expense.payments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(p.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        if (user == null || household == null) return false;
                        await ref.read(expenseRepositoryProvider).removePayment(
                              expense: expense,
                              paymentId: p.id,
                              actorUid: user.uid,
                              robUid: household.robUid,
                              lauUid: household.lauUid,
                            );
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: c.dueSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text('Elimina', style: TextStyle(color: c.due, fontWeight: FontWeight.w800)),
                      ),
                      child: AppCard(
                        child: Row(
                          children: [
                            PersonAvatar(
                              person: household?.isLauUid(p.payerUid) == true
                                  ? PersonKey.lau
                                  : PersonKey.rob,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${household?.isLauUid(p.payerUid) == true ? 'Laura' : 'Roberto'} ha pagato',
                                    style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${AppDateFormat.format(p.date)} · ${paymentMethodLabel(p.method)}',
                                    style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            MoneyText(p.amountCents),
                          ],
                        ),
                      ),
                    ),
                  ),
              if (expense.missingCents > 0) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Pagamento',
                  onPressed: user == null || household == null
                      ? null
                      : () => _addPayment(context, ref, expense, user, household),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Segna pagata',
                  onPressed: user == null || household == null
                      ? null
                      : () => _markPaid(context, ref, expense, user, household),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _addPayment(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    AppUser user,
    Household household,
  ) async {
    final draft = await askPayment(
      context: context,
      household: household,
      suggestedCents:
          expense.missingCents > 0 ? expense.missingCents : expense.amountDueCents,
      title: 'Pagamento',
    );
    if (draft == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    await repo.addPayments(
      expense: expense,
      parts: [
        for (final p in draft.parts)
          (payerUid: p.payerUid, amountCents: p.amountCents),
      ],
      actorUid: user.uid,
      robUid: household.robUid,
      lauUid: household.lauUid,
    );
  }

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    AppUser user,
    Household household,
  ) async {
    final draft = await askPayment(
      context: context,
      household: household,
      suggestedCents:
          expense.missingCents > 0 ? expense.missingCents : expense.amountDueCents,
      title: 'Segna pagata',
    );
    if (draft == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    await repo.addPayments(
      expense: expense,
      parts: [
        for (final p in draft.parts)
          (payerUid: p.payerUid, amountCents: p.amountCents),
      ],
      actorUid: user.uid,
      robUid: household.robUid,
      lauUid: household.lauUid,
    );
  }

  Future<void> _duplicate(
    WidgetRef ref,
    BuildContext context,
    Expense expense,
    AppUser user,
    Household household,
  ) async {
    final repo = ref.read(expenseRepositoryProvider);
    final saved = await repo.save(
      draft: Expense(
        id: '',
        description: expense.description,
        amountDueCents: expense.amountDueCents,
        date: DateTime.now(),
        categoryId: expense.categoryId,
        propertyId: expense.propertyId,
        shareRobPct: expense.shareRobPct,
      ),
      actorUid: user.uid,
      robUid: household.robUid,
      lauUid: household.lauUid,
    );
    if (context.mounted) context.push('/spese/${saved.id}');
  }

  Future<void> _delete(
    WidgetRef ref,
    BuildContext context,
    Expense expense,
    String uid,
  ) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.softDelete(expense.id, uid);
    if (context.mounted) context.go('/spese');
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: c.acc, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _Triple extends StatelessWidget {
  const _Triple({
    required this.label,
    required this.cents,
    this.ok = false,
    this.due = false,
  });

  final String label;
  final int cents;
  final bool ok;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = due
        ? c.due
        : ok
            ? c.ok
            : c.ink;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: c.ink2, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 6),
          MoneyText(cents, color: color, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
