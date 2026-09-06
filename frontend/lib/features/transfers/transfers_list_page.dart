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
import '../../core/widgets/undo_snackbar.dart';
import '../../data/data_providers.dart';
import '../../data/transfer_models.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';

class TransfersListPage extends ConsumerWidget {
  const TransfersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final transfers =
        ref.watch(transfersProvider).valueOrNull ?? const <Transfer>[];
    final household = ref.watch(authSessionProvider).valueOrNull?.household;
    final user = ref.watch(authSessionProvider).valueOrNull?.user;

    final groups = <String, List<Transfer>>{};
    for (final t in transfers) {
      final key = AppDateFormat.monthYearHeader(t.date);
      groups.putIfAbsent(key, () => []).add(t);
    }

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Bonifici'),
        actions: [
          IconButton(
            tooltip: 'Registra bonifico',
            onPressed: () => context.push('/bonifici/nuovo'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: transfers.isEmpty
          ? ListView(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
              children: [
                EmptyState(
                  message:
                      'Nessun bonifico di conguaglio. '
                      'Quando uno dei due rimborsa l’altro, registratelo qui: '
                      'non è una spesa, serve solo a riportare il saldo a zero.',
                  actionLabel: 'Registra bonifico',
                  onAction: () => context.push('/bonifici/nuovo'),
                ),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final month = groups.keys.elementAt(i);
                final items = groups[month]!;
                final monthTotal =
                    items.fold<int>(0, (s, t) => s + t.amountCents);
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
                    for (final t in items)
                      _TransferTile(
                        transfer: t,
                        household: household,
                        onDelete: household == null || user == null
                            ? null
                            : () => _delete(context, ref, t, user.uid),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
    String uid,
  ) async {
    await ref.read(transferRepositoryProvider).softDelete(transfer.id, uid);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: 'Bonifico eliminato',
      onUndo: () {
        ref.read(transferRepositoryProvider).restore(transfer.id, uid);
      },
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({
    required this.transfer,
    required this.household,
    required this.onDelete,
  });

  final Transfer transfer;
  final Household? household;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fromLaura = household != null && household!.isLauUid(transfer.fromUid);
    final fromName = fromLaura ? 'Laura' : 'Roberto';
    final toName = fromLaura ? 'Roberto' : 'Laura';
    final note = transfer.note?.trim();
    final subtitle = [
      AppDateFormat.format(transfer.date),
      if (note != null && note.isNotEmpty) note,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(transfer.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: c.dueSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Elimina',
            style: TextStyle(color: c.due, fontWeight: FontWeight.w800),
          ),
        ),
        confirmDismiss: (_) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Eliminare il bonifico?'),
              content: const Text(
                'Il conguaglio verrà nascosto e il saldo si aggiornerà.',
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
        child: AppCard(
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 32,
                child: Stack(
                  children: [
                    PersonAvatar(
                      person: fromLaura ? PersonKey.lau : PersonKey.rob,
                      size: 32,
                    ),
                    Positioned(
                      left: 12,
                      child: PersonAvatar(
                        person: fromLaura ? PersonKey.rob : PersonKey.lau,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              MoneyText(transfer.amountCents),
            ],
          ),
        ),
      ),
    );
  }
}
